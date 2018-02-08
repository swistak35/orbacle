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

    specify "local variable assignment" do
      snippet = <<-END
      x = 42
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

    specify "simple (primitive) literal array" do
      snippet = <<-END
      [1, 2]
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Array", [nominal("Integer")]))
    end

    specify "string literal" do
      snippet = <<-END
      "foobar"
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("String"))
    end

    specify "symbol literal" do
      snippet = <<-END
      :foobar
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Symbol"))
    end

    specify "simple (primitive) literal array" do
      snippet = <<-END
      [1, "foobar"]
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Array", [union([nominal("Integer"), nominal("String")])]))
    end

    specify "Integer#succ" do
      snippet = <<-END
      x = 42
      x.succ
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    specify "Array#map" do
      snippet = <<-END
      x = [1,2]
      x.map {|y| y }
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Array", [nominal("Integer")]))
    end

    specify "Array#map" do
      snippet = <<-END
      x = [1,2]
      x.map {|y| y.to_s }
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Array", [nominal("String")]))
    end

    specify "constructor call" do
      snippet = <<-END
      class Foo
      end
      Foo.new
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Foo"))
    end

    def type_snippet(snippet)
      result = generate_cfg(snippet)
      typing_result = type_graph(result.graph, result.message_sends)
      typing_result[result.final_node]
    end

    def type_graph(graph, message_sends)
      service = TypingService.new
      service.(graph, message_sends)
    end

    def nominal(*args)
      TypingService::NominalType.new(*args)
    end

    def union(*args)
      TypingService::UnionType.new(*args)
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
