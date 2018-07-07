module Orbacle
  class Engine
    def initialize(logger)
      @logger = logger
    end

    attr_reader :stats_recorder

    def index(project_root)
      service = Indexer.new(logger)
      @tree, @typing_result, @graph, @stats_recorder = service.(project_root: project_root)
    end

    def get_type_information(filepath, line, character)
      logger.info("Asked about #{filepath.inspect} #{line.inspect} #{character.inspect}")
      relevant_nodes = @graph
        .vertices
        .select {|n| n.location && n.location.uri == filepath && n.location.position_range.include_position?(line, character) }
        .sort_by {|n| n.location.span }

      type_pretty_printer.(@typing_result[relevant_nodes[0]])
    end

    private
    attr_reader :logger

    def pretty_print_type(type)
      type_pretty_printer.(type)
    end

    def type_pretty_printer
      @type_pretty_printer ||= TypePrettyPrinter.new
    end
  end
end
