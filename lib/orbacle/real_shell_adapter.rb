module Orbacle
  class RealShellAdapter
    def bundle_paths
      `bundle show --paths`.split
    end
  end
end
