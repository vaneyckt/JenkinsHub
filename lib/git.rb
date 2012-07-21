require './lib/helpers.rb'

module Git
  def Git.clone_repository!(root_path, config)
    if !repository_exists_locally?(root_path, config)
      path = get_repository_dir_path(root_path)
      repository_id = get_repository_id(config)
      cmd = <<-GIT
        cd #{path} &&
        git clone https://#{config[:github_login]}:#{config[:github_password]}@github.com/#{repository_id}.git
      GIT
      $LOGGER.info('Git') { "preparing to clone repository (#{parse_cmd(cmd)})" }
      system(cmd)
    end
    raise "Failed to clone repository" if !repository_exists_locally?(root_path, config)
  end

  def Git.local_testing_branch_exists?(root_path, config)
    path = get_repository_file_path(root_path, config)
    cmd = <<-GIT
      cd #{path} &&
      git branch
    GIT
    $LOGGER.info('Git') { "preparing to check if local testing branch exists (#{parse_cmd(cmd)})" }
    `#{cmd}`.include?(config[:testing_branch_name])
  end

  def Git.remote_testing_branch_exists?(root_path, config)
    path = get_repository_file_path(root_path, config)
    cmd = <<-GIT
      cd #{path} &&
      git fetch --all &&
      git remote prune origin &&
      git branch -r
    GIT
    $LOGGER.info('Git') { "preparing to check if remote testing branch exists (#{parse_cmd(cmd)})" }
    `#{cmd}`.include?(config[:testing_branch_name])
  end

  def Git.delete_local_testing_branch!(root_path, config)
    if Git.local_testing_branch_exists?(root_path, config)
      path = get_repository_file_path(root_path, config)
      cmd = <<-GIT
        cd #{path} &&
        git checkout master &&
        git branch -D #{config[:testing_branch_name]}
      GIT
      $LOGGER.info('Git') { "preparing to delete local testing branch (#{parse_cmd(cmd)})" }
      system(cmd)
    end
    raise "Failed to delete local testing branch" if Git.local_testing_branch_exists?(root_path, config)
  end

  def Git.delete_remote_testing_branch!(root_path, config)
    if Git.remote_testing_branch_exists?(root_path, config)
      path = get_repository_file_path(root_path, config)
      cmd = <<-GIT
        cd #{path} &&
        git checkout master &&
        git push origin :#{config[:testing_branch_name]}
      GIT
      $LOGGER.info('Git') { "preparing to delete remote testing branch (#{parse_cmd(cmd)})" }
      system(cmd)
    end
    raise "Failed to delete remote testing branch" if Git.remote_testing_branch_exists?(root_path, config)
  end

  def Git.create_local_testing_branch!(pull_request, root_path, config)
    if !Git.local_testing_branch_exists?(root_path, config)
      path = get_repository_file_path(root_path, config)
      cmd = <<-GIT
        cd #{path} &&
        git fetch --all &&
        git checkout #{pull_request[:head_branch]} &&
        git reset --hard &&
        git pull origin #{pull_request[:head_branch]} &&
        git checkout -b #{config[:testing_branch_name]} &&
        git pull origin #{pull_request[:base_branch]}
      GIT
      $LOGGER.info('Git') { "preparing to create local testing branch (#{parse_cmd(cmd)})" }
      system(cmd)
    end
    raise "Failed to create new local testing branch" if !Git.local_testing_branch_exists?(root_path, config)
  end

  def Git.push_local_testing_branch_to_remote!(root_path, config)
    if !Git.remote_testing_branch_exists?(root_path, config)
      path = get_repository_file_path(root_path, config)
      cmd = <<-GIT
        cd #{path} &&
        git checkout #{config[:testing_branch_name]} &&
        git push origin #{config[:testing_branch_name]}
      GIT
      $LOGGER.info('Git') { "preparing to push local testing branch to remote (#{parse_cmd(cmd)})" }
      system(cmd)
    end
    raise "Failed to create new remote testing branch" if !Git.remote_testing_branch_exists?(root_path, config)
  end
end
