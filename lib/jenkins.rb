require 'json'
require './lib/helpers.rb'

module Jenkins
  def Jenkins.handle_pull_request_with_job_id(job_id, config)
    poll_interval = config[:jenkins_polling_interval_seconds]
    timeout_value = Time.now.to_i + config[:jenkins_job_timeout_seconds]

    # wait for executor to become available
    while(Jenkins.get_idle_executors(config) == 0)
      $LOGGER.info('Jenkins') { "preparing to sleep for #{poll_interval} seconds (wait for idle executor)" }
      sleep poll_interval
    end

    # start job
    while(Jenkins.start_job_with_job_id(job_id, config) != true and Time.now.to_i < timeout_value)
      $LOGGER.info('Jenkins') { "preparing to sleep for #{poll_interval} seconds (start job)" }
      sleep poll_interval
    end

    # get job result
    result = 'timeout'
    while(result == 'timeout' and Time.now.to_i < timeout_value)
      $LOGGER.info('Jenkins') { "preparing to sleep for #{poll_interval} seconds (get job result)" }
      sleep poll_interval
      result = Jenkins.get_job_result_for_job_id(job_id, config)
    end
    result
  end

  def Jenkins.start_job_with_job_id(job_id, config)
    cmd = get_jenkins_start_job_with_job_id_curl_cmd(job_id, config)
    $LOGGER.info('Jenkins') { "preparing to start job (#{cmd})" }
    response = `#{cmd}`
    response.include?('200 OK')
  end

  def Jenkins.get_job_result_for_job_id(job_id, config)
    job_info = Jenkins.get_job_info(config)
    job_info["builds"].each do |job_build_info|
      begin
        if(job_build_info["actions"][0]["parameters"][2]["value"] == job_id)
          return 'passed' if(job_build_info["result"] == "SUCCESS")
          return 'failed' if(job_build_info["result"] == "UNSTABLE")
          return 'failed' if(job_build_info["result"] == "FAILURE")
        end
      rescue
      end
    end
    'timeout'
  end

  def Jenkins.get_job_url_for_job_id(job_id, config)
    job_info = Jenkins.get_job_info(config)
    job_info["builds"].each do |job_build_info|
      begin
        if(job_build_info["actions"][0]["parameters"][2]["value"] == job_id)
          return job_build_info["url"]
        end
      rescue
      end
    end
    nil
  end

  def Jenkins.get_job_info(config)
    cmd = get_jenkins_job_info_curl_cmd(config)
    $LOGGER.info('Jenkins') { "preparing to get job info (#{cmd})" }
    response = `#{cmd}`
    JSON.parse(response)
  end

  def Jenkins.get_idle_executors(config)
    cmd = get_jenkins_idle_executors_curl_cmd(config)
    $LOGGER.info('Jenkins') { "preparing to get idle executors (#{cmd})" }
    response = `#{cmd}`
    response = JSON.parse(response)
    response["assignedLabels"][0]["idleExecutors"]
  end
end
