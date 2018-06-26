require 'tmpdir'

class TestProject
  def initialize
    @root = Dir.mktmpdir
  end

  attr_reader :root

  def add_file(path, content)
    File.open(path_of(path), "w") do |f|
      f.write(content)
    end
    self
  end

  def path_of(path)
    File.join(root, path)
  end
end
