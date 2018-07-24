# frozen_string_literal: true

module Orbacle
  class Engine
    def initialize(logger)
      @logger = logger
    end

    attr_reader :stats_recorder

    def index(project_root)
      @stats_recorder = Indexer::StatsRecorder.new
      service = Indexer.new(logger, stats_recorder)
      @tree, @typing_result, @graph, @worklist = service.(project_root: project_root)
    end

    def get_type_information(filepath, line, character)
      searched_position = Position.new(line, character)
      relevant_nodes = @graph
        .vertices
        .select {|n| n.location && n.location.uri == filepath && n.location.position_range.include_position?(searched_position) }
        .sort_by {|n| n.location.span }

      type_pretty_printer.(@typing_result[relevant_nodes[0]])
    end

    def get_constants_definitions(const_ref)
      @tree.solve_reference2(const_ref)
    end

    def find_definition_under_position(content, line, character)
      FindDefinitionUnderPosition.new(RubyParser.new).process_file(content, Position.new(line, character))
    end

    def locations_for_definition_under_position(file_content, position)
      result = find_definition_under_position(file_content, request.position.line, request.position.character)
      case result
      when FindDefinitionUnderPosition::ConstantResult
        constants = get_constants_definitions(result.const_ref)
        constants.map(&:location)
      when FindDefinitionUnderPosition::MessageResult
        caller_type = get_type_of_caller_from_message_send(file_path, result.position_range)
        methods_definitions = get_methods_definitions_for_type(caller_type, result.name)
        methods_definitions.map(&:location).compact
      else
        nil
      end
    end

    def get_type_of_caller_from_message_send(file_path, position_range)
      message_send = @worklist
        .message_sends
        .find {|ms| ms.location && ms.location.uri == file_path && ms.location.position_range.include_position?(position_range.start) }
      @typing_result[message_send.send_obj]
    end

    def get_methods_definitions_for_type(type, method_name)
      case type
      when NominalType
        @tree.get_instance_methods_for_class(type.name, method_name)
      when ClassType
        @tree.get_class_methods_for_class(type.name, method_name)
      when UnionType
        type.types_set.flat_map {|t| get_methods_definitions_for_type(t, method_name) }.uniq
      else
        []
      end
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
