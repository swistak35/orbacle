require 'rgl/adjacency'
require 'parser/current'

module Orbacle
  class ControlFlowGraph
    class Node
      def initialize(type, params)
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

      process(ast)

      return @graph
    end

    private

    def process(ast)
      case ast.type
      when :lvasgn
        handle_lvasgn(ast)
      when :int
        handle_int(ast)
      else
        raise ArgumentError.new(ast)
      end
    end

    def handle_lvasgn(ast)
      var_name = ast.children[0].to_s
      expr = ast.children[1]

      n1 = Node.new(:lvasgn, { var_name: var_name })
      @graph.add_vertex(n1)

      n2 = process(expr)

      @graph.add_edge(n1, n2)

      return n1
    end

    def handle_int(ast)
      value = ast.children[0]
      n = Node.new(:int, { value: value })
      @graph.add_vertex(n)

      return n
    end
  end
end
