require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "DataFlowGraph" do
    describe "primitives" do
      specify "nothing" do
        snippet = ""

        expect do
          generate_cfg(snippet)
        end.not_to raise_error
      end

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
    end

    describe "arrays" do
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

      specify "splat in array" do
        snippet = <<-END
        foo = [1,2]
        [*foo, 3]
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:array))
        expect(result.graph).to include_edge(
          node(:splat_array),
          node(:array))
      end
    end

    describe "hashes" do
      specify "empty hash" do
        snippet = <<-END
        {}
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

      specify "hash with kwsplat" do
        snippet = <<-END
        other = { bar: 1 }
        { foo: 42, **other }
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:hash))

        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "other" }),
          node(:unwrap_hash_keys))
        expect(result.graph).to include_edge(
          node(:unwrap_hash_keys),
          node(:hash_keys))

        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "other" }),
          node(:unwrap_hash_values))
        expect(result.graph).to include_edge(
          node(:unwrap_hash_values),
          node(:hash_values))
      end
    end

    describe "strings" do
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
          node(:lvasgn, { var_name: "bar" }),
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
    end

    describe "symbols" do
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
          node(:lvasgn, { var_name: "bar" }),
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
    end

    describe "regexps" do
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
    end

    describe "ranges" do
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
    end

    describe "defined?" do
      specify "handle defined?" do
        snippet = <<-END
        defined?(x)
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:defined))
      end
    end

    describe "local variables" do
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

        expect(result.final_lenv["x"]).to match_array(node(:lvasgn, { var_name: "x" }))
        expect(result.final_lenv["y"]).to match_array(node(:lvasgn, { var_name: "y" }))
      end

      specify "local variable usage" do
        snippet = <<-END
        x = 42
        x
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:lvar, { var_name: "x" }))
        expect(result.graph).to include_edge(
          node(:lvasgn, { var_name: "x" }),
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
          node(:call_result, { csend: false }),
          node(:method_result))
      end
    end

    describe "method calls" do
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
            node(:call_result, { csend: false })))
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
                node(:call_result, { csend: false })))
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
                node(:call_result, { csend: false })))
      end

      specify "method call, with block" do
        snippet = <<-END
        x = 42
        x.map {|y| y }
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:block_arg),
          node(:lvar, { var_name: "y" }))
        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "y" }),
          node(:block_result))

        expect(result.message_sends).to include(
          msend("map",
                node(:call_obj),
                [],
                node(:call_result, { csend: false }),
                block([node(:block_arg)], node(:block_result))))
      end
    end

    describe "block arguments formats" do
      specify "no arguments" do
        snippet = <<-END
        x.map { 42 }
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:int, { value: 42 }),
          node(:block_result))

        expect(result.message_sends).to include(
          msend("map",
                node(:call_obj),
                [],
                node(:call_result, { csend: false }),
                block([], node(:block_result))))
      end

      specify "1 argument" do
        snippet = <<-END
        x.map {|x| x }
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "x" }),
          node(:block_result))

        expect(result.message_sends).to include(
          msend("map",
                node(:call_obj),
                [],
                node(:call_result, { csend: false }),
                block([node(:block_arg)], node(:block_result))))
      end

      specify "2 arguments" do
        snippet = <<-END
        x.map {|x, y| x; y }
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:lvar, { var_name: "x" }))
        expect(result.graph).to include_node(node(:lvar, { var_name: "y" }))
        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "y" }),
          node(:block_result))

        expect(result.message_sends).to include(
          msend("map",
                node(:call_obj),
                [],
                node(:call_result, { csend: false }),
                block([node(:block_arg), node(:block_arg)], node(:block_result))))
      end

      specify "deconstructed array argument into 1 lvar" do
        snippet = <<-END
        x.map {|(y)| y }
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:lvar, { var_name: "y" }))
        expect(result.graph).to include_edge(
          node(:block_arg),
          node(:unwrap_array))
        expect(result.graph).to include_edge(
          node(:unwrap_array),
          node(:lvar, { var_name: "y" }))
        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "y" }),
          node(:block_result))
      end

      specify "deconstructed array argument into 2 lvars" do
        snippet = <<-END
        x.map {|(x, y)| x; y }
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:lvar, { var_name: "y" }))
        expect(result.graph).to include_edge(
          node(:block_arg),
          node(:unwrap_array))
        expect(result.graph).to include_edge(
          node(:unwrap_array),
          node(:lvar, { var_name: "y" }))

        expect(result.graph).to include_node(node(:lvar, { var_name: "x" }))
        expect(result.graph).to include_edge(
          node(:block_arg),
          node(:unwrap_array))
        expect(result.graph).to include_edge(
          node(:unwrap_array),
          node(:lvar, { var_name: "x" }))

        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "y" }),
          node(:block_result))
      end

      specify "deconstructed array argument into deconstructed array argument" do
        snippet = <<-END
        x.map {|(x, (y))| y }
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:lvar, { var_name: "y" }))
        expect(result.graph).to include_edge(
          node(:block_arg),
          node(:unwrap_array))
        expect(result.graph).to include_edge(
          node(:unwrap_array),
          node(:unwrap_array))
        expect(result.graph).to include_edge(
          node(:unwrap_array),
          node(:lvar, { var_name: "y" }))
        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "y" }),
          node(:block_result))
      end
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

    specify "method definition with 1 arg" do
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

    specify "method definition with optional argument" do
      snippet = <<-END
      def foo(x = 42)
        x
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:formal_optarg, { var_name: "x" }))
      expect(result.graph).to include_edge(
        node(:formal_optarg, { var_name: "x" }),
        node(:lvar, { var_name: "x" }))
    end

    specify "method definition with keyword arguments" do
      snippet = <<-END
      def foo(x, bar:, baz:)
        bar
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:formal_kwarg, { var_name: "bar" }),
        node(:lvar, { var_name: "bar" }))
      expect(result.graph).to include_node(
        node(:formal_kwarg, { var_name: "baz" }))
    end

    specify "method definition with optional keyword arguments" do
      snippet = <<-END
      def foo(x, bar: 42, baz: "foo")
        bar
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:formal_kwoptarg, { var_name: "bar" }))
      expect(result.graph).to include_edge(
        node(:formal_kwoptarg, { var_name: "bar" }),
        node(:lvar, { var_name: "bar" }))
    end

    specify "method definition with keyword args splat" do
      snippet = <<-END
      def foo(x, **kwargs)
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_node(
        node(:formal_kwrestarg, { var_name: "kwargs" }))
    end

    specify "method definition with unnamed keyword args splat" do
      snippet = <<-END
      def foo(x, **)
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_node(
        node(:formal_kwrestarg, { var_name: nil }))
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

    specify "method definition with unnamed splat argument" do
      snippet = <<-END
      def foo(x, *)
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_node(node(:formal_restarg, { var_name: nil }))
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

    describe "returning" do
      specify "method definition, using return with value" do
        snippet = <<-END
        def foo(x)
          return 42
          17
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:int, { value: 42 }),
          node(:method_result))
        expect(result.graph).to include_edge(
          node(:int, { value: 17 }),
          node(:method_result))
      end

      specify "method definition, using empty return" do
        snippet = <<-END
        def foo(x)
          return
          17
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:nil),
          node(:method_result))
        expect(result.graph).to include_edge(
          node(:int, { value: 17 }),
          node(:method_result))
      end

      specify "method definition, multiple-value return" do
        snippet = <<-END
        def foo(x)
          return 3, 7
          17
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:int, { value: 3 }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:int, { value: 7 }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:array),
          node(:method_result))
      end
    end

    describe "instance variables" do
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
    end

    describe "class variables" do
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
    end

    describe "global variables" do
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

      specify "regexp-specific global variables" do
        snippet = <<-END
        $`
        $&
        $'
        $+
        $1
        $9
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:backref, { ref: "$`" }))
        expect(result.graph).to include_node(node(:backref, { ref: "$&" }))
        expect(result.graph).to include_node(node(:backref, { ref: "$'" }))
        expect(result.graph).to include_node(node(:backref, { ref: "$+" }))

        expect(result.graph).to include_node(node(:nthref, { ref: "1" }))
        expect(result.graph).to include_node(node(:nthref, { ref: "9" }))
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
    end

    describe "constants" do
      specify "assignment to constant" do
        snippet = <<-END
        Foo = 42
        END

        result = generate_cfg(snippet)

        nesting = Nesting.empty
        const_ref = ConstRef.from_full_name("Foo", nesting)

        expect(result.final_node).to eq(node(:casgn, { const_ref: const_ref }))
        expect(result.graph).to include_edge(
          node(:int, { value: 42 }),
          node(:casgn, { const_ref: const_ref }))
        expect(result.graph).to include_edge(
          node(:casgn, { const_ref: const_ref }),
          node(:const_definition))
      end
    end

    specify "calling constructor" do
      snippet = <<-END
      class Foo
      end
      Foo.new
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:call_result, { csend: false }))
      expect(result.graph).to include_edge_type(
        node(:const, { const_ref: ConstRef.from_full_name("Foo", Nesting.empty) }),
        node(:call_obj))

      expect(result.message_sends).to include(
        msend("new",
              node(:call_obj),
              [],
              node(:call_result, { csend: false })))
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
          node(:call_result, { csend: false })))
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
          node(:call_result, { csend: false })))
    end

    specify "super call without arguments" do
      snippet = <<-END
      class Foo
        def bar
          super()
        end
      end
      END

      result = generate_cfg(snippet)

      super_send = result.message_sends.first
      expect(super_send).to be_a(Worklist::SuperSend)
      expect(super_send.send_args).to match_array([])
      expect(super_send.send_result).to eq(node(:call_result))
      expect(super_send.block).to be_nil
    end

    specify "super call with arguments" do
      snippet = <<-END
      class Foo
        def bar
          super(42)
        end
      end
      END

      result = generate_cfg(snippet)

      super_send = result.message_sends.first
      expect(super_send).to be_a(Worklist::SuperSend)
      expect(super_send.send_args).to match_array([node(:call_arg)])
      expect(super_send.send_result).to eq(node(:call_result))
      expect(super_send.block).to be_nil
    end

    specify "super zero-arity call" do
      snippet = <<-END
      class Foo
        def bar
          super
        end
      end
      END

      result = generate_cfg(snippet)

      zsuper_send = result.message_sends.first
      expect(zsuper_send).to be_a(Worklist::Super0Send)
      expect(zsuper_send.send_result).to eq(node(:call_result))
      expect(zsuper_send.block).to be_nil
    end

    specify "control flow `and` operator" do
      snippet = <<-END
      false and 42
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:bool, { value: false }),
        node(:and))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:and))
    end

    specify "control flow `and` operator - using correct lenv" do
      snippet = <<-END
      (x = 17) and x
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:lvasgn, { var_name: "x" }),
        node(:lvar, { var_name: "x" }))
    end

    specify "control flow `or` operator" do
      snippet = <<-END
      false or 42
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:bool, { value: false }),
        node(:or))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:or))
    end

    specify "control flow `&&` operator" do
      snippet = <<-END
      false && 42
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:bool, { value: false }),
        node(:and))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:and))
    end

    specify "control flow `||` operator" do
      snippet = <<-END
      false || 42
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:bool, { value: false }),
        node(:or))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:or))
    end

    specify "branching" do
      snippet = <<-END
      if 1
        2
      else
        3
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 2 }),
        node(:if_result))
      expect(result.graph).to include_edge(
        node(:int, { value: 3 }),
        node(:if_result))
      expect(result.final_node).to eq(node(:if_result))
    end

    specify "branching - without iffalse" do
      snippet = <<-END
      if 42
        17
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 17 }),
        node(:if_result))
      expect(result.graph).to include_edge(
        node(:nil),
        node(:if_result))
      expect(result.final_node).to eq(node(:if_result))
    end

    specify "branching - without iftrue" do
      snippet = <<-END
      unless 42
        17
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:int, { value: 17 }),
        node(:if_result))
      expect(result.graph).to include_edge(
        node(:nil),
        node(:if_result))
      expect(result.final_node).to eq(node(:if_result))
    end

    specify "branching - using correct lenvs" do
      snippet = <<-END
      if (x = 42) && (y = 17)
        x
      else
        y
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_edge(
        node(:lvasgn, { var_name: "x" }),
        node(:lvar, { var_name: "x" }))
      expect(result.graph).to include_edge(
        node(:lvasgn, { var_name: "y" }),
        node(:lvar, { var_name: "y" }))
    end

    specify "branching - using correct lenvs" do
      snippet = <<-END
      if "meh"
        x = 42
      else
        x = 17
      end
      x
      END

      result = generate_cfg(snippet)

      expect(result.final_lenv["x"]).to match_array([
        node(:lvasgn, { var_name: "x" }),
        node(:lvasgn, { var_name: "x" }),
      ])

      int_42 = result.graph.vertices.find {|v| v.type == :int && v.params[:value] == 42 }
      lvasgn_to_42 = result.graph.adjacent_vertices(int_42).first
      expect(result.graph.adjacent_vertices(lvasgn_to_42)).to include(node(:lvar, { var_name: "x" }))

      int_17 = result.graph.vertices.find {|v| v.type == :int && v.params[:value] == 17 }
      lvasgn_to_17 = result.graph.adjacent_vertices(int_17).first
      expect(result.graph.adjacent_vertices(lvasgn_to_17)).to include(node(:lvar, { var_name: "x" }))
    end

    describe "multiple assignment" do
      specify "multiple assignment - local variables" do
        snippet = <<-END
        x, y = [1,2,3]
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:array)])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 0 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:lvasgn, { var_name: "x" })])

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend1.send_obj)).to eq([node(:array)])
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend1.send_result)).to eq([node(:lvasgn, { var_name: "y" })])

        expect(result.final_node).to eq(node(:array))
        expect(result.graph).to include_edge(
          node(:lvasgn, { var_name: "x" }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:lvasgn, { var_name: "y" }),
          node(:array))
      end

      specify "multiple assignment - nested local variables" do
        snippet = <<-END
        x, (y, z) = [1,[2,3]]
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:array)])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 0 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:lvasgn, { var_name: "x" })])

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend1.send_obj)).to eq([node(:array)])
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend1.send_result)).to eq([node(:call_obj)])

        msend2 = result.message_sends[2]
        expect(msend2.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend2.send_obj)).to eq([msend1.send_result])
        expect(msend2.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend2.send_args[0])).to eq([node(:int, { value: 0 })])
        expect(result.graph.adjacent_vertices(msend2.send_result)).to eq([node(:lvasgn, { var_name: "y" })])

        #msend3 is msend1 again

        msend4 = result.message_sends[4]
        expect(msend4.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend4.send_obj)).to eq([msend1.send_result])
        expect(msend4.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend4.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend4.send_result)).to eq([node(:lvasgn, { var_name: "z" })])

        expect(result.final_node).to eq(node(:array))
        expect(result.graph).to include_edge(
          node(:lvasgn, { var_name: "x" }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:array),
          node(:array))
      end

      specify "multiple assignment - instance variables" do
        snippet = <<-END
        class Foo
          def foo
            @x, @y = [1,2,3]
          end
        end
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:array)])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 0 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:ivasgn, { var_name: "@x" })])

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend1.send_obj)).to eq([node(:array)])
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend1.send_result)).to eq([node(:ivasgn, { var_name: "@y" })])

        expect(result.graph).to include_edge(
          node(:ivasgn, { var_name: "@x" }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:ivasgn, { var_name: "@y" }),
          node(:array))
      end

      specify "multiple assignment - class variables" do
        snippet = <<-END
        class Foo
          def foo
            @@x, @@y = [1,2,3]
          end
        end
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:array)])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 0 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:cvasgn, { var_name: "@@x" })])

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend1.send_obj)).to eq([node(:array)])
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend1.send_result)).to eq([node(:cvasgn, { var_name: "@@y" })])

        expect(result.graph).to include_edge(
          node(:cvasgn, { var_name: "@@x" }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:cvasgn, { var_name: "@@y" }),
          node(:array))
      end

      specify "multiple assignment - self send assignment" do
        snippet = <<-END
        self.x, self.y = [1, 2]
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:array)])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 0 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:call_arg)])

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("x=")
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:call_result, { csend: false })])
        expect(result.graph.adjacent_vertices(msend1.send_result)).to eq([node(:array)])

        msend2 = result.message_sends[2]
        expect(msend2.message_send).to eq("[]")
        expect(result.graph.reverse.adjacent_vertices(msend2.send_obj)).to eq([node(:array)])
        expect(msend2.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend2.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend2.send_result)).to eq([node(:call_arg)])

        msend3 = result.message_sends[3]
        expect(msend3.message_send).to eq("y=")
        expect(msend3.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend3.send_args[0])).to eq([node(:call_result, { csend: false })])
        expect(result.graph.adjacent_vertices(msend3.send_result)).to eq([node(:array)])

        expect(result.final_node).to eq(node(:array))
        expect(result.graph).to include_edge(
          node(:call_result, { csend: false }),
          node(:array))
      end
    end

    specify "alias method" do
      snippet = <<-END
      class Foo
        alias :foo :bar
      end
      END

      generate_cfg(snippet)
    end

    specify "alias global variable" do
      snippet = <<-END
      alias $foo $bar
      END

      generate_cfg(snippet)
    end

    describe "loops" do
      specify "empty while loop" do
        snippet = <<-END
        while true
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "simple while loop" do
        snippet = <<-END
        while true
          42
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.graph).to include_node(node(:int, { value: 42 }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "empty until loop" do
        snippet = <<-END
        until true
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "simple until loop" do
        snippet = <<-END
        until true
          42
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.graph).to include_node(node(:int, { value: 42 }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "empty post-while loop" do
        snippet = <<-END
        begin
        end while true
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "post-while loop" do
        snippet = <<-END
        begin
          42
        end while true
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.graph).to include_node(node(:int, { value: 42 }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "empty post-until loop" do
        snippet = <<-END
        begin
        end until true
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "post-until loop" do
        snippet = <<-END
        begin
          42
        end until true
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_node(node(:bool, { value: true }))
        expect(result.graph).to include_node(node(:int, { value: 42 }))
        expect(result.final_node).to eq(node(:nil))
      end

      specify "break" do
        snippet = <<-END
        while true
          break
        end
        END

        generate_cfg(snippet)
      end

      specify "next" do
        snippet = <<-END
        while true
          next
        end
        END

        generate_cfg(snippet)
      end

      specify "redo" do
        snippet = <<-END
        while true
          redo
        end
        END

        generate_cfg(snippet)
      end
    end

    specify "case-when branching (without else)" do
      snippet = <<-END
      case true
      when :foo then "foo"
      when :bar then 42
      end
      END

      result = generate_cfg(snippet)

      expect(result.graph).to include_node(node(:bool, { value: true }))
      expect(result.graph).to include_node(node(:sym, { value: :foo }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foo" }),
        node(:case_result))
      expect(result.graph).to include_edge(
        node(:int, { value: 42 }),
        node(:case_result))
    end

    describe "yielding" do
      specify "empty yield" do
        snippet = <<-END
        def foo
          yield
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:nil),
          node(:method_result))
        expect(result.graph).to include_edge(
          node(:nil),
          node(:yield))
      end

      specify "simple yield" do
        snippet = <<-END
        def foo
          yield 42
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:nil),
          node(:method_result))
        expect(result.graph).to include_edge(
          node(:int, { value: 42 }),
          node(:yield))
      end
    end

    specify "passing block" do
      snippet = <<-END
        x = Proc.new {|x| x }
        foo(&x)
      END

      result = generate_cfg(snippet)
    end

    describe "rescue" do
      specify "rescue without assigning error" do
        snippet = <<-END
        begin
        rescue
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:nil),
          node(:rescue))
        expect(result.final_node).to eq(node(:rescue))
      end

      specify "rescue without else" do
        snippet = <<-END
        begin
          78
        rescue => e
          e
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:lvasgn, { var_name: "e" }),
          node(:lvar, { var_name: "e" }))
        expect(result.graph).to include_edge(
          node(:int, { value: 78 }),
          node(:rescue))
        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "e" }),
          node(:rescue))
        expect(result.final_node).to eq(node(:rescue))
      end

      specify "rescue with else" do
        snippet = <<-END
        begin
        rescue => e
          e
        else
          42
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:int, { value: 42 }),
          node(:rescue))
        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "e" }),
          node(:rescue))
        expect(result.final_node).to eq(node(:rescue))
      end

      specify "rescue specific error" do
        snippet = <<-END
        begin
        rescue SomeError, OtherError => e
          e
        end
        END

        result = generate_cfg(snippet)

        nesting = Nesting.empty
        some_error_ref = ConstRef.from_full_name("SomeError", nesting)
        other_error_ref = ConstRef.from_full_name("OtherError", nesting)

        expect(result.graph).to include_edge(
          node(:const, { const_ref: some_error_ref }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:const, { const_ref: other_error_ref }),
          node(:array))
        expect(result.graph).to include_edge(
          node(:array),
          node(:unwrap_array))
        expect(result.graph).to include_edge(
          node(:unwrap_array),
          node(:lvasgn, { var_name: "e" }))
      end

      specify "retry keyword" do
        snippet = <<-END
        begin
          42
        rescue
          retry
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:nil),
          node(:rescue))
        expect(result.final_node).to eq(node(:rescue))
      end

      specify "empty ensure" do
        snippet = <<-END
        begin
        ensure
        end
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:ensure))
      end

      specify "ensure" do
        snippet = <<-END
        begin
          42
        rescue
          78
        else
          23
        ensure
          17
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:rescue),
          node(:ensure))
        expect(result.graph).to include_edge(
          node(:int, { value: 17 }),
          node(:ensure))
        expect(result.final_node).to eq(node(:ensure))
      end
    end

    specify "simple module" do
      snippet = <<-END
      module Foo
      end
      END

      result = generate_cfg(snippet)

      expect(result.final_node).to eq(node(:nil))
    end

    describe "operator assginments" do
      specify "for lvar, usage of +=" do
        snippet = <<-END
        a = 42
        a += 1
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:lvasgn, { var_name: "a" }))

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("+")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:lvar, { var_name: "a" })])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:lvasgn, { var_name: "a" })])
      end

      specify "for ivar, usage of +=" do
        snippet = <<-END
        class Foo
          @a += 1
        end
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("+")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:ivar)])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:ivasgn, { var_name: "@a" })])
      end

      specify "for cvar, usage of +=" do
        snippet = <<-END
        class Foo
          @@a += 1
        end
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("+")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:cvar)])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:cvasgn, { var_name: "@@a" })])
      end

      specify "for send, usage of +=" do
        snippet = <<-END
        class Foo
          @b.a += 1
        end
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("a")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:ivar)])
        expect(msend0.send_args.size).to eq(0)

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("+")
        expect(result.graph.reverse.adjacent_vertices(msend1.send_obj)).to eq([node(:call_result, { csend: false })])
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend1.send_result)).to eq([node(:call_arg)])

        msend2 = result.message_sends[2]
        expect(msend2.message_send).to eq("a=")
        expect(result.graph.reverse.adjacent_vertices(msend2.send_obj)).to eq([node(:ivar)])
        expect(msend2.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend2.send_args[0])).to eq([node(:call_result, { csend: false })])
      end

      specify "for const, usage of +=" do
        snippet = <<-END
        class Foo
          Bar += 1
        end
        END

        result = generate_cfg(snippet)

        nesting = Nesting.empty.increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
        const_ref = ConstRef.from_full_name("Bar", nesting)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("+")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:const, { const_ref: const_ref })])
        expect(msend0.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend0.send_args[0])).to eq([node(:int, { value: 1 })])
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:casgn, { const_ref: const_ref })])
      end

      specify "for lvar, usage of ||=" do
        snippet = <<-END
        a = 42
        a ||= 1
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:lvasgn, { var_name: "a" }))

        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "a" }),
          node(:or))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:or))
        expect(result.graph).to include_edge(
          node(:or),
          node(:lvasgn, { var_name: "a" }))
      end

      specify "for ivar, usage of ||=" do
        snippet = <<-END
        class Foo
          @a ||= 1
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:ivar),
          node(:or))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:or))
        expect(result.graph).to include_edge(
          node(:or),
          node(:ivasgn, { var_name: "@a" }))
      end

      specify "for cvar, usage of ||=" do
        snippet = <<-END
        class Foo
          @@a ||= 1
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:cvar),
          node(:or))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:or))
        expect(result.graph).to include_edge(
          node(:or),
          node(:cvasgn, { var_name: "@@a" }))
      end

      specify "for send, usage of ||=" do
        snippet = <<-END
        class Foo
          @b.a ||= 1
        end
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("a")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:ivar)])
        expect(msend0.send_args.size).to eq(0)
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:or)])

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("a=")
        expect(result.graph.reverse.adjacent_vertices(msend1.send_obj)).to eq([node(:ivar)])
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:or)])
      end

      specify "for const, usage of ||=" do
        snippet = <<-END
        class Foo
          Bar ||= 1
        end
        END

        result = generate_cfg(snippet)

        nesting = Nesting.empty.increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
        const_ref = ConstRef.from_full_name("Bar", nesting)

        expect(result.graph).to include_edge(
          node(:const, { const_ref: const_ref }),
          node(:or))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:or))
        expect(result.graph).to include_edge(
          node(:or),
          node(:casgn, { const_ref: const_ref }))
      end

      specify "for lvar, usage of &&=" do
        snippet = <<-END
        a = 42
        a &&= 1
        END

        result = generate_cfg(snippet)

        expect(result.final_node).to eq(node(:lvasgn, { var_name: "a" }))

        expect(result.graph).to include_edge(
          node(:lvar, { var_name: "a" }),
          node(:and))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:and))
        expect(result.graph).to include_edge(
          node(:and),
          node(:lvasgn, { var_name: "a" }))
      end

      specify "for ivar, usage of &&=" do
        snippet = <<-END
        class Foo
          @a &&= 1
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:ivar),
          node(:and))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:and))
        expect(result.graph).to include_edge(
          node(:and),
          node(:ivasgn, { var_name: "@a" }))
      end

      specify "for cvar, usage of &&=" do
        snippet = <<-END
        class Foo
          @@a &&= 1
        end
        END

        result = generate_cfg(snippet)

        expect(result.graph).to include_edge(
          node(:cvar),
          node(:and))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:and))
        expect(result.graph).to include_edge(
          node(:and),
          node(:cvasgn, { var_name: "@@a" }))
      end

      specify "for send, usage of &&=" do
        snippet = <<-END
        class Foo
          @b.a &&= 1
        end
        END

        result = generate_cfg(snippet)

        msend0 = result.message_sends.first
        expect(msend0.message_send).to eq("a")
        expect(result.graph.reverse.adjacent_vertices(msend0.send_obj)).to eq([node(:ivar)])
        expect(msend0.send_args.size).to eq(0)
        expect(result.graph.adjacent_vertices(msend0.send_result)).to eq([node(:and)])

        msend1 = result.message_sends[1]
        expect(msend1.message_send).to eq("a=")
        expect(result.graph.reverse.adjacent_vertices(msend1.send_obj)).to eq([node(:ivar)])
        expect(msend1.send_args.size).to eq(1)
        expect(result.graph.reverse.adjacent_vertices(msend1.send_args[0])).to eq([node(:and)])
      end

      specify "for const, usage of &&=" do
        snippet = <<-END
        class Foo
          Bar &&= 1
        end
        END

        result = generate_cfg(snippet)

        nesting = Nesting.empty.increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
        const_ref = ConstRef.from_full_name("Bar", nesting)

        expect(result.graph).to include_edge(
          node(:const, { const_ref: const_ref }),
          node(:and))
        expect(result.graph).to include_edge(
          node(:int, { value: 1 }),
          node(:and))
        expect(result.graph).to include_edge(
          node(:and),
          node(:casgn, { const_ref: const_ref }))
      end
    end

    describe "lambdas" do
      specify "simple" do
        snippet = <<-END
        -> { 42 }
        END

        result = generate_cfg(snippet)
        expect(result.final_node).to eq(node(:lambda, { id: 0 }))
      end

      specify "with one argument" do
        snippet = <<-END
        ->() { 42 }
        ->(x) { 42 }
        END

        result = generate_cfg(snippet)
        expect(result.final_node).to eq(node(:lambda, { id: 1 }))
      end
    end

    describe "attr_reader/writer/accessor" do
      specify "simple attr_reader example" do
        file = <<-END
        class Foo
          attr_reader :bar, :baz
        end
        END

        result = generate_cfg(file)

        expect(result.graph).to include_edge(
          node(:ivar_definition),
          node(:method_result))
      end

      specify "simple attr_writer example" do
        file = <<-END
        class Foo
          attr_writer :bar, :baz
        end
        END

        result = generate_cfg(file)

        expect(result.graph).to include_edge(
          node(:formal_arg, { var_name: "_attr_writer" }),
          node(:ivar_definition))
        expect(result.graph).to include_edge(
          node(:ivar_definition),
          node(:method_result))
      end
    end

    def generate_cfg(snippet)
      worklist = Worklist.new
      graph = DataFlowGraph::Graph.new
      service = DataFlowGraph::Builder.new(graph, worklist, GlobalTree.new)
      result = service.process_file(snippet, "")
      OpenStruct.new(
        graph: graph,
        final_lenv: result.context.lenv,
        final_node: result.node,
        message_sends: worklist.message_sends.to_a)
    end

    def node(type, params = {})
      Orbacle::DataFlowGraph::Node.new(type, params)
    end

    def msend(message_send, call_obj, call_args, call_result, block = nil)
      Worklist::MessageSend.new(message_send, call_obj, call_args, call_result, block)
    end

    def block(args_node, result_node)
      DataFlowGraph::Block.new(args_node, result_node)
    end
  end
end
