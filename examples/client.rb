require 'rubygems'
require 'net/http/persistent'
require 'zk-service-registry'

def lb_uri(svcname)
  services = ZK::ServiceInstance.list_services
  service = services.select do |s|
    s.name == svcname 
  end[0]
  instance = service.instances.shuffle[0]
  URI "http://#{instance.name}"
end

http = Net::HTTP::Persistent.new 'my_fancy_foo_client'
(1..100).each do
  # perform a GET
  begin
  response = http.request lb_uri("foo")
  p response.body
  rescue Exception => e 
    puts e.message
  end
  sleep 3 
end


