module Orbacle
  module DataFlowGraph
    class Builder
      module OperatorAssignmentProcessors
        def handle_op_asgn(ast, context)
          expr_partial_asgn = ast.children[0]
          method_name = ast.children[1]
          expr_argument = ast.children[2]

          case expr_partial_asgn.type
          when :lvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:send,
                                                  [Parser::AST::Node.new(:lvar, [var_name]), method_name, expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :ivasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:send,
                                                  [Parser::AST::Node.new(:ivar, [var_name]), method_name, expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :cvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:send,
                                                  [Parser::AST::Node.new(:cvar, [var_name]), method_name, expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :casgn
            scope = expr_partial_asgn.children[0]
            var_name = expr_partial_asgn.children[1]
            expr_full_rhs = Parser::AST::Node.new(:send,
                                                  [Parser::AST::Node.new(:const, [scope, var_name]), method_name, expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :send
            send_obj = expr_partial_asgn.children[0]
            asgn_method_name = expr_partial_asgn.children[1]
            args = expr_partial_asgn.children[2..-1]
            expr_full_rhs = Parser::AST::Node.new(:send,
                                                  [Parser::AST::Node.new(:send, [send_obj, asgn_method_name, *args]), method_name, expr_argument])
            expr_full_asgn = expr_partial_asgn.updated(nil, [send_obj, "#{asgn_method_name}=", expr_full_rhs])
          when :gvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:send,
                                                  [Parser::AST::Node.new(:gvar, [var_name]), method_name, expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          else raise ArgumentError
          end
          expr_full_asgn_result = process(expr_full_asgn, context)

          return expr_full_asgn_result
        end

        def handle_or_asgn(ast, context)
          expr_partial_asgn = ast.children[0]
          expr_argument = ast.children[1]

          case expr_partial_asgn.type
          when :lvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:or,
                                                  [Parser::AST::Node.new(:lvar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :ivasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:or,
                                                  [Parser::AST::Node.new(:ivar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :cvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:or,
                                                  [Parser::AST::Node.new(:cvar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :casgn
            scope = expr_partial_asgn.children[0]
            var_name = expr_partial_asgn.children[1]
            expr_full_rhs = Parser::AST::Node.new(:or,
                                                  [Parser::AST::Node.new(:const, [scope, var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :send
            send_obj = expr_partial_asgn.children[0]
            asgn_method_name = expr_partial_asgn.children[1]
            args = expr_partial_asgn.children[2..-1]
            expr_full_rhs = Parser::AST::Node.new(:or,
                                                  [Parser::AST::Node.new(:send, [send_obj, asgn_method_name, *args]), expr_argument])
            expr_full_asgn = expr_partial_asgn.updated(nil, [send_obj, "#{asgn_method_name}=", expr_full_rhs])
          when :gvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:or,
                                                  [Parser::AST::Node.new(:gvar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          else raise ArgumentError
          end
          expr_full_asgn_result = process(expr_full_asgn, context)

          return expr_full_asgn_result
        end

        def handle_and_asgn(ast, context)
          expr_partial_asgn = ast.children[0]
          expr_argument = ast.children[1]

          case expr_partial_asgn.type
          when :lvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:and,
                                                  [Parser::AST::Node.new(:lvar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :ivasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:and,
                                                  [Parser::AST::Node.new(:ivar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :cvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:and,
                                                  [Parser::AST::Node.new(:cvar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :casgn
            scope = expr_partial_asgn.children[0]
            var_name = expr_partial_asgn.children[1]
            expr_full_rhs = Parser::AST::Node.new(:and,
                                                  [Parser::AST::Node.new(:const, [scope, var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          when :send
            send_obj = expr_partial_asgn.children[0]
            asgn_method_name = expr_partial_asgn.children[1]
            args = expr_partial_asgn.children[2..-1]
            expr_full_rhs = Parser::AST::Node.new(:and,
                                                  [Parser::AST::Node.new(:send, [send_obj, asgn_method_name, *args]), expr_argument])
            expr_full_asgn = expr_partial_asgn.updated(nil, [send_obj, "#{asgn_method_name}=", expr_full_rhs])
          when :gvasgn
            var_name = expr_partial_asgn.children[0]
            expr_full_rhs = Parser::AST::Node.new(:and,
                                                  [Parser::AST::Node.new(:gvar, [var_name]), expr_argument])
            expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
          else raise ArgumentError
          end
          expr_full_asgn_result = process(expr_full_asgn, context)

          return expr_full_asgn_result
        end
      end
    end
  end
end
