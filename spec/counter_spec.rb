require File.join(File.dirname(__FILE__), %w[spec_helper])
require File.dirname(__FILE__) + "/../lib/zk-service-registry"

describe ZK::Counter do

  before :all do
    ZK::ZookeeperServer.start
    ZK::Utils.wait_until { ZK::ZookeeperServer.running? }

    # clear all nodes before starting
    ZK::Counter.clear_all

    @counter_one = ZK::Counter.new("deployments").connect.count!("foo")
    @counter_three = ZK::Counter.new("deployments").connect.count!("bar").count!("bar", 2)
    @counter_sum = ZK::Counter.new("deployments").connect
  end

  after :all do
    ZK::ZookeeperServer.stop
    ZK::Utils.wait_until { !ZK::ZookeeperServer.running? }
  end

  it "should be one after first count" do
    @counter_one.count("foo").should eql(1)
  end

  it "should be three after c += 1 and c += 2" do
    @counter_three.count("bar").should eql(3)
  end

  it "should sum up child counts" do
    @counter_sum.count.should eql(4)
  end

  it "should give all the count subcategory names" do
    @counter_sum.subcategories.should eql(["foo", "bar"])
  end

end
