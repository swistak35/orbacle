require 'spec_helper'
require 'logger'

module Orbacle
  RSpec.describe DefineBuiltins do
    describe "Object" do
      specify "==" do
        snippet = <<-END
        Object.new == Object.new
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "!" do
        snippet = <<-END
        !Object.new
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "!=" do
        snippet = <<-END
        Object.new != Object.new
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "object_id" do
        snippet = <<-END
        Object.new.object_id
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "__id__" do
        snippet = <<-END
        Object.new.__id__
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "equal?" do
        snippet = <<-END
        Object.new.equal?(Object.new)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "!~" do
        snippet = <<-END
        Object.new !~ Object.new
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "===" do
        snippet = <<-END
        Object.new === Object.new
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "<=>" do
        snippet = <<-END
        Object.new <=> Object.new
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Nil"), nominal("Integer")]))
      end

      specify "display" do
        snippet = <<-END
        Object.new.display
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Nil"))
      end

      specify "eql?" do
        snippet = <<-END
        Object.new.eql?(Object.new)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "frozen?" do
        snippet = <<-END
        Object.new.frozen?
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "instance_of?" do
        snippet = <<-END
        Object.new.instance_of?(Object)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "instance_variable_defined?" do
        snippet = <<-END
        Object.new.instance_variable_defined?(:@ivar)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "is_a?" do
        snippet = <<-END
        Object.new.is_a?(Object)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "inspect" do
        snippet = <<-END
        Object.new.inspect
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "kind_of?" do
        snippet = <<-END
        Object.new.kind_of?(Object)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "nil?" do
        snippet = <<-END
        Object.new.nil?
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "respond_to?" do
        snippet = <<-END
        Object.new.respond_to?(Object)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "respond_to_missing?" do
        snippet = <<-END
        Object.new.respond_to_missing?(Object)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "#tainted?" do
        snippet = <<-END
        Object.new.tainted?
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "#to_s" do
        snippet = <<-END
        Object.new.to_s
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "#untrusted?" do
        snippet = <<-END
        Object.new.untrusted?
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end
    end

    describe "Integer" do
      specify "#succ" do
        snippet = <<-END
        x = 42
        x.succ
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "#+" do
        snippet = <<-END
        42 + 78
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "#-" do
        snippet = <<-END
        42 - 78
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "#*" do
        snippet = <<-END
        42 * 78
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end
    end

    describe "Dir" do
      specify "::glob" do
        snippet = <<-END
        Dir.glob(/foo/)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("String")]))
      end
    end

    describe "File" do
      specify "::read" do
        snippet = <<-END
        File.read("foo.rb")
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end
    end

    def type_snippet(snippet)
      worklist = Worklist.new
      graph = Graph.new
      tree = GlobalTree.new
      DefineBuiltins.new(graph, tree).()
      result = Builder.new(graph, worklist, tree).process_file(Parser::CurrentRuby.parse(snippet), nil)
      typing_result = TypingService.new(Logger.new(nil)).(graph, worklist, tree)
      typing_result[result.node]
    end

    def nominal(*args)
      NominalType.new(*args)
    end

    def union(*args)
      UnionType.new(*args)
    end

    def generic(*args)
      GenericType.new(*args)
    end

    def klass(*args)
      ClassType.new(*args)
    end

    def main
      MainType.new
    end

    def bottom
      BottomType.new
    end
  end
end
