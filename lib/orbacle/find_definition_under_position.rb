# frozen_string_literal: true

module Orbacle
  class FindDefinitionUnderPosition < Parser::AST::Processor
    include AstUtils

    ConstantResult = Struct.new(:const_ref)
    MessageResult = Struct.new(:name, :position_range)

    def initialize(parser)
      @parser = parser
    end

    def process_file(file_content, searched_position)
      ast = parser.parse(file_content)

      @current_nesting = Nesting.empty
      @searched_position = searched_position

      process(ast)

      @result
    end

    attr_reader :parser

    def on_const(ast)
      if build_position_range_from_ast(ast).include_position?(@searched_position)
        @result = ConstantResult.new(ConstRef.from_ast(ast, @current_nesting))
      end
    end

    def on_class(ast)
      klass_name_ast, _ = ast.children
      klass_name_ref = ConstRef.from_ast(klass_name_ast, @current_nesting)
      with_new_nesting(@current_nesting.increase_nesting_const(klass_name_ref)) do
        super
      end
    end

    def on_module(ast)
      module_name_ast, _ = ast.children
      module_name_ref = ConstRef.from_ast(module_name_ast, @current_nesting)
      with_new_nesting(@current_nesting.increase_nesting_const(module_name_ref)) do
        super
      end
    end

    def on_send(ast)
      if build_position_range_from_parser_range(ast.loc.selector).include_position?(@searched_position)
        message_name = ast.children.fetch(1).to_s
        selector_position_range = build_position_range_from_parser_range(ast.loc.selector)
        @result = MessageResult.new(message_name, selector_position_range)
      else
        super
      end
    end

    def with_new_nesting(new_nesting)
      previous_nesting = @current_nesting
      @current_nesting = new_nesting
      yield
      @current_nesting = previous_nesting
    end
  end
end
