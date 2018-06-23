require 'lsp'

module OrbacleServer
  class LangServer
    include Lsp::LanguageServer

    def initialize(logger)
      @logger = logger
      @engine = Orbacle::Engine.new(logger)
    end

    attr_reader :logger

    def handle_initialize(request)
      @engine.index(request.root_uri)
      Lsp::ResponseMessage.new(nil, nil)
    end

    def handle_text_document_hover(request)
      Lsp::ResponseMessage.successful(
        Lsp::TextDocumentHoverResult.new("Type: Meh"))
    end

    def handle_text_document_definition(request)
      Lsp::ResponseMessage.successful(
        Lsp::Location.new(
          "/home/swistak35/projs/msc/orbacle/lib/orbacle.rb",
          Lsp::Range.new(Lsp::Position.new(0, 0), Lsp::Position.new(0, 0))))
    end
  end
end
