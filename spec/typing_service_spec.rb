require 'spec_helper'

module Orbacle
  RSpec.describe TypingService do
    specify "primitive int" do
      snippet = <<-END
      42
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    specify "primitive float" do
      snippet = <<-END
      42.0
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Float"))
    end

    specify "primitive bool" do
      snippet = <<-END
      true
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Boolean"))
    end

    specify "primitive nil" do
      snippet = <<-END
      nil
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("nil"))
    end

    specify "string literal" do
      snippet = <<-END
      "foobar"
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("String"))
    end

    specify "string with interpolation" do
      snippet = '
      bar = 42
      "foo#{bar}baz"
      '

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

    specify "symbol with interpolation" do
      snippet = '
      bar = 42
      :"foo#{bar}baz"
      '

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Symbol"))
    end

    specify "regexp" do
      snippet = <<-END
      /foobar/
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Regexp"))
    end

    specify "regexp with interpolation" do
      snippet = '
      bar = 42
      /foo#{bar}/
      '

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Regexp"))
    end

    specify "empty array" do
      snippet = <<-END
      []
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Array", [nil]))
    end

    specify "simple (primitive) literal array" do
      snippet = <<-END
      [1, "foobar"]
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Array", [union([nominal("Integer"), nominal("String")])]))
    end

    specify "empty hash" do
      snippet = <<-END
      {}
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Hash", [nil, nil]))
    end

    specify "hash" do
      snippet = <<-END
      {
        "foo" => 42,
        bar: "nananana",
      }
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Hash", [union([nominal("String"), nominal("Symbol")]), union([nominal("Integer"), nominal("String")])]))
    end

    specify "range" do
      snippet = <<-END
      (2..4)
      END

      result = type_snippet(snippet)

      expect(result).to eq(generic("Range", [nominal("Integer")]))
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

    specify "simple user-defined method call" do
      snippet = <<-END
      class Foo
        def bar
          42
        end
      end
      Foo.new.bar
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    specify "user-defined method call with argument" do
      snippet = <<-END
      class Foo
        def bar(x)
          x.succ
        end
      end
      Foo.new.bar(42)
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    specify "user-defined method call with optional argument" do
      snippet = <<-END
      class Foo
        def bar(s, x = 42)
          x.succ
        end
      end
      Foo.new.bar("foo")
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    specify "user-defined method call with optional argument 2" do
      snippet = <<-END
      class Foo
        def bar(x = 42)
          x
        end
      end
      Foo.new.bar("foo")
      END

      result = type_snippet(snippet)

      expect(result).to eq(union([nominal("Integer"), nominal("String")]))
    end

    specify "method call to self" do
      snippet = <<-END
      class Foo
        def bar
          self.baz
        end

        def baz
          42
        end
      end
      Foo.new.bar
      END

      result = type_snippet(snippet)

      expect(result).to eq(nominal("Integer"))
    end

    def type_snippet(snippet)
      result = ControlFlowGraph.new.process_file(snippet)
      typing_result = TypingService.new.(result.graph, result.message_sends, result.tree)
      typing_result[result.final_node]
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
  end
end
