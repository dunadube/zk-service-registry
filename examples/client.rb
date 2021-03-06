require 'rubygems'
require 'net/http/persistent'
require 'zk-service-registry'

@service_finder = ZK::ServiceFinder.new.connect
@service_finder.watch("foo")

def lb_uri
  instance = @service_finder.instances.shuffle[0]
  URI "http://#{instance.name}"
end

http = Net::HTTP::Persistent.new 'my_fancy_foo_client'
(1..100).each do
  # perform a GET
  begin
  response = http.request lb_uri
  p response.body
  rescue Exception => e 
    puts e.message
  end
  sleep 3 
end


