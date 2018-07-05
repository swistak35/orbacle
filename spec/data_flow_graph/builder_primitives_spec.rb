require 'spec_helper'
require 'support/graph_matchers'
require 'support/builder_helper'
require 'ostruct'

module Orbacle
  RSpec.describe Builder do
    include BuilderHelper

    describe "#handle_int" do
      specify "int" do
        snippet = <<-END
        42
        END

        result = build_graph(snippet)

        expect(result.graph).to include_node(node(:int, { value: 42 }))
        expect(result.final_node).to eq(node(:int, { value: 42 }))
      end

      specify "negative int" do
        snippet = <<-END
        -42
        END

        result = build_graph(snippet)

        expect(result.final_node).to eq(node(:int, { value: -42 }))
      end
    end

    describe "#handle_float" do
      specify "float" do
        snippet = <<-END
        42.0
        END

        result = build_graph(snippet)

        expect(result.graph).to include_node(node(:float, { value: 42.0 }))
        expect(result.final_node).to eq(node(:float, { value: 42.0 }))
      end

      specify "negative float" do
        snippet = <<-END
        -42.0
        END

        result = build_graph(snippet)

        expect(result.final_node).to eq(node(:float, { value: -42.0 }))
      end
    end

    specify "rational" do
      snippet = <<-END
      2.0r
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:rational))
    end

    specify "complex" do
      snippet = <<-END
      1i
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:complex))
    end

    specify "bool" do
      snippet = <<-END
      true
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:bool, { value: true }))
    end

    specify "bool" do
      snippet = <<-END
      false
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:bool, { value: false }))
    end

    specify "nil" do
      snippet = <<-END
      nil
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:nil))
    end

    specify "string literal" do
      snippet = <<-END
      "foobar"
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:str, { value: "foobar" }))
    end

    specify "string heredoc" do
      snippet = <<-END
      <<-HERE
      foo
      HERE
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:str, { value: "      foo\n" }))
    end

    specify "string with interpolation" do
      snippet = '
      bar = 42
      "foo#{bar}baz"
      '

      result = build_graph(snippet)

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

    specify "execution string" do
      snippet = '
      bar = 42
      `foo#{bar}`
      '

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:xstr))
      expect(result.graph).to include_edge(
        node(:str, { value: "foo" }),
        node(:xstr))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "bar" }),
        node(:xstr))
    end

    specify "symbol literal" do
      snippet = <<-END
      :foobar
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:sym, { value: :foobar }))
    end

    specify "symbol with interpolation" do
      snippet = '
      bar = 42
      :"foo#{bar}baz"
      '

      result = build_graph(snippet)

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

    specify "regexp" do
      snippet = <<-END
      /foobar/
      END

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:regexp, { regopt: [] }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foobar" }),
        node(:regexp, { regopt: [] }))
    end

    specify "regexp with options" do
      snippet = <<-END
      /foobar/im
      END

      result = build_graph(snippet)

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

      result = build_graph(snippet)

      expect(result.final_node).to eq(node(:regexp, { regopt: [] }))
      expect(result.graph).to include_edge(
        node(:str, { value: "foo" }),
        node(:regexp, { regopt: [] }))
      expect(result.graph).to include_edge(
        node(:lvar, { var_name: "bar" }),
        node(:regexp, { regopt: [] }))
    end
  end
end
