#
# Add some convenience methods
#
class ZooKeeper

  #
  # Force create a path
  #
  def mkdir_p(path)
    path.split("/").slice(1..-1).inject("") do |current_path, part|
      current_path =  current_path + "/" + part

      create(:path => current_path, :data => "") if !exists(:path => current_path)

      current_path
    end
  end

  #
  # Delete a path recursively
  #
  def rm_r(path)
    return if !exists path

    children(path).each do |c|
      rm_r(path + "/" + c)
    end
    delete(path) 
  end
end
