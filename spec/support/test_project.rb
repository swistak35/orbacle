require 'tmpdir'

class TestProject
  def initialize
    @root = Dir.mktmpdir
    add_orbaclerc
  end

  attr_reader :root

  def add_file(path:, content:)
    full_path = File.join(root, path)
    File.open(full_path, "w") do |f|
      f.write(content)
    end
    self
  end

  private

  def add_orbaclerc
    full_path = File.join(root, ".orbaclerc")
    File.open(full_path, "w") do |f|
      f.write("")
    end
  end
end
