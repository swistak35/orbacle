# frozen_string_literal: true

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

      specify "#clone" do
        snippet = <<-END
        [1,2,3].clone(freeze: false)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
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

      specify "#dup" do
        snippet = <<-END
        [1,2,3].dup
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#freeze" do
        snippet = <<-END
        [1,2,3].freeze
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#itself" do
        snippet = <<-END
        [1,2,3].itself
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#taint" do
        snippet = <<-END
        [1,2,3].taint
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#trust" do
        snippet = <<-END
        [1,2,3].trust
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#untaint" do
        snippet = <<-END
        [1,2,3].untaint
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#untrust" do
        snippet = <<-END
        [1,2,3].untrust
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
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

    describe "Array" do
      specify "#map without a block" do
        snippet = <<-END
        x = [1,2]
        x.map
        END

        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "#map with simple block" do
        snippet = <<-END
        x = [1,2]
        x.map {|y| y }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#map - passing block by blockarg" do
        snippet = <<-END
        x = [1,2]
        y = ->(y) { y.to_s }
        x.map(&y)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("String")]))
      end

      specify "#map - block without arg" do
        snippet = <<-END
        x = [1,2]
        x.map { 42.0 }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Float")]))
      end

      specify "#map - works when some argument passed" do
        snippet = <<-END
        x = [1,2]
        x.map(42) {|x| x }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#each without a block" do
        snippet = <<-END
        x = [1,2]
        x.each
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#each with simple block" do
        snippet = <<-END
        x = [1,2]
        x.each {|y| $x = y }
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "#each - block without arg" do
        snippet = <<-END
        x = [1,2]
        x.each { 42.0 }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "#each - works when some argument passed" do
        snippet = <<-END
        x = [1,2]
        x.each(42) {|x| x }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end
    end

    def type_snippet(snippet)
      worklist = Worklist.new
      graph = Graph.new
      id_generator = UuidIdGenerator.new
      state = GlobalTree.new(id_generator)
      DefineBuiltins.new(graph, state, id_generator).()
      result = Builder.new(graph, worklist, state, id_generator).process_file(RubyParser.new.parse(snippet), nil)
      stats_recorder = Indexer::StatsRecorder.new
      TypingService.new(Logger.new(nil), stats_recorder).(graph, worklist, state)
      state.type_of(result.node)
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
