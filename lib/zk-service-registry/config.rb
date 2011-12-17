
#
# This is the default config which will
# take effect if zk-service-registry-config
# is not loaded.
#
module ZK
  class Config
    # Zookeeper Hosts: Can be a comma separated list of host and ports
    Hosts = "localhost:2181" if !const_defined?(:Hosts)

    # Service registrations will be created under this path
    ServicePath = "/services"
  end
end
