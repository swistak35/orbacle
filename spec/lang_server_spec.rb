require 'spec_helper'

module Orbacle
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

    describe "#handle_text_document_definition" do
      specify "no result" do
        engine = double
        server = LangServer.new(logger, engine)

        file_content = double
        expect(File).to receive(:read).with("/foo.rb").and_return(file_content)

        expect(engine).to receive(:find_definition_under_position)
          .with(file_content, 2, 10)
          .and_return(nil)

        response = server.handle_text_document_definition(
          Lsp::TextDocumentPositionParams.new(
            Lsp::TextDocumentIdentifier.new(URI("file:///foo.rb")),
            Lsp::Position.new(2, 10)))

        expect(response.result).to eq(nil)
      end

      specify "constant result" do
        engine = instance_double(Engine)
        server = LangServer.new(logger, engine)

        file_content = double
        expect(File).to receive(:read).with("/foo.rb").and_return(file_content)

        const_ref = double
        expect(engine).to receive(:find_definition_under_position)
          .with(file_content, 2, 10)
          .and_return(FindDefinitionUnderPosition::ConstantResult.new(const_ref))

        location = Location.new("/bar.rb", PositionRange.new(Position.new(1, 2), Position.new(3, 4)), 5)
        expect(engine).to receive(:get_constants_definitions)
          .with(const_ref)
          .and_return([OpenStruct.new(location: location)])

        response = server.handle_text_document_definition(
          Lsp::TextDocumentPositionParams.new(
            Lsp::TextDocumentIdentifier.new(URI("file:///foo.rb")),
            Lsp::Position.new(2, 10)))

        expect(response.result).to eq([
          Lsp::Location.new(
            URI("file:///bar.rb"),
            Lsp::Range.new(Lsp::Position.new(1, 2), Lsp::Position.new(3, 4)))
        ])
      end
    end
  end
end
