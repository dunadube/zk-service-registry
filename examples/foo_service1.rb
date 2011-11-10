require 'rubygems'
require 'sinatra'
require File.dirname(__FILE__) + '/zk-register'

settings.port = 7777
zk_register("foo")

get '/' do
    'I am instance ONE of the FOO SERVICE!'
end
