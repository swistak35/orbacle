require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe "DataFlowGraph location" do
    describe "primitives" do
      specify "primitive int" do
        snippet = <<-END
        -42
        END

        result = generate_cfg(snippet)

        expect(result.final_node.location).to eq(loc([1, 9], [1, 12]))
      end

      specify "primitive float" do
        snippet = <<-END
        -42.0
        END

        result = generate_cfg(snippet)

        expect(result.final_node.location).to eq(loc([1, 9], [1, 14]))
      end

      specify "primitive bool" do
        snippet = <<-END
        true
        END

        result = generate_cfg(snippet)

        expect(result.final_node.location).to eq(loc([1, 9], [1, 13]))
      end

      specify "primitive nil" do
        snippet = <<-END
        nil
        END

        result = generate_cfg(snippet)

        expect(result.final_node.location).to eq(loc([1, 9], [1, 12]))
      end
    end

    specify "simple array" do
      snippet = <<-END
      [1,2]
      END

      result = generate_cfg(snippet)

      expect(result.final_node.location).to eq(loc([1, 7], [1, 12]))
    end

    specify "multiline array" do
      snippet = <<-END
      [1,
       2]
      END

      result = generate_cfg(snippet)

      expect(result.final_node.location).to eq(loc([1, 7], [2, 10]))
    end

    specify "message send" do
      snippet = <<-END
      some_obj.some_msg(arg1, arg2)
      END

      result = generate_cfg(snippet)

      expect(result.final_node.location).to eq(loc([1, 7], [1, 36]))
    end

    def generate_cfg(snippet)
      service = DataFlowGraph.new
      service.process_file(snippet, "")
    end

    def loc(start_arr, end_arr, uri = "")
      DataFlowGraph::Location.new(uri, DataFlowGraph::PositionRange.new(DataFlowGraph::Position.new(*start_arr), DataFlowGraph::Position.new(*end_arr)))
    end
  end
end
