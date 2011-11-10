#!/usr/bin/env ruby
# Command line utility to manage
# the zookeeper service registry
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'rubygems'
require 'bundler/setup'
require 'zk-service-registry'

def emit_header
  service = "SERVICE".ljust(20)
  instance = "INSTANCE".ljust(25)
  data = "STATE".ljust(5)
  puts "#{service}\t#{instance}\t#{data}" 
end

def emit_service_list
  services = ZK::ServiceInstance.list_services
  services.each do |s|
    s.instances.each do |svc_inst|
      state = svc_inst.data[:state] if svc_inst.data
      puts "#{s.name.ljust(20)}\t#{svc_inst.name.ljust(25)}\t#{state.ljust(5)}"
    end
  end
end

emit_header
emit_service_list
