require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify do
      snippet = <<-END
        x = 42
      END

      root, local_environment = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:int, { value: 42 }),
        node(:lvasgn, { var_name: "x" }))

      expect(local_environment["x"]).to eq(node(:int, { value: 42 }))
    end

    specify do
      snippet = <<-END
      [42, 24]
      END

      root, _ = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:int, { value: 42 }),
        node(:array))
      expect(root).to include_edge(
        node(:int, { value: 24 }),
        node(:array))
    end

    specify do
      snippet = <<-END
      x = 42
      y = 17
      END

      root, local_environment = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:int, { value: 42 }),
        node(:lvasgn, { var_name: "x" }))
      expect(root).to include_edge(
        node(:int, { value: 17 }),
        node(:lvasgn, { var_name: "y" }))

      expect(local_environment["x"]).to eq(node(:int, { value: 42 }))
      expect(local_environment["y"]).to eq(node(:int, { value: 17 }))
    end

    specify "local variable usage" do
      snippet = <<-END
      x = [42, 24]
      x
      END

      root, _ = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:array),
        node(:lvar, { var_name: "x" }))
    end

    specify "method call" do
      snippet = <<-END
      x = 42
      x.succ
      END

      root, _ = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:lvar, { var_name: "x" }),
        node(:call_obj))
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
