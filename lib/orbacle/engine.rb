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
      @state, @graph, @worklist = service.(project_root: project_root)
    end

    def get_type_information(filepath, searched_position)
      relevant_nodes = @graph
        .vertices
        .select {|n| n.location && n.location.uri.eql?(filepath) && n.location.position_range.include_position?(searched_position) }
        .sort_by {|n| n.location.span }

      pretty_print_type(@state.type_of(relevant_nodes.at(0)))
    end

    def locations_for_definition_under_position(file_path, file_content, position)
      result = find_definition_under_position(file_content, position.line, position.character)
      case result
      when FindDefinitionUnderPosition::ConstantResult
        constants = @state.solve_reference2(result.const_ref)
        constants.map(&:location)
      when FindDefinitionUnderPosition::MessageResult
        caller_type = get_type_of_caller_from_message_send(file_path, result.position_range)
        methods_definitions = get_methods_definitions_for_type(caller_type, result.name)
        methods_definitions.map(&:location).compact
      else
        []
      end
    end

    private
    def get_type_of_caller_from_message_send(file_path, position_range)
      message_send = @worklist
        .message_sends
        .find {|ms| ms.location && ms.location.uri == file_path && ms.location.position_range.include_position?(position_range.start) }
      @state.type_of(message_send.send_obj)
    end

    def get_methods_definitions_for_type(type, method_name)
      case type
      when NominalType
        @state.get_instance_methods_from_class_name(type.name, method_name)
      when ClassType
        @state.get_class_methods_from_class_name(type.name, method_name)
      when UnionType
        type.types_set.flat_map {|t| get_methods_definitions_for_type(t, method_name) }.uniq
      else
        []
      end
    end

    private
    attr_reader :logger

    def find_definition_under_position(content, line, character)
      FindDefinitionUnderPosition.new(RubyParser.new).process_file(content, Position.new(line, character))
    end

    def pretty_print_type(type)
      TypePrettyPrinter.new.(type)
    end
  end
end
