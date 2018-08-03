# frozen_string_literal: true

require 'parser'

module Orbacle
  class FindDefinitionUnderPosition < Parser::AST::Processor
    include AstUtils

    ConstantResult = Struct.new(:const_ref)
    MessageResult = Struct.new(:name, :position_range)
    SuperResult = Struct.new(:nesting, :method_name, :keyword_position_range)

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

    def process(ast)
      new_ast = super
      raise unless ast.equal?(new_ast)
      new_ast
    end

    def on_const(ast)
      if build_position_range_from_ast(ast).include_position?(@searched_position)
        @result = ConstantResult.new(ConstRef.from_ast(ast, @current_nesting))
      end
      nil
    end

    def on_class(ast)
      klass_name_ast, _ = ast.children
      klass_name_ref = ConstRef.from_ast(klass_name_ast, @current_nesting)
      with_new_nesting(@current_nesting.increase_nesting_const(klass_name_ref)) do
        super
      end
      nil
    end

    def on_module(ast)
      module_name_ast, _ = ast.children
      module_name_ref = ConstRef.from_ast(module_name_ast, @current_nesting)
      with_new_nesting(@current_nesting.increase_nesting_const(module_name_ref)) do
        super
      end
      nil
    end

    def on_send(ast)
      if ast.loc.selector && build_position_range_from_parser_range(ast.loc.selector).include_position?(@searched_position)
        message_name = ast.children.fetch(1)
        if message_name.equal?(:[])
          selector_position_range = build_position_range_from_parser_range(ast.loc.selector)
          if selector_position_range.on_edges?(@searched_position)
            @result = MessageResult.new(message_name, selector_position_range)
          else
            super
          end
        else
          selector_position_range = build_position_range_from_parser_range(ast.loc.selector)
          @result = MessageResult.new(message_name, selector_position_range)
        end
      elsif ast.loc.dot && build_position_range_from_parser_range(ast.loc.dot).include_position?(@searched_position)
        message_name = ast.children.fetch(1)
        dot_position_range = build_position_range_from_parser_range(ast.loc.dot)
        @result = MessageResult.new(message_name, dot_position_range)
      else
        super
      end
      nil
    end

    def on_super(ast)
      keyword_position_range = build_position_range_from_parser_range(ast.loc.keyword)
      if keyword_position_range.include_position?(@searched_position)
        @result = SuperResult.new(@current_nesting, @current_method, keyword_position_range)
      else
        super
      end
      nil
    end

    def on_zsuper(ast)
      keyword_position_range = build_position_range_from_parser_range(ast.loc.keyword)
      if keyword_position_range.include_position?(@searched_position)
        @result = SuperResult.new(@current_nesting, @current_method, keyword_position_range)
      end
      nil
    end

    def on_def(ast)
      method_name = ast.children.fetch(0)
      with_analyzed_method(method_name) do
        super
      end
      nil
    end

    def with_new_nesting(new_nesting)
      previous_nesting = @current_nesting
      @current_nesting = new_nesting
      yield
      @current_nesting = previous_nesting
    end

    def with_analyzed_method(new_method)
      previous_method = @current_method
      @current_method = new_method
      yield
      @current_method = previous_method
    end
  end
end
