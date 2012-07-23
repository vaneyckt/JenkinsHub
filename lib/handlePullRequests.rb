require 'yaml'
require 'logger'
require 'trollop'
require './lib/git.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers.rb'

# get options
opts = Trollop::options do
  opt :root_path, "The path that contains the /db and /repositories directories", :type => :string, :required => true
end

# create global logger
log_file_path = get_log_file_path(opts[:root_path])
log_file = File.open(log_file_path, 'a+')
log_file.sync = true
$LOGGER = Logger.new(log_file)
$LOGGER.level = Logger::ERROR

# read config file
config = read_config_data(opts[:root_path])

while(true)
  # get all currently open pull requests ids from github
  open_pull_requests_ids = Github.get_open_pull_requests_ids(config)

  # remove pull requests that are no longer open in github from the data file
  pull_requests_data = read_pull_requests_data_file(opts[:root_path])
  removable_ids = pull_requests_data.keys - open_pull_requests_ids
  removable_ids.each { |id| delete_id_pull_requests_data_file(opts[:root_path], id) }
  removable_ids.each { |id| pull_requests_data.delete(id) }

  # decide which currently open pull requests warrants action
  open_pull_requests_ids.each do |pull_request_id|
    begin
      # parse data of this pull request
      info_json = Github.get_pull_request_info(pull_request_id, config)
      pull_request = parse_pull_request_from_info_json(opts[:root_path], info_json, pull_request_id)

      if pull_request[:merged]
        # remove pull request from the db
        delete_id_pull_requests_data_file(opts[:root_path], pull_request_id)
      elsif !pull_request[:mergeable]
        # update pull request status
        pull_request[:status] = 'not mergeable'
        update_data_pull_requests_data_file(opts[:root_path], pull_request)
      else
        # check if we need to test this pull request
        pull_requests_data = read_pull_requests_data_file(opts[:root_path])
        is_test_required = !pull_requests_data.has_key?(pull_request_id)
        is_test_required = pull_requests_data[pull_request_id][:status] == 'busy' if !is_test_required
        is_test_required = pull_requests_data[pull_request_id][:status] == 'error' if !is_test_required
        is_test_required = pull_requests_data[pull_request_id][:status] == 'timeout' if !is_test_required
        is_test_required = pull_requests_data[pull_request_id][:status] == 'not mergeable' if !is_test_required
        is_test_required = pull_requests_data[pull_request_id][:head_sha] != pull_request[:head_sha] if !is_test_required
        is_test_required = pull_requests_data[pull_request_id][:base_sha] != pull_request[:base_sha] if !is_test_required

        if !is_test_required
          # update pull request status (to update last checked time)
          pull_request[:status] = pull_requests_data[pull_request_id][:status]
          update_data_pull_requests_data_file(opts[:root_path], pull_request)
        else
          # update pull request status
          pull_request[:status] = 'busy'
          pull_request[:jenkins_job_id] = "#{pull_request_id}-#{(Time.now.to_f * 1000000).to_i}"
          update_data_pull_requests_data_file(opts[:root_path], pull_request)

          # clone repository if required
          Git.clone_repository!(opts[:root_path], config)

          # delete the old local testing branch
          Git.delete_local_testing_branch!(opts[:root_path], config)

          # delete the old remote testing branch
          Git.delete_remote_testing_branch!(opts[:root_path], config)

          # create a new local testing branch by branching of the base branch of the pull request and pulling in the head branch
          Git.create_local_testing_branch!(pull_request, opts[:root_path], config)

          # push the new local testing branch to the remote
          Git.push_local_testing_branch_to_remote!(opts[:root_path], config)

          # make jenkins test the pull request, get the result and update the pull request status
          pull_request[:status] = Jenkins.handle_pull_request_with_job_id(pull_request[:jenkins_job_id], config)
          update_data_pull_requests_data_file(opts[:root_path], pull_request)

          # comment on pull request if required
          comment = create_comment(pull_request, config)
          Github.comment_on_pull_request(pull_request_id, comment, config) if !comment.nil?
        end
      end
    rescue => ex
      $LOGGER.error('Main') { "Error: #{ex.message}" }

      # update pull request status
      pull_request[:status] = 'error'
      update_data_pull_requests_data_file(opts[:root_path], pull_request)
    end

    # sleep so as not to overwhelm github
    sleep config[:github_polling_interval_seconds]
  end
end
