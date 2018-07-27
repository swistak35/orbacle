# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "DataFlowGraph location" do
    describe "primitives" do
      specify "primitive int" do
        snippet = <<-END
        -42
        END

        result = generate_cfg(snippet)

        expect(result.final_node.location.start).to eq(pos(0, 8))
        expect(result.final_node.location.end).to eq(pos(0, 10))
        expect(result.final_node.location.span).to eq(3)
      end

      specify "primitive float" do
        snippet = <<-END
        -42.0
        END

        result = generate_cfg(snippet)

        expect(result.final_node.location.start).to eq(pos(0, 8))
        expect(result.final_node.location.end).to eq(pos(0, 12))
      end
    end

    specify "multiline array" do
      snippet = <<-END
      [1,
       2]
      END

      result = generate_cfg(snippet)

      expect(result.final_node.location.start).to eq(pos(0, 6))
      expect(result.final_node.location.end).to eq(pos(1, 8))
      expect(result.final_node.location.span).to eq(13)
    end

    specify "message send" do
      snippet = <<-END
      some_obj.some_msg(arg1, arg2)
      END

      result = generate_cfg(snippet)

      expect(result.final_node.location.start).to eq(pos(0, 6))
      expect(result.final_node.location.end).to eq(pos(0, 34))
    end

    specify "attr_reader" do
      snippet = <<-END
      class Foo
        attr_reader :bar
      end
      END

      result = generate_cfg(snippet)

      meth = result.tree.find_instance_method_from_class_name("Foo", "bar")
      expect(meth.location.start).to eq(pos(1, 8))
      expect(meth.location.end).to eq(pos(1, 23))
    end

    specify "attr_writer" do
      snippet = <<-END
      class Foo
        attr_writer :bar
      end
      END

      result = generate_cfg(snippet)

      meth = result.tree.find_instance_method_from_class_name("Foo", "bar=")
      expect(meth.location.start).to eq(pos(1, 8))
      expect(meth.location.end).to eq(pos(1, 23))
    end

    specify "attr_accessor" do
      snippet = <<-END
      class Foo
        attr_accessor :bar
      end
      END

      result = generate_cfg(snippet)

      meth = result.tree.find_instance_method_from_class_name("Foo", "bar")
      expect(meth.location.start).to eq(pos(1, 8))
      expect(meth.location.end).to eq(pos(1, 25))

      meth = result.tree.find_instance_method_from_class_name("Foo", "bar=")
      expect(meth.location.start).to eq(pos(1, 8))
      expect(meth.location.end).to eq(pos(1, 25))
    end

    def generate_cfg(file)
      worklist = Worklist.new
      graph = Graph.new
      id_generator = UuidIdGenerator.new
      tree = GlobalTree.new(id_generator)
      service = Builder.new(graph, worklist, tree, id_generator)
      result = service.process_file(Parser::CurrentRuby.parse(file), nil)
      OpenStruct.new(
        final_node: result.node,
        tree: tree)
    end

    def loc(start_arr, end_arr, uri = "", span)
      Location.new(uri, PositionRange.new(pos(*start_arr), pos(*end_arr)), span)
    end

    def pos(line, character)
      Position.new(line, character)
    end
  end
end
