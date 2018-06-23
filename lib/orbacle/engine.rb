module Orbacle
  class Engine
    def initialize(logger)
      @logger = logger
    end

    def index(project_root)
      service = Indexer.new(logger)
      service.(project_root: project_root)
    end

    private
    attr_reader :logger
  end
end
