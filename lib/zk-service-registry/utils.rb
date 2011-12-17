#
# Various utility methods
#
module ZK::Utils

  # Wait until a given block has executed
  #
  def self.wait_until(timeout=10, &block)
    time_to_stop = Time.now + timeout
    until yield do
      break unless Time.now < time_to_stop
    end
  end

  # Get the ip address of the local machine
  #
  def self.local_ip
    require 'socket'
    Socket.ip_address_list.find(&:ipv4_private?).ip_address if Socket.respond_to?(:ip_address_list) #>=1.9.2-180

    begin
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily
      UDPSocket.open do |s|
        s.connect '64.233.187.99', 1
        s.addr.last
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end
  end
end
