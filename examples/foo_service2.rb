require 'rubygems'
require 'sinatra'
require File.dirname(__FILE__) + '/zk-register'

settings.port = 6666
zk_register("foo")

get '/' do
    'I am instance TWO of the FOO SERVICE!'
end
