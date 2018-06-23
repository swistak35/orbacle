module Orbacle
  module DataFlowGraph
    class Engine
      def initialize(logger)
        @logger = logger
      end

      def index(project_root)
        service = IndexService.new(logger)
        service.(project_root)
      end
    end
  end
end
