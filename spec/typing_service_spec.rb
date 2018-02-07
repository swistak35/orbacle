require 'spec_helper'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify "int primitive" do
      snippet = <<-END
      42
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    specify "simple lvar reference" do
      snippet = <<-END
      x = 42
      x
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    specify do
      snippet = <<-END
      [1, 2]
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Array", [nominal("Integer")]))
    end

    def type_snippet(snippet)
      graph, _, sends, final_node = generate_cfg(snippet)
      typing_result = type_graph(graph, sends)
      typing_result[final_node]
    end

    def type_graph(graph, message_sends)
      service = TypingService.new
      service.(graph, message_sends)
    end

    def nominal(*args)
      TypingService::NominalType.new(*args)
    end

    def generic(*args)
      TypingService::GenericType.new(*args)
    end

    def generate_cfg(snippet)
      service = ControlFlowGraph.new
      service.process_file(snippet)
    end
  end
end
