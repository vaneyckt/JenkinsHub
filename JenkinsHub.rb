require 'yaml'
require 'json'
require 'logger'
require 'sinatra'
require 'sinatra/static_assets'
require './lib/helpers.rb'

# create global logger
log_file_path = get_log_file_path(settings.root)
log_file = File.open(log_file_path, 'a+')
log_file.sync = true
$LOGGER = Logger.new(log_file)
$LOGGER.level = Logger::ERROR
$LOGGER.info("Start")

# read config file
config = read_config_data(settings.root)

# start script
scheduler_thread = Thread.new do
  pids = `ps aux | grep 'handlePullRequests.rb' | grep -v 'grep' | awk '{print $2}'`.split("\n")
  `ruby #{settings.root}/lib/handlePullRequests.rb -r #{settings.root}` if pids.empty?
end

# get index page
get '/?' do
  erb :index
end

# get json of pull requests data file in /db folder
get '/pull_requests_data/?' do
  data = read_pull_requests_data_file(settings.root)
  content_type :json
  JSON.pretty_generate(JSON.parse(data.to_json))
end

# delete pull request from the pull request data file
get '/delete/?' do
  id = params[:id].to_i
  delete_id_pull_requests_data_file(settings.root, id)
  redirect to('/')
end
