require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify do
      snippet = <<-END
        x = 42
      END

      r = generate_cfg(snippet)
      expect(r).to include_edge(
        node(:int, { value: 42 }),
        node(:lvasgn, { var_name: "x" }))
    end

    specify do
      snippet = <<-END
      [42, 24]
      END

      r = generate_cfg(snippet)
      expect(r).to include_edge(
        node(:int, { value: 42 }),
        node(:array))
      expect(r).to include_edge(
        node(:int, { value: 24 }),
        node(:array))
    end

    specify do
    end

    def generate_cfg(snippet)
      service = ControlFlowGraph.new
      service.process_file(snippet)
    end

    def node(type, params = {})
      Orbacle::ControlFlowGraph::Node.new(type, params)
    end
  end
end
