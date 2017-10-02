module Orbacle
  class ControlFlowGraph < Parser::AST::Processor
    def process_method(method_declaration)
      ast = Parser::CurrentRuby.parse(method_declaration)

      @blocks = []
      @tmpcounter = 0

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
              if object_ast.children[0].nil?
                [:send, object_ast.children[1].to_s]
              else
                [:tmpvar, make_tmp_var(object_ast)]
              end
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

    def make_tmp_var(ast)
      tmpvar = @tmpcounter.to_s
      @tmpcounter += 1

      assigned_expr = case ast.type
        when :send
          object_ast = ast.children[0]
          method_name = ast.children[1]
          object = case object_ast.type
            when :const
              [:constant, object_ast.children[1].to_s]
            when :send
              if object_ast.children[0].nil?
                [:send, object_ast.children[1].to_s]
              else
                [:tmpvar, make_tmp_var(object_ast)]
              end
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
        type: :tmpasgn,
        tmp_name: tmpvar,
        assigned_expr: assigned_expr,
      }

      tmpvar
    end
  end
end
