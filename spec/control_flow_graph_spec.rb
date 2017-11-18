require 'spec_helper'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify do
      snippet = <<-END
        x = 42
      END

      r = generate_cfg(snippet)
      expect(r.edges).to include(
        edge(
          node(:lvasgn, { var_name: "x" }),
          node(:int, { value: 42 })))
    end

    def generate_cfg(snippet)
      service = ControlFlowGraph.new
      service.process_file(snippet)
    end

    def node(type, params)
      Orbacle::ControlFlowGraph::Node.new(type, params)
    end

    def edge(source, target)
      RGL::Edge::DirectedEdge.new(source, target)
    end
  end
end
