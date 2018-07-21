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
      file_content = File.read(request.text_document.uri.path)
      result = engine.find_definition_under_position(file_content, request.position.line, request.position.character)
      if result
        constants = engine.get_constants_definitions(result.const_ref)
        constants_locations = constants.map do |constant|
          location_to_lsp_location(constant.location)
        end
        Lsp::ResponseMessage.successful(constants_locations)
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
