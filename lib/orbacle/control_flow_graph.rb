require 'rgl/adjacency'
require 'parser/current'

module Orbacle
  class ControlFlowGraph
    class Node
      def initialize(type, params = {})
        @type = type
        @params = params
      end

      attr_reader :type, :params

      def ==(other)
        @type == other.type && @params == other.params
      end
    end

    def process_file(file)
      ast = Parser::CurrentRuby.parse(file)

      @graph = RGL::DirectedAdjacencyGraph.new

      initial_local_environment = {}
      _final_node, final_local_environment = process(ast, initial_local_environment)

      return [@graph, final_local_environment]
    end

    private

    def process(ast, lenv)
      case ast.type
      when :lvasgn
        handle_lvasgn(ast, lenv)
      when :int
        handle_int(ast, lenv)
      when :array
        handle_array(ast, lenv)
      when :begin
        handle_begin(ast, lenv)
      when :lvar
        handle_lvar(ast, lenv)
      when :send
        handle_send(ast, lenv)
      else
        raise ArgumentError.new(ast)
      end
    end

    def handle_lvasgn(ast, lenv)
      var_name = ast.children[0].to_s
      expr = ast.children[1]

      n1 = Node.new(:lvasgn, { var_name: var_name })
      @graph.add_vertex(n1)

      n2, n2_lenv = process(expr, lenv)

      @graph.add_edge(n2, n1)

      new_lenv = n2_lenv.merge(var_name => n2)

      return [n1, new_lenv]
    end

    def handle_int(ast, lenv)
      value = ast.children[0]
      n = Node.new(:int, { value: value })
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_array(ast, lenv)
      node_array = Node.new(:array)
      @graph.add_vertex(node_array)

      exprs_nodes = []
      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        exprs_nodes << ast_child_node
        new_lenv
      end
      exprs_nodes.each do |node_expr|
        @graph.add_edge(node_expr, node_array)
      end

      return [node_array, final_lenv]
    end

    def handle_begin(ast, lenv)
      final_node, final_lenv = ast.children.reduce([nil, lenv]) do |(current_node, current_lenv), ast_child|
        process(ast_child, current_lenv)
      end
      return [final_node, final_lenv]
    end

    def handle_lvar(ast, lenv)
      var_name = ast.children[0].to_s

      node_lvar = Node.new(:lvar, { var_name: var_name })
      @graph.add_vertex(node_lvar)

      var_definition_node = lenv[var_name]
      # raise some error if lenv[var_name].nil? - because it means, that it's undefine
      @graph.add_edge(var_definition_node, node_lvar)

      return [node_lvar, lenv]
    end

    def handle_send(ast, lenv)
      obj_expr = ast.children[0]
      message_name = ast.children[1]
      arg_exprs = ast.children[2..-1]

      obj_node, obj_lenv = process(obj_expr, lenv)

      arg_nodes = []
      final_lenv = arg_exprs.reduce(obj_lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        arg_nodes << ast_child_node
        new_lenv
      end

      call_arg_nodes = []
      arg_nodes.each do |arg_node|
        call_arg_node = Node.new(:call_arg)
        @graph.add_vertex(call_arg_node)
        @graph.add_edge(arg_node, call_arg_node)
      end

      call_obj_node = Node.new(:call_obj)
      @graph.add_vertex(call_obj_node)

      @graph.add_edge(obj_node, call_obj_node)

      call_result_node = Node.new(:call_result)
      @graph.add_vertex(call_result_node)

      return [call_result_node, obj_lenv]
    end
  end
end
