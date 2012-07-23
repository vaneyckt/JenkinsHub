require 'octokit'
require './lib/helpers.rb'

module Github
  def Github.get_open_pull_requests_ids(config)
    begin
      $LOGGER.info('Github') { "starting to get open pull requests ids" }
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      repository_id = get_repository_id(config)
      open_pull_requests = client.pull_requests(repository_id, 'open')
      open_pull_requests_ids = open_pull_requests.collect { |pull_request| pull_request.number }
      return open_pull_requests_ids
    rescue
      sleep 5
      retry
    end
  end

  def Github.get_pull_request_info(pull_request_id, config)
    begin
      $LOGGER.info('Github') { "starting to get pull request info (#{pull_request_id})" }
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      repository_id = get_repository_id(config)
      info_json = client.pull_request(repository_id, pull_request_id)
      raise 'bad info_json' if ![true, false].include?(info_json.merged)
      raise 'bad info_json' if info_json.merged == false and ![true, false].include?(info_json.mergeable)
      return info_json
    rescue
      sleep 5
      retry
    end
  end

  def Github.comment_on_pull_request(pull_request_id, comment, config)
    begin
      $LOGGER.info('Github') { "starting to comment on pull request (#{pull_request_id})" }
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      repository_id = get_repository_id(config)
      client.add_comment(repository_id, pull_request_id, comment)
    rescue
      sleep 5
      retry
    end
  end
end
