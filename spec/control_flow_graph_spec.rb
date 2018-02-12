require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify "primitive int" do
      snippet = <<-END
        42
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:int, { value: 42 }))
    end

    specify "primitive negative int" do
      snippet = <<-END
      -42
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:int, { value: -42 }))
    end

    specify "primitive float" do
      snippet = <<-END
      42.0
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:float, { value: 42.0 }))
    end

    specify "primitive negative float" do
      snippet = <<-END
      -42.0
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:float, { value: -42.0 }))
    end

    specify "primitive bool" do
      snippet = <<-END
      true
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:bool, { value: true }))
    end

    specify "primitive bool" do
      snippet = <<-END
      false
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:bool, { value: false }))
    end

    specify "primitive nil" do
      snippet = <<-END
      nil
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:nil))
    end

    specify "literal array" do
      snippet = <<-END
      [42, 24]
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:array))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:array))
      expect(result.graph).to include_edge(
        node(:int, { value: 24 }),
        node(:array))
    end

    specify "literal empty array" do
      snippet = <<-END
      []
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:array))
    end

    specify "string literal" do
      snippet = <<-END
      "foobar"
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:str, { value: "foobar" }))
    end

    specify "string heredoc" do
      snippet = <<-END
        <<-HERE
        foo
        HERE
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:str, { value: "        foo\n" }))
    end

    specify "string with interpolation" do
      snippet = '
      bar = 42
      "foo#{bar}baz"
      '

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:dstr))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:lvar, { var_name: "bar" }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foo" }),
        node(:dstr))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "bar" }),
        node(:dstr))
      expect(result.graph).to include_edge(
        node(:str, { value: "baz" }),
        node(:dstr))
    end

    specify "symbol literal" do
      snippet = <<-END
      :foobar
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:sym, { value: :foobar }))
    end

    specify "symbol with interpolation" do
      snippet = '
      bar = 42
      :"foo#{bar}baz"
      '

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:dsym))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:lvar, { var_name: "bar" }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foo" }),
        node(:dsym))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "bar" }),
        node(:dsym))
      expect(result.graph).to include_edge(
        node(:str, { value: "baz" }),
        node(:dsym))
    end

    specify "regexp" do
      snippet = <<-END
      /foobar/
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:regexp, { regopt: [] }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foobar" }),
        node(:regexp, { regopt: [] }))
    end

    specify "regexp with options" do
      snippet = <<-END
      /foobar/im
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:regexp, { regopt: [:i, :m] }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foobar" }),
        node(:regexp, { regopt: [:i, :m] }))
    end

    specify "regexp with interpolation" do
      snippet = '
      bar = 42
      /foo#{bar}/
      '

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:regexp, { regopt: [] }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foo" }),
        node(:regexp, { regopt: [] }))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "bar" }),
        node(:regexp, { regopt: [] }))
    end

    specify "empty hash" do
      snippet = <<-END
      {
        "foo" => 42,
        bar: "nananana",
      }
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:hash))
      expect(result.graph).to include_edge(
        node(:hash_keys),
        node(:hash))
      expect(result.graph).to include_edge(
        node(:hash_values),
        node(:hash))
    end

    specify "hash" do
      snippet = <<-END
      {
        "foo" => 42,
        bar: "nananana",
      }
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:hash))
      expect(result.graph).to include_edge(
        node(:hash_keys),
        node(:hash))
      expect(result.graph).to include_edge(
        node(:hash_values),
        node(:hash))

      expect(result.graph).to include_edge(
        node(:str, { value: "foo" }),
        node(:hash_keys))
      expect(result.graph).to include_edge(
        node(:sym, { value: :bar }),
        node(:hash_keys))

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:hash_values))
      expect(result.graph).to include_edge(
        node(:str, { value: "nananana" }),
        node(:hash_values))
    end

    specify "simple inclusive range" do
      snippet = <<-END
      (2..4)
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:range, { inclusive: true }))
      expect(result.graph).to include_edge(
        node(:range_from),
        node(:range, { inclusive: true }))
      expect(result.graph).to include_edge(
        node(:range_to),
        node(:range, { inclusive: true }))

      expect(result.graph).to include_edge(
        node(:int, { value: 2 }),
        node(:range_from))
      expect(result.graph).to include_edge(
        node(:int, { value: 4 }),
        node(:range_to))
    end

    specify "simple exclusive range" do
      snippet = <<-END
      (2...4)
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:range, { inclusive: false }))
      expect(result.graph).to include_edge(
        node(:range_from),
        node(:range, { inclusive: false }))
      expect(result.graph).to include_edge(
        node(:range_to),
        node(:range, { inclusive: false }))

      expect(result.graph).to include_edge(
        node(:int, { value: 2 }),
        node(:range_from))
      expect(result.graph).to include_edge(
        node(:int, { value: 4 }),
        node(:range_to))
    end

    specify "local variable assignment" do
      snippet = <<-END
      x = 42
      y = 17
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:lvasgn, { var_name: "y" }))
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
      x = 42
      x
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:lvar, { var_name: "x" }))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:lvar, { var_name: "x" }))
    end

    specify "local variables defined in class are not present in method body" do
      snippet = <<-END
      class Foo
        x = 42
        def foo
          x
        end
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:call_result),
        node(:method_result))
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

    specify "method call, with 1 arg" do
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

    specify "method call, with more than one arg" do
      snippet = <<-END
      x = 42
      x.floor(2, 3)
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "x" }),
        node(:call_obj))
      expect(result.graph).to include_edge(
        node(:int, { value: 2 }),
        node(:call_arg))
      expect(result.graph).to include_edge(
        node(:int, { value: 3 }),
        node(:call_arg))

      expect(result.message_sends).to include(
        msend("floor",
              node(:call_obj),
              [node(:call_arg), node(:call_arg)],
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

    specify "empty method definition" do
      snippet = <<-END
      def foo
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:nil),
        node(:method_result))
      expect(result.final_node).to eq(node(:sym, { value: :foo }))
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

    specify "private send in class definition" do
      snippet = <<-END
      class Foo
        private
        def foo
        end
      end
      END

      result = generate_cfg(snippet)

      nodes = result.graph.vertices.select {|v| v.type == :class }
      expect(nodes.size).to eq(1)
      expect(nodes.first.params.fetch(:klass).name).to eq("Foo")
    end

    specify "private send outside class definition" do
      snippet = <<-END
      private
      def foo
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_node(node(:nil))
    end

    specify "method definition with splat argument" do
      snippet = <<-END
      def foo(x, *rest)
        rest
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_node(node(:formal_arg, { var_name: "x" }))
      expect(result.graph).to include_edge(
        node(:formal_restarg, { var_name: "rest" }),
        node(:lvar, { var_name: "rest" }))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "rest" }),
        node(:method_result))
    end

    specify "method definition with splat argument in the middle" do
      snippet = <<-END
      def foo(x, *rest, y)
        rest
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_node(node(:formal_arg, { var_name: "x" }))
      expect(result.graph).to include_node(node(:formal_arg, { var_name: "y" }))
      expect(result.graph).to include_edge(
        node(:formal_restarg, { var_name: "rest" }),
        node(:lvar, { var_name: "rest" }))
    end

    specify "usage of instance variable" do
      snippet = <<-END
      class Foo
        def bar
          @baz
        end
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:ivar_definition),
        node(:ivar))
    end

    specify "usage of instance variable in nested class" do
      snippet = <<-END
      class Fizz
        class Foo
          def bar
            @baz
          end
        end
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:ivar_definition),
        node(:ivar))
    end

    specify "assignment of instance variable" do
      snippet = <<-END
      class Foo
        def bar
          @baz = 42
        end
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:ivasgn, { var_name: "@baz" }))
      expect(result.graph).to include_edge(
        node(:ivasgn, { var_name: "@baz" }),
        node(:ivar_definition))
    end

    specify "distinguish instance variables from class level instance variables" do
      snippet = <<-END
      class Fizz
        @baz = 42

        def setting_baz
          @baz = 57
        end

        def getting_baz
          @baz
        end
      end
      END

      result = generate_cfg(snippet)

      int_57 = result.graph.vertices.find {|v| v.type == :int && v.params[:value] == 57 }
      ivasgn_to_57 = result.graph.adjacent_vertices(int_57).first
      instance_level_baz = result.graph.adjacent_vertices(ivasgn_to_57).first
      expect(result.graph.adjacent_vertices(instance_level_baz)).to match_array([node(:ivar)])

      int_42 = result.graph.vertices.find {|v| v.type == :int && v.params[:value] == 42 }
      ivasgn_to_42 = result.graph.adjacent_vertices(int_42).first
      class_level_baz = result.graph.adjacent_vertices(ivasgn_to_42).first
      expect(result.graph.adjacent_vertices(class_level_baz)).to be_empty
    end

    specify "usage of instance variable inside selfed method" do
      snippet = <<-END
      class Foo
        @baz = 42

        def self.bar
          @baz
        end
      end
      END

      result = generate_cfg(snippet)

      int_42 = result.graph.vertices.find {|v| v.type == :int && v.params[:value] == 42 }
      ivasgn_to_42 = result.graph.adjacent_vertices(int_42).first
      class_level_baz = result.graph.adjacent_vertices(ivasgn_to_42).first
      expect(result.graph.adjacent_vertices(class_level_baz)).to match_array([node(:ivar)])
    end

    specify "usage of class variable" do
      snippet = <<-END
      class Foo
        @@baz
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:cvar_definition),
        node(:cvar))
    end

    specify "assignment of class variable" do
      snippet = <<-END
      class Foo
        @@baz = 42
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:cvasgn, { var_name: "@@baz" }))
      expect(result.graph).to include_edge(
        node(:cvasgn, { var_name: "@@baz" }),
        node(:cvar_definition))
    end

    specify "usage of global variable" do
      snippet = <<-END
      $baz
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:gvar))
      expect(result.graph).to include_edge(
        node(:gvar_definition),
        node(:gvar))
    end

    specify "assignment of global variable" do
      snippet = <<-END
      $baz = 42
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:gvasgn, { var_name: "$baz" }))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:gvasgn, { var_name: "$baz" }))
      expect(result.graph).to include_edge(
        node(:gvasgn, { var_name: "$baz" }),
        node(:gvar_definition))
    end

    specify "usage and assignment of global variable" do
      snippet = <<-END
      class Foo
        def foo
          $baz
        end
      end
      class Bar
        def bar
          $baz = 42
        end
      end
      END

      result = generate_cfg(snippet)

      int_42 = result.graph.vertices.find {|v| v.type == :int && v.params[:value] == 42 }
      gvasgn_to_42 = result.graph.adjacent_vertices(int_42).first
      global_baz = result.graph.adjacent_vertices(gvasgn_to_42).first
      expect(result.graph.adjacent_vertices(global_baz)).to match_array([node(:gvar)])
    end

    specify "assignment of class variable" do
      snippet = <<-END
      class Foo
        @@baz = 42
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:cvasgn, { var_name: "@@baz" }))
      expect(result.graph).to include_edge(
        node(:cvasgn, { var_name: "@@baz" }),
        node(:cvar_definition))
    end

    specify "calling constructor" do
      snippet = <<-END
      class Foo
      end
      Foo.new
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:call_result))
      expect(result.graph).to include_edge_type(
             node(:const, { const_ref: ConstRef.from_full_name("Foo") }),
        node(:call_obj))

      expect(result.message_sends).to include(
        msend("new",
              node(:call_obj),
              [],
              node(:call_result)))
    end

    specify "method call, on self" do
      snippet = <<-END
      class Foo
        def bar
          self.baz
        end
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:self, { selfie: Selfie.instance_from_scope(Scope.new(["Foo"], false)) }),
        node(:call_obj))

      expect(result.message_sends).to include(
        msend(
          "baz",
          node(:call_obj),
          [],
          node(:call_result)))
    end

    specify "method call, on implicit self" do
      snippet = <<-END
      class Foo
        def bar
          baz
        end
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:self, { selfie: Selfie.instance_from_scope(Scope.new(["Foo"], false)) }),
        node(:call_obj))

      expect(result.message_sends).to include(
        msend(
          "baz",
          node(:call_obj),
          [],
          node(:call_result)))
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
