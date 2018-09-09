# frozen_string_literal: true

require 'parser'

module Orbacle
  class FindCallUnderPosition < Parser::AST::Processor
    include AstUtils

    SelfResult = Struct.new(:message_name, :nesting)

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

    def on_send(ast)
      if ast.loc.selector && build_position_range_from_parser_range(ast.loc.selector).include_position?(@searched_position)
        message_name = ast.children.fetch(1)
        selector_position_range = build_position_range_from_parser_range(ast.loc.selector)
        @result = if ast.children[0] == nil
          SelfResult.new(message_name, @current_nesting)
        else
          case ast.children[0].type
          when :self
            SelfResult.new(message_name, @current_nesting)
          else
          end
        end
      else
        super
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

    def with_new_nesting(new_nesting)
      previous_nesting = @current_nesting
      @current_nesting = new_nesting
      yield
      @current_nesting = previous_nesting
    end
  end
end
