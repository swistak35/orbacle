require 'lsp'
require 'uri'

module Orbacle
  class FindDefinitionUnderPosition < Parser::AST::Processor
    ConstantResult = Struct.new(:const_ref)

    def initialize(parser)
      @parser = parser
    end

    def process_file(file_content, searched_line, searched_character)
      ast = parser.parse(file_content)

      @current_nesting = Orbacle::Nesting.empty
      @searched_position = Orbacle::Position.new(searched_line, searched_character)

      process(ast)

      @result
    end

    attr_reader :parser

    def on_const(ast)
      if build_position_range_from_ast(ast).include_position?(@searched_position.line, @searched_position.character)
        @result = ConstantResult.new(Orbacle::ConstRef.from_ast(ast, @current_nesting))
      end
      return ast
    end

    def on_class(ast)
      klass_name_ast, _ = ast.children
      klass_name_ref = Orbacle::ConstRef.from_ast(klass_name_ast, @current_nesting)
      with_new_nesting(@current_nesting.increase_nesting_const(klass_name_ref)) do
        super
      end
      return ast
    end

    def build_position_range_from_ast(ast)
      Orbacle::PositionRange.new(
        Orbacle::Position.new(ast.loc.expression.begin.line - 1, ast.loc.expression.begin.column),
        Orbacle::Position.new(ast.loc.expression.end.line - 1, ast.loc.expression.end.column - 1))
    end

    def with_new_nesting(new_nesting)
      previous_nesting = @current_nesting
      @current_nesting = new_nesting
      yield
      @current_nesting = previous_nesting
    end
  end

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
