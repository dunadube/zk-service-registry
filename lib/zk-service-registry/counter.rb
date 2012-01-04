class ZK::Counter
  CounterRoot = "/counters"

  def self.clear_all
    zk = ZooKeeper.new(:host => ZK::Config::Hosts.join(","))
    ZK::Utils.wait_until { zk.connected? }
    zk.rm_r(CounterRoot)
  end

  def initialize(what)
    @hosts = ZK::Config::Hosts.join(",")
    @counter_category_path = "#{CounterRoot}/#{what}" 
  end
  
  def connect
    @zk = @zk || ZooKeeper.new(:host => @hosts)
    ZK::Utils.wait_until { @zk.connected? }

    # make sure there is a path for the election
    @zk.mkdir_p(@counter_category_path)

    self
  end

  def count(who=nil)
    return count_all if who.nil?

    counter_path = "#{@counter_category_path}/#{who}"
    @zk.get(counter_path)[0].to_i
  end

  def count!(who, inc=1)
    counter_path = "#{@counter_category_path}/#{who}"
    if !@zk.exists counter_path

      @zk.create(:path => counter_path, :data => "#{inc}")
      inc
    else
      current_count = count(who)
      @zk.set(:path => counter_path, :data => "#{current_count + inc}")
    end
    self
  end

  private

  def count_all
    @zk.children(@counter_category_path).inject(0) do  |sum, who|
      sum += count(who)
      sum
    end
  end
end
