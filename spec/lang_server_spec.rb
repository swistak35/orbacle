require 'orbacle_server'

module OrbacleServer
  RSpec.describe LangServer do
    let(:logger) { Logger.new(nil) }

    specify do
      engine = double
      server = LangServer.new(logger, engine)

      expect(engine).to receive(:get_type_information).with("/foo.rb", 2, 10)
        .and_return("Array<String>")

      server.handle_text_document_hover(
        Lsp::TextDocumentPositionParams.new(
          Lsp::TextDocumentIdentifier.new("file:///foo.rb"),
          Lsp::Position.new(2, 10)))
    end
  end
end
