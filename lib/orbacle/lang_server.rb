require 'lsp'
require 'uri'

module Orbacle
  class LangServer
    include Lsp::LanguageServer

    def initialize(logger, engine = Orbacle::Engine.new(logger))
      @logger = logger
      @engine = engine
    end

    attr_reader :logger

    def handle_initialize(request)
      root_path = URI(request.root_uri).path
      logger.info("Initializing at #{root_path.inspect}")
      @engine.index(root_path)
      Lsp::ResponseMessage.new(nil, nil)
    end

    def handle_text_document_hover(request)
      filepath = URI(request.text_document.uri).path
      pretty_type = @engine.get_type_information(filepath, request.position.line, request.position.character)
      Lsp::ResponseMessage.successful(
        Lsp::TextDocumentHoverResult.new(
          "Type of that expression: #{pretty_type}"))
    rescue => e
      logger.error(e)
      raise
    end

    def handle_text_document_definition(request)
      file_content = File.read(request.text_document.uri)
      result = FindDefinitionUnderPosition.new.(file_content, request.position.line, request.position.character)
      if result.is_a?(ConstantResult)
      else
      end
      Lsp::ResponseMessage.successful(
        Lsp::Location.new(
          "/home/swistak35/projs/msc/orbacle/lib/orbacle.rb",
          Lsp::Range.new(Lsp::Position.new(0, 0), Lsp::Position.new(0, 0))))
    end
  end
end
