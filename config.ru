require './JenkinsHub.rb'

set :environment, :production

map('/') { run Sinatra::Application }
