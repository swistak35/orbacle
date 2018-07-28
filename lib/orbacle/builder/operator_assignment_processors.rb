# frozen_string_literal: true

module Orbacle
  class Builder
    module OperatorAssignmentProcessors
      def handle_op_asgn(ast, context)
        partial_assignment_ast, operator_name, argument_ast = ast.children

        return process(
          complete_assignment(
            partial_assignment_ast,
            Parser::AST::Node.new(:send, [
              build_accessor_based_on_assignment(partial_assignment_ast),
              operator_name,
              argument_ast])),
             context)
      end

      def handle_or_asgn(ast, context)
        partial_assignment_ast, argument_ast = ast.children

        return process(
          complete_assignment(
            partial_assignment_ast,
            Parser::AST::Node.new(:or, [
              build_accessor_based_on_assignment(partial_assignment_ast),
              argument_ast])),
             context)
      end

      def handle_and_asgn(ast, context)
        partial_assignment_ast, argument_ast = ast.children

        return process(
          complete_assignment(
            partial_assignment_ast,
            Parser::AST::Node.new(:and, [
              build_accessor_based_on_assignment(partial_assignment_ast),
              argument_ast])),
             context)
      end

      def build_accessor_based_on_assignment(assignment_ast)
        case assignment_ast.type
        when :lvasgn
          var_name = assignment_ast.children[0]
          Parser::AST::Node.new(:lvar, [var_name])
        when :ivasgn
          var_name = assignment_ast.children[0]
          Parser::AST::Node.new(:ivar, [var_name])
        when :cvasgn
          var_name = assignment_ast.children[0]
          Parser::AST::Node.new(:cvar, [var_name])
        when :casgn
          scope = assignment_ast.children[0]
          var_name = assignment_ast.children[1]
          Parser::AST::Node.new(:const, [scope, var_name])
        when :send
          send_obj = assignment_ast.children[0]
          asgn_method_name = assignment_ast.children[1]
          args = assignment_ast.children[2..-1]
          Parser::AST::Node.new(:send, [send_obj, asgn_method_name, *args])
        when :gvasgn
          var_name = assignment_ast.children[0]
          Parser::AST::Node.new(:gvar, [var_name])
        else raise ArgumentError
        end
      end

      def complete_assignment(partial_assignment_ast, full_rhs_ast)
        if partial_assignment_ast.type == :send
          send_obj_ast, accessor_method_name, _ = partial_assignment_ast.children
          partial_assignment_ast.updated(nil, [send_obj_ast, :"#{accessor_method_name}=", full_rhs_ast])
        elsif [:lvasgn, :ivasgn, :cvasgn, :casgn, :gvasgn].include?(partial_assignment_ast.type)
          partial_assignment_ast.append(full_rhs_ast)
        end
      end
    end
  end
end
