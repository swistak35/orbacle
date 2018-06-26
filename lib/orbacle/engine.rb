module Orbacle
  class Engine
    def initialize(logger)
      @logger = logger
    end

    def index(project_root)
      service = Indexer.new(logger)
      @tree, @typing_result, @graph = service.(project_root: project_root)
    end

    def get_type_information(filepath, line, character)
      relevant_nodes = @graph
        .vertices
        .select {|n| n.location && n.location.uri == filepath && n.location.position_range.include_position?(line, character) }
        .sort_by {|n| n.location.span }

      pretty_print_type(@typing_result[relevant_nodes[0]])
    end

    private
    attr_reader :logger

    def pretty_print_type(type)
      case type
      when Orbacle::TypingService::NominalType
        type.name
      end
    end
  end
end
