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

    specify "method call, without args" do
      snippet = <<-END
      x = 42
      x.succ
      END

      root, _, sends = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:lvar, { var_name: "x" }),
        node(:call_obj))

      expect(sends).to include(
        msend(
          "succ",
          node(:call_obj),
          [],
          node(:call_result)))
    end

    specify "method call, with args" do
      snippet = <<-END
      x = 42
      x.floor(2)
      END

      root, _, sends = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:lvar, { var_name: "x" }),
        node(:call_obj))
      expect(root).to include_edge(
        node(:int, { value: 2 }),
        node(:call_arg))

      expect(sends).to include(
        msend("floor",
              node(:call_obj),
              [node(:call_arg)],
              node(:call_result)))
    end

    specify "method call, with block" do
      snippet = <<-END
      x = 42
      x.map {|y| y }
      END

      root, _, sends = generate_cfg(snippet)

      expect(root).to include_edge(
        node(:block_arg, { var_name: "y" }),
        node(:lvar, { var_name: "y" }))
      expect(root).to include_edge(
        node(:lvar, { var_name: "y" }),
        node(:block_result))

      expect(sends).to include(
        msend("map",
              node(:call_obj),
              [],
              node(:call_result),
              block([node(:block_arg, { var_name: "y" })], node(:block_result))))
    end

    specify "method definition, without formal arguments" do
      snippet = <<-END
      def foo
      end
      END

      root, _, _, _, methods, constants, klasslikes = generate_cfg(snippet)

      expect(methods).to eq([
        [nil, "foo", { line: 1 }],
      ])
      expect(constants).to match_array([])
      expect(klasslikes).to be_empty
    end

    def generate_cfg(snippet)
      service = ControlFlowGraph.new
      service.process_file(snippet)
    end

    def node(type, params = {})
      Orbacle::ControlFlowGraph::Node.new(type, params)
    end

    def msend(message_send, call_obj, call_args, call_result, block = nil)
      ControlFlowGraph::MessageSend.new(message_send, call_obj, call_args, call_result, block)
    end

    def block(args_node, result_node)
      ControlFlowGraph::Block.new(args_node, result_node)
    end
  end
end
