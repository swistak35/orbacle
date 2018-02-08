require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify do
      snippet = <<-END
        42
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:int, { value: 42 }))
    end

    specify do
      snippet = <<-END
      -42
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:int, { value: -42 }))
    end

    specify do
      snippet = <<-END
      true
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:bool, { value: true }))
    end

    specify do
      snippet = <<-END
      false
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:bool, { value: false }))
    end

    specify do
      snippet = <<-END
      nil
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:nil))
    end

    specify do
      snippet = <<-END
      [42, 24]
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:array))
      expect(result.graph).to include_edge(
        node(:int, { value: 24 }),
        node(:array))
    end

    specify do
      snippet = <<-END
      x = 42
      y = 17
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:lvasgn, { var_name: "x" }))
      expect(result.graph).to include_edge(
        node(:int, { value: 17 }),
        node(:lvasgn, { var_name: "y" }))

      expect(result.final_lenv["x"]).to eq(node(:int, { value: 42 }))
      expect(result.final_lenv["y"]).to eq(node(:int, { value: 17 }))
    end

    specify "local variable usage" do
      snippet = <<-END
      x = [42, 24]
      x
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:array),
        node(:lvar, { var_name: "x" }))
    end

    specify "method call, without args" do
      snippet = <<-END
      x = 42
      x.succ
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "x" }),
        node(:call_obj))

      expect(result.message_sends).to include(
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

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "x" }),
        node(:call_obj))
      expect(result.graph).to include_edge(
        node(:int, { value: 2 }),
        node(:call_arg))

      expect(result.message_sends).to include(
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

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:block_arg, { var_name: "y" }),
        node(:lvar, { var_name: "y" }))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "y" }),
        node(:block_result))

      expect(result.message_sends).to include(
        msend("map",
              node(:call_obj),
              [],
              node(:call_result),
              block([node(:block_arg, { var_name: "y" })], node(:block_result))))
    end

    specify "simple method definition" do
      snippet = <<-END
      def foo(x)
        x
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:formal_arg, { var_name: "x" }),
        node(:lvar, { var_name: "x" }))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "x" }),
        node(:method_result))
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
