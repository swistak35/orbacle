module Orbacle
  class ControlFlowGraph < Parser::AST::Processor
    def process_method(method_declaration)
      ast = Parser::CurrentRuby.parse(method_declaration)

      @blocks = []

      process(ast)

      @blocks
    end

    def on_lvasgn(node)
      lvar_name = node.children[0].to_s
      assigned_expr_ast = node.children[1]
      assigned_expr = case assigned_expr_ast.type
        when :send
          object_ast = assigned_expr_ast.children[0]
          method_name = assigned_expr_ast.children[1]
          object = case object_ast.type
            when :const
              [:constant, object_ast.children[1].to_s]
            when :send
              [:send, object_ast.children[1].to_s]
            when :lvar
              [:lvar, object_ast.children[0].to_s]
            else
              raise
            end
          if method_name == :new
            [:init, object, []]
          else
            [:send, method_name, object, []]
          end
        else raise
        end

      @blocks << {
        type: :lvasgn,
        lvar_name: lvar_name,
        assigned_expr: assigned_expr,
      }
    end
  end
end
