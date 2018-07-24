# frozen_string_literal: true

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
      log_errors do
        filepath = URI(request.text_document.uri).path
        pretty_type = engine.get_type_information(filepath, request.position.line, request.position.character)
        Lsp::ResponseMessage.successful(
          Lsp::TextDocumentHoverResult.new(
            "Type of that expression: #{pretty_type}"))
      end
    end

    def handle_text_document_definition(request)
      log_errors do
        file_path = request.text_document.uri.path
        file_content = File.read(file_path)
        locations = engine.locations_for_definition_under_position(file_content, Position.new(request.position.line, request.position.character))
        if locations
          Lsp::ResponseMessage.successful(locations.map(&method(:location_to_lsp_location)))
        else
          Lsp::ResponseMessage.successful(nil)
        end
      end
    end

    def log_errors
      begin
        yield
      rescue => e
        logger.error(e)
        raise
      end
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
