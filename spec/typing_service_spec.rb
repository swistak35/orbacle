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

    def type_graph(graph, message_sends = [])
      service = TypingService.new
      service.(graph, message_sends)
    end

    def nominal(*args)
      TypingService::NominalType.new(*args)
    end

    def node(type, params = {})
      ControlFlowGraph::Node.new(type, params)
    end
  end
end
