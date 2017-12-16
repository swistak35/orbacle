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

    TypingRule = Struct.new(:node, :type)
    NominalType = Struct.new(:name)
    UnionType = Struct.new(:types)
    GenericType = Struct.new(:nominal_type, :type_vars)

    def process_file(file)
      ast = Parser::CurrentRuby.parse(file)

      @graph = RGL::DirectedAdjacencyGraph.new
      @type_rules = []

      process(ast)

      return [@graph, @type_rules]
    end

    private

    def process(ast)
      case ast.type
      when :lvasgn
        handle_lvasgn(ast)
      when :int
        handle_int(ast)
      when :array
        handle_array(ast)
      else
        raise ArgumentError.new(ast)
      end
    end

    def handle_lvasgn(ast)
      var_name = ast.children[0].to_s
      expr = ast.children[1]

      n1 = Node.new(:lvasgn, { var_name: var_name })
      @graph.add_vertex(n1)

      n2, expr_type = process(expr)

      @graph.add_edge(n2, n1)

      return [n1, expr_type]
    end

    def handle_int(ast)
      value = ast.children[0]
      n = Node.new(:int, { value: value })
      @graph.add_vertex(n)

      type = NominalType.new("Integer")

      @type_rules << TypingRule.new(n, type)

      return [n, type]
    end

    def handle_array(ast)
      node_array = Node.new(:array)
      @graph.add_vertex(node_array)

      exprs_nodes = ast.children.map(&method(:process))
      exprs_nodes.each do |node_expr, _expr_type|
        @graph.add_edge(node_expr, node_array)
      end

      exprs_types = exprs_nodes.map {|_node, type| type }.uniq

      type = GenericType.new("Array", [UnionType.new(exprs_types)])

      @type_rules << TypingRule.new(node_array, type)

      return [node_array, type]
    end
  end
end
