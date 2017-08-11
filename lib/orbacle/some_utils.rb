module Orbacle
  module SomeUtils
    def find_project_root(fileuri)
      dirpath = Pathname(URI(fileuri).path)
      while !dirpath.root?
        dirpath = dirpath.split[0]
        return dirpath if File.exists?(dirpath.join(".orbaclerc"))
      end
      raise "No project root found (.orbaclerc file)"
    end
  end
end
