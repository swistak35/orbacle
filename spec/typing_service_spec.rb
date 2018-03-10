require 'spec_helper'

module Orbacle
  RSpec.describe TypingService do
    describe "primitives" do
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
    end

    describe "strings" do
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
    end

    describe "symbols" do
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
    end

    describe "regexps" do
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
    end

    describe "arrays" do
      specify "empty array" do
        snippet = <<-END
        []
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nil]))
      end

      specify "simple (primitive) literal array" do
        snippet = <<-END
        [1, 2]
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "(primitive) heterogenous literal array" do
        snippet = <<-END
        [1, "foobar"]
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("Integer"), nominal("String")])]))
      end

      specify "array with splat" do
        snippet = <<-END
        foo = [1,2]
        [*foo, "foobar"]
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("Integer"), nominal("String")])]))
      end
    end

    describe "hashes" do
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

      specify "hash with kwsplat" do
        snippet = <<-END
        x = { "foo" => 42 }
        {
          bar: "nananana",
          **x,
        }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Hash", [union([nominal("Symbol"), nominal("String")]), union([nominal("String"), nominal("Integer")])]))
      end
    end

    describe "ranges" do
      specify "range" do
        snippet = <<-END
        (2..4)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Range", [nominal("Integer")]))
      end
    end

    describe "local variables" do
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
    end

    describe "instance variables" do
      specify "usage of uninitialized instance variable" do
        snippet = <<-END
        class Foo
          def bar
            @baz
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar)).to eq(nil)
      end

      specify "assignment of instance variable" do
        snippet = <<-END
        class Foo
          def bar
            @baz = 42
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar_definition)).to eq(nominal("Integer"))
      end

      specify "usage of instance variable" do
        snippet = <<-END
        class Foo
          def foo
            @baz = 42
          end

          def bar
            @baz
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar)).to eq(nominal("Integer"))
      end

      specify "distinguish instance variables from class level instance variables" do
        snippet = <<-END
        class Fizz
          @baz = 42

          def setting_baz
            @baz = "foo"
          end

          def getting_baz
            @baz
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar_definition)).to eq(nominal("String"))
        expect(find_by_node(result, :clivar_definition)).to eq(nominal("Integer"))
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

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar)).to eq(nominal("Integer"))
      end
    end

    describe "global variables" do
      specify "usage of global variable" do
        snippet = <<-END
        $baz
        END

        result = type_snippet(snippet)

        expect(result).to eq(nil)
      end

      specify "assignment and usage of global variable" do
        snippet = <<-END
        $baz = 42
        $baz
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "nth-ref global variables" do
        snippet = <<-END
        $1
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "back-ref global variables" do
        snippet = <<-END
        $`
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end
    end

    describe "defined?" do
      specify "handle defined?" do
        snippet = <<-END
        defined?(x)
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("nil")]))
      end
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

    describe "user-defined methods" do
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

      specify "user-defined method call with splat argument" do
        snippet = <<-END
        class Foo
          def bar(*args)
            args
          end
        end
        Foo.new.bar("foo", 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("String"), nominal("Integer")])]))
      end

      specify "user-defined method call with named argument" do
        snippet = <<-END
        class Foo
          def bar(x:)
            x.succ
          end
        end
        Foo.new.bar(x: 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "user-defined method call with 2 named arguments" do
        snippet = <<-END
        class Foo
          def bar(x:, y:)
            y
          end
        end
        Foo.new.bar(x: 42, y: "foo")
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Integer"), nominal("String")]))
      end

      specify "user-defined method call with named argument" do
        snippet = <<-END
        class Foo
          def bar(**kwargs)
            kwargs
          end
        end
        Foo.new.bar(x: 42, y: "foo")
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Hash", [nominal("Symbol"), union([nominal("Integer"), nominal("String")])]))
      end

      specify "user-defined method call with named optional argument" do
        snippet = <<-END
        class Foo
          def bar(x: "foo")
            x
          end
        end
        Foo.new.bar(x: 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Integer")]))
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

      specify "method with simple yield" do
        snippet = <<-END
        class Foo
          def bar
            yield 42
          end
        end
        Foo.new.bar do |x|
          x
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :lvar, { var_name: "x" })).to eq(nominal("Integer"))
      end

      specify "method with more than one yield" do
        snippet = <<-END
        class Foo
          def bar
            yield 42
            yield "foo"
          end
        end
        Foo.new.bar do |x|
          x
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :lvar, { var_name: "x" })).to eq(union([nominal("Integer"), nominal("String")]))
      end
    end

    def type_snippet(snippet)
      result = DataFlowGraph.new.process_file(snippet)
      typing_result = TypingService.new.(result.graph, result.message_sends, result.tree)
      typing_result[result.final_node]
    end

    def full_type_snippet(snippet)
      result = DataFlowGraph.new.process_file(snippet)
      TypingService.new.(result.graph, result.message_sends, result.tree)
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

    def find_by_node(result, node_type, node_params = {})
      result.find {|k,v| k.type == node_type && k.params == node_params }.last
    end
  end
end
