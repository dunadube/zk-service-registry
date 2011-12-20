require 'rubygems'
require 'sinatra'
require 'zk-service-registry'

configure do
  ZK::Registration.register_deferred("foo", settings.bind, settings.port=6666) do
    Sinatra::Application.running?
  end
end

get '/' do
    'I am instance ONE of the FOO SERVICE!'
end
