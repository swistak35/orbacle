# frozen_string_literal: true

require 'spec_helper'

module Orbacle
  RSpec.describe LangServer do
    let(:logger) { Logger.new(nil) }

    describe "#handle_initialize" do
      specify do
        engine = instance_double(Engine)
        server = LangServer.new(logger, engine)

        expect(logger).to receive(:info).with('Initializing at "/foo/bar"')
        expect(engine).to receive(:index).with("/foo/bar")

        response = server.handle_initialize(
          Lsp::InitializeRequest.new(URI("file:///foo/bar")))

        expect(response.result).to eq(nil)
      end
    end

    describe "#handle_text_document_hover" do
      specify "happy path" do
        engine = instance_double(Engine)
        server = LangServer.new(logger, engine)

        expect(engine).to receive(:get_type_information).with("/foo.rb", Position.new(2, 10))
          .and_return("Array<String>")

        response = server.handle_text_document_hover(
          Lsp::TextDocumentPositionParams.new(
            Lsp::TextDocumentIdentifier.new(URI("file:///foo.rb")),
            Lsp::Position.new(2, 10)))

        expect(response.result).to eq(
          Lsp::TextDocumentHoverResult.new("Type of that expression: Array<String>"))
      end

      specify "error raised" do
        engine = instance_double(Engine)
        server = LangServer.new(logger, engine)

        expect(engine).to receive(:get_type_information).with("/foo.rb", Position.new(2, 10))
          .and_raise(StandardError)

        expect(logger).to receive(:error).with(StandardError)
        expect do
          server.handle_text_document_hover(
            Lsp::TextDocumentPositionParams.new(
              Lsp::TextDocumentIdentifier.new(URI("file:///foo.rb")),
              Lsp::Position.new(2, 10)))
        end.to raise_error(StandardError)
      end
    end

    describe "#handle_text_document_definition" do
      specify "no result" do
        engine = instance_double(Engine)
        server = LangServer.new(logger, engine)

        file_content = double
        expect(File).to receive(:read).with("/foo.rb").and_return(file_content)

        expect(engine).to receive(:locations_for_definition_under_position)
          .with("/foo.rb", file_content, Position.new(2, 10))
          .and_return(nil)

        response = server.handle_text_document_definition(
          Lsp::TextDocumentPositionParams.new(
            Lsp::TextDocumentIdentifier.new(URI("file:///foo.rb")),
            Lsp::Position.new(2, 10)))

        expect(response.result).to eq(nil)
        expect(response.error).to eq(LangServer::Errors::NoDefinitionFound)
      end

      specify "constant result" do
        engine = instance_double(Engine)
        server = LangServer.new(logger, engine)

        file_content = double
        expect(File).to receive(:read).with("/foo.rb").and_return(file_content)

        location = Location.new("/bar.rb", PositionRange.new(Position.new(1, 2), Position.new(3, 4)), 5)
        expect(engine).to receive(:locations_for_definition_under_position)
          .with("/foo.rb", file_content, Position.new(2, 10))
          .and_return([location])

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

      specify "error raised" do
        engine = instance_double(Engine)
        server = LangServer.new(logger, engine)

        file_content = double
        expect(File).to receive(:read).with("/foo.rb").and_return(file_content)

        expect(engine).to receive(:locations_for_definition_under_position)
          .with("/foo.rb", file_content, Position.new(2, 10))
          .and_raise(StandardError)

        expect(logger).to receive(:error).with(StandardError)
        expect do
          server.handle_text_document_definition(
            Lsp::TextDocumentPositionParams.new(
              Lsp::TextDocumentIdentifier.new(URI("file:///foo.rb")),
              Lsp::Position.new(2, 10)))
        end.to raise_error(StandardError)
      end
    end
  end
end
