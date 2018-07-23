require 'lsp'
require 'uri'

module Orbacle
  class LangServer
    include Lsp::LanguageServer

    def initialize(logger, engine = Orbacle::Engine.new(logger))
      @logger = logger
      @engine = engine
    end

    attr_reader :logger, :engine

    def handle_initialize(request)
      root_path = URI(request.root_uri).path
      logger.info("Initializing at #{root_path.inspect}")
      engine.index(root_path)
      Lsp::ResponseMessage.new(nil, nil)
    end

    def handle_text_document_hover(request)
      filepath = URI(request.text_document.uri).path
      pretty_type = engine.get_type_information(filepath, request.position.line, request.position.character)
      Lsp::ResponseMessage.successful(
        Lsp::TextDocumentHoverResult.new(
          "Type of that expression: #{pretty_type}"))
    rescue => e
      logger.error(e)
      raise
    end

    def handle_text_document_definition(request)
      file_path = request.text_document.uri.path
      file_content = File.read(file_path)
      result = engine.find_definition_under_position(file_content, request.position.line, request.position.character)
      case result
      when FindDefinitionUnderPosition::ConstantResult
        constants = engine.get_constants_definitions(result.const_ref)
        constants_locations = constants.map do |constant|
          location_to_lsp_location(constant.location)
        end
        Lsp::ResponseMessage.successful(constants_locations)
      when FindDefinitionUnderPosition::MessageResult
        caller_type = engine.get_type_of_caller_from_message_send(file_path, result.position_range)
        methods_definitions = engine.get_methods_definitions_for_type(caller_type, result.name)
        methods_locations = methods_definitions.map(&:location).compact.map(&method(:location_to_lsp_location))
        Lsp::ResponseMessage.successful(methods_locations)
      else
        Lsp::ResponseMessage.successful(nil)
      end
    rescue => e
      logger.error(e)
      raise
    end

    def location_to_lsp_location(location)
      Lsp::Location.new(
        URI("file://#{location.uri}"),
        Lsp::Range.new(
          Lsp::Position.new(location.start.line, location.start.character),
          Lsp::Position.new(location.end.line, location.end.character)))
    end
  end
end
