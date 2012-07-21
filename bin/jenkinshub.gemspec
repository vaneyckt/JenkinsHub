Gem::Specification.new do |s|
  s.name        = 'jenkinshub'
  s.version     = '0.1.2'
  s.date        = '2012-07-20'
  s.summary     = "A Sinatra application that allows for communication between the Jenkins CI and GitHub."
  s.description = "A Sinatra application that allows for communication between the Jenkins CI and GitHub."
  s.authors     = ["Tom Van Eyck"]
  s.email       = 'tomvaneyck@gmail.com'
  s.homepage    = 'https://github.com/vaneyckt/JenkinsHub'

  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'sinatra-static-assets'
  s.add_runtime_dependency 'octokit'
  s.add_runtime_dependency 'trollop'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'rack'
end
