require 'spec_helper'
# require 'support/graph_matchers'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify do
      graph = RGL::DirectedAdjacencyGraph.new
      int_node = node(:int, { value: 42 })
      graph.add_vertex(int_node)
      lvar_node = node(:lvar, { var_name: "x" })
      graph.add_vertex(lvar_node)
      graph.add_edge(int_node, lvar_node)

      result = type_graph(graph)

      expect(result[int_node]).to eq(nominal("Integer"))
      expect(result[lvar_node]).to eq(nominal("Integer"))
    end

    specify do
      graph = build_graph([
        int_node1 = node(:int),
        int_node2 = node(:int),
        array_node = node(:array),
      ], [
        [int_node1, array_node],
        [int_node2, array_node],
      ])
      result = type_graph(graph)

      expect(result[array_node]).to eq(generic("Array", [nominal("Integer")]))
    end

    def build_graph(vertices, edges)
      graph = RGL::DirectedAdjacencyGraph.new
      vertices.each do |v|
        graph.add_vertex(v)
      end
      edges.each do |edge|
        graph.add_edge(*edge)
      end
      graph
    end

    def type_graph(graph, message_sends = [])
      service = TypingService.new
      service.(graph, message_sends)
    end

    def nominal(*args)
      TypingService::NominalType.new(*args)
    end

    def generic(*args)
      TypingService::GenericType.new(*args)
    end

    def node(type, params = {})
      ControlFlowGraph::Node.new(type, params)
    end
  end
end
