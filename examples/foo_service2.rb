require 'rubygems'
require 'sinatra'
require 'zk-service-registry'

configure do
  ZK::Registration.register_deferred("foo", settings.bind, settings.port=7777) do
    Sinatra::Application.running?
  end
end

get '/' do
    'I am instance TWO of the FOO SERVICE!'
end
