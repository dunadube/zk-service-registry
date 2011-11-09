# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "zk-service-registry/version"

Gem::Specification.new do |s|
  s.name        = "zk-service-registry"
  s.version     = ZK::VERSION
  s.authors     = ["Stefan Huber"]
  s.email       = ["hubidu27@googlemail.com"]
  s.homepage    = ""
  s.summary     = %q{A service registry based on Apache Zookeeper}
  s.description = %q{Using Apache Zookeeper as a REST based SOA service registry}

  s.rubyforge_project = "zk-service-registry"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_runtime_dependency "json"
end
