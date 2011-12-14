require 'rubygems'
require 'sinatra'
require File.dirname(__FILE__) + '/zk-register'

configure do
  settings.port = 7777

  Thread.new{
    puts "Waiting for Sinatra to get his pants on..."
    sleep 1 until Sinatra::Application.running?
    puts "Registering at Zookeeper server..."
    zk_register("foo")
  }
end

get '/' do
    'I am instance ONE of the FOO SERVICE!'
end
