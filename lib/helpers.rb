def read_config_data(root_path)
  path = get_config_file_path(root_path)
  $LOGGER.info('Helpers') { "preparing to read config data file (#{path})" }
  config = YAML.load(File.read(path))
end

def read_pull_requests_data_file(root_path)
  data = {}
  path = get_pull_requests_data_file_path(root_path)
  $LOGGER.info('Helpers') { "preparing to read pull requests data file (#{path})" }
  data = YAML.load(File.read(path)) if File.exists?(path)
  data
end

def delete_id_pull_requests_data_file(root_path, pull_request_id)
  data = read_pull_requests_data_file(root_path)
  data.delete(pull_request_id)
  path = get_pull_requests_data_file_path(root_path)
  $LOGGER.info('Helpers') { "preparing to overwrite pull requests data file (#{path})" }
  File.open(path, 'w') { |f| YAML.dump(data, f) }
end

def update_data_pull_requests_data_file(root_path, pull_request)
  data = read_pull_requests_data_file(root_path)
  data[pull_request[:id]] = pull_request
  path = get_pull_requests_data_file_path(root_path)
  $LOGGER.info('Helpers') { "preparing to update pull requests data file (#{path} - #{pull_request[:id]})" }
  File.open(path, 'w') { |f| YAML.dump(data, f) }
end


def get_log_file_path(root_path)
  "#{root_path}/logfile.log"
end

def get_config_file_path(root_path)
  "#{root_path}/config/config.yaml"
end

def get_repository_dir_path(root_path)
  "#{root_path}/repositories"
end

def get_repository_file_path(root_path, config)
  repository_name = get_repository_name(config)
  "#{root_path}/repositories/#{repository_name}"
end

def get_pull_requests_data_file_path(root_path)
  "#{root_path}/db/pull_requests.yaml"
end


def get_repository_id(config)
  config[:github_ssh_repository].split('github.com').last.sub('.git', '').reverse.chop.reverse
end

def get_repository_name(config)
  get_repository_id(config).split('/').last
end

def repository_exists_locally?(root_path, config)
  path = get_repository_file_path(root_path, config)
  $LOGGER.info('Helpers') { "preparing to check if repository exists locally (#{path})" }
  File.directory?(path)
end


def get_jenkins_start_job_with_job_id_curl_cmd(job_id, config)
  cmd = "curl"
  cmd << " --user #{config[:jenkins_login]}:#{config[:jenkins_password]}" if(config.has_key?(:jenkins_login) and config.has_key?(:jenkins_password))
  cmd << " -d \"branch=#{config[:testing_branch_name]}\""
  cmd << " -d \"repository=#{config[:github_ssh_repository]}\""
  cmd << " -d \"id=#{job_id}\""
  cmd << " -GILs"
  cmd << " #{config[:jenkins_url]}"
  cmd << "/" if(config[:jenkins_url][-1] != '/')
  cmd << "job/#{config[:jenkins_job_name]}/buildWithParameters"
  cmd
end

def get_jenkins_job_info_curl_cmd(config)
  cmd = "curl"
  cmd << " --user #{config[:jenkins_login]}:#{config[:jenkins_password]}" if(config.has_key?(:jenkins_login) and config.has_key?(:jenkins_password))
  cmd << " -d \"depth=1\""
  cmd << " -d \"tree=builds[actions[parameters[name,value]],result,url]\""
  cmd << " -s"
  cmd << " #{config[:jenkins_url]}"
  cmd << "/" if(config[:jenkins_url][-1] != '/')
  cmd << "job/#{config[:jenkins_job_name]}/api/json"
end

def get_jenkins_idle_executors_curl_cmd(config)
  cmd = "curl"
  cmd << " --user #{config[:jenkins_login]}:#{config[:jenkins_password]}" if(config.has_key?(:jenkins_login) and config.has_key?(:jenkins_password))
  cmd << " -d \"depth=1\""
  cmd << " -d \"tree=assignedLabels[idleExecutors]\""
  cmd << " -s"
  cmd << " #{config[:jenkins_url]}"
  cmd << "/" if(config[:jenkins_url][-1] != '/')
  cmd << "api/json"
end


def parse_pull_request_from_info_json(root_path, info_json, pull_request_id)
  pull_request = {}
  data = read_pull_requests_data_file(root_path)

  pull_request[:id] = pull_request_id
  pull_request[:url] = info_json.html_url
  pull_request[:title] = info_json.title
  pull_request[:user_name] = info_json.user.login
  pull_request[:merged] = info_json.merged
  pull_request[:mergeable] = info_json.mergeable
  pull_request[:head_sha] = info_json.head.sha
  pull_request[:head_branch] = info_json.head.ref
  pull_request[:base_sha] = info_json.base.sha
  pull_request[:base_branch] = info_json.base.ref
  pull_request[:last_checked] = Time.now.to_i
  pull_request[:status] = nil
  pull_request[:prev_status] = data.has_key?(pull_request_id) ? data[pull_request_id][:status] : nil
  pull_request[:jenkins_job_id] = nil
  pull_request
end

def parse_cmd(cmd)
  cmd.squeeze(' ').strip.gsub(/\n/, '')
end


def create_comment(pull_request, config)
  comment = nil
  no_comment_status = [nil, 'busy', 'error', 'timeout', 'not mergeable']
  if !no_comment_status.include?(pull_request[:status])
    if !no_comment_status.include?(pull_request[:prev_status])
      if pull_request[:status] != pull_request[:prev_status]
        url = Jenkins.get_job_url_for_job_id(pull_request[:jenkins_job_id], config)
        comment = "Status changed from #{pull_request[:prev_status]} to #{pull_request[:status]}."
        comment << " See #{url} for more info."
      end
    else
      url = Jenkins.get_job_url_for_job_id(pull_request[:jenkins_job_id], config)
      comment = "Status set to #{pull_request[:status]}."
      comment << " See #{url} for more info."
    end
  end
  comment
end
