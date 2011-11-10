require 'zk-service-registry'

def local_ip
  require 'socket'
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

  UDPSocket.open do |s|
    s.connect '64.233.187.99', 1
    s.addr.last
  end
ensure
  Socket.do_not_reverse_lookup = orig
end

def zk_register(svcname)
  ipaddr = settings.bind
  ipaddr = local_ip if ipaddr == "0.0.0.0"

  ZK::ServiceInstance.advertise(svcname, ipaddr + ":" + settings.port.to_s)
end
