require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify do
      snippet = <<-END
        x = 42
      END

      root, typings, local_environment = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:int, { value: 42 }),
        node(:lvasgn, { var_name: "x" }))

      expect(typings).to include(
        equal(var(0), nominal("Integer")))

      expect(typings).to include(
        rule(node(:int, { value: 42}), nominal_type("Integer")))

      expect(local_environment["x"]).to eq(nominal_type("Integer"))
    end

    specify do
      snippet = <<-END
      [42, 24]
      END

      root, typings = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:int, { value: 42 }),
        node(:array))
      expect(root).to include_edge(
        node(:int, { value: 24 }),
        node(:array))

      expect(typings).to include(
        rule(node(:array), generic_type("Array", [union_type([nominal_type("Integer")])])))
    end

    specify do
      snippet = <<-END
      [42, 24].map {|i| i.next }
      END

      root, typings = generate_cfg(snippet)

      # expect(root).to include_edge(
      #   node(:int, { value: 42 }),
      #   node(:array))
      # expect(root).to include_edge(
      #   node(:int, { value: 24 }),
      #   node(:array))

      # expect(typings).to include(
      #   rule(node(:array), generic_type("Array", [union_type([nominal_type("Integer")])])))
    end

    def generate_cfg(snippet)
      service = ControlFlowGraph.new
      service.process_file(snippet)
    end

    def node(type, params = {})
      Orbacle::ControlFlowGraph::Node.new(type, params)
    end

    def rule(node, type)
      Orbacle::ControlFlowGraph::TypingRule.new(node, type)
    end

    def nominal_type(name)
      Orbacle::ControlFlowGraph::NominalType.new(name)
    end

    def union_type(types)
      Orbacle::ControlFlowGraph::UnionType.new(types)
    end

    def generic_type(name, type_vars)
      Orbacle::ControlFlowGraph::GenericType.new(name, type_vars)
    end
  end
end
