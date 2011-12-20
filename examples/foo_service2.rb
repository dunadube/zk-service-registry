require 'rubygems'
require 'sinatra'
require 'zk-service-registry'

configure do
  settings.port = 6666
  ZK::Registration.register_when("foo"){Sinatra::Application.running?}
end

get '/' do
    'I am instance TWO of the FOO SERVICE!'
end
