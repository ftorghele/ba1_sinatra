require 'sinatra'
require './lib/response_timer'

use Rack::ResponseTimer

get '/' do
  @msg = "Hello World"
  erb :home
end