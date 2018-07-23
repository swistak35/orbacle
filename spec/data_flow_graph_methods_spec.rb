# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

module Orbacle
  RSpec.describe "Builder" do
    describe "visibility" do
      specify "public by default" do
        file = <<-END
        class Foo
          def bar
          end
        end
        END

        result = compute_graph(file)

        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:public)
      end

      specify "private method in class declaration" do
        file = <<-END
        class Foo
          private
          def bar
          end
        end
        END

        result = compute_graph(file)
        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:private)
      end

      specify "rechanging visibility of methods in class declaration" do
        file = <<-END
        class Foo
          private
          public
          def bar
          end
        end
        END

        result = compute_graph(file)
        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:public)
      end

      specify "changing visibility to protected" do
        file = <<-END
        class Foo
          protected
          def bar
          end
        end
        END

        result = compute_graph(file)
        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:protected)
      end

      specify "private keyword does not work if not used inside object declaration" do
        file = <<-END
        private
        def bar
        end
        END

        result = compute_graph(file)
        meth = find_kernel_method(result, "bar")
        expect(meth.visibility).to eq(:public)
      end

      specify "using private with passing a symbol" do
        file = <<-END
        class Foo
          def bar
          end
          private :bar
        end
        END

        result = compute_graph(file)
        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:private)
      end

      specify "using private with passing a symbol does not change visibility of future methods" do
        file = <<-END
        class Foo
          def bar
          end
          private :bar
          def baz
          end
        end
        END

        result = compute_graph(file)
        meth = find_method(result, "Foo", "baz")
        expect(meth.visibility).to eq(:public)
      end
    end

    describe "collecting yields" do
      specify "method with one yield" do
        file = <<-END
        def bar
          yield
        end
        END

        result = compute_graph(file)

        last_method = find_kernel_method(result, "bar")
        expect(result.graph.get_metod_nodes(last_method.id).yields.size).to eq(1)
      end

      specify "method with more yields" do
        file = <<-END
        def bar
          yield
          yield
          yield
        end
        END

        result = compute_graph(file)

        last_method = find_kernel_method(result, "bar")
        expect(result.graph.get_metod_nodes(last_method.id).yields.size).to eq(3)
      end
    end

    specify "simple class declaration" do
      file = <<-END
      class Foo
      end
      END

      result = compute_graph(file)

      foo_class = find_class(result, "Foo")
      expect(foo_class).not_to be_nil
      expect(foo_class.parent_ref).to eq(nil)

      foo_const = find_constant(result, "Foo")
      expect(foo_const.location.start_line).to eq(0)
    end

    specify "simple method in class declaration" do
      file = <<-END
      class Foo
        def bar
        end
      end
      END

      result = compute_graph(file)

      foo_class = find_class(result, "Foo")

      meth = find_method2(result, foo_class.id, "bar")
      expect(meth.visibility).to eq(:public)
      expect(meth.location.start_line).to eq(1)
    end

    specify do
      file = <<-END
      class Foo
        def bar
        end

        def baz
        end
      end
      END

      result = compute_graph(file)

      foo_class = find_class(result, "Foo")
      expect(find_method2(result, foo_class.id, "bar")).not_to be_nil
      expect(find_method2(result, foo_class.id, "baz")).not_to be_nil
    end

    specify do
      file = <<-END
      module Foo
      end
      END

      result = compute_graph(file)

      foo_module = find_module(result, "Foo")
      expect(foo_module).not_to be_nil
    end

    specify do
      file = <<-END
      module Some
        class Foo
        end
      end
      END

      result = compute_graph(file)

      expect(find_class(result, "Some::Foo")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some
        class Foo
          def bar
          end

          def baz
          end
        end
      end
      END

      result = compute_graph(file)

      foo_class = find_class(result, "Some::Foo")
      expect(find_method2(result, foo_class.id, "bar")).not_to be_nil
      expect(find_method2(result, foo_class.id, "baz")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some
        class Foo
        end

        class Bar
        end
      end
      END

      result = compute_graph(file)

      expect(find_class(result, "Some::Foo")).not_to be_nil
      expect(find_class(result, "Some::Bar")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some
        class Foo
          def oof
          end
        end

        class Bar
          def rab
          end
        end
      end
      END

      result = compute_graph(file)

      foo = find_class(result, "Some::Foo")
      bar = find_class(result, "Some::Bar")

      expect(find_method2(result, foo.id, "oof")).not_to be_nil
      expect(find_method2(result, bar.id, "rab")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some
        module Foo
          class Bar
          end
        end
      end
      END

      result = compute_graph(file)

      expect(find_class(result, "Some::Foo::Bar")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some::Foo
        class Bar
        end
      end
      END

      result = compute_graph(file)

      expect(find_class(result, "Some::Foo::Bar")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some::Foo::Bar
        class Baz
          def xxx
          end
        end
      end
      END

      result = compute_graph(file)

      expect(find_class(result, "Some::Foo::Bar::Baz")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some::Foo
        class Bar::Baz
        end
      end
      END

      result = compute_graph(file)

      expect(find_class(result, "Some::Foo::Bar::Baz")).not_to be_nil
    end

    specify do
      file = <<-END
      class Bar
        class ::Foo
          def xxx
          end
        end
      end
      END

      result = compute_graph(file)

      expect(find_class(result, "Foo")).not_to be_nil
      expect(find_class(result, "Bar::Foo")).to be_nil
    end

    specify do
      file = <<-END
      class Bar
        class ::Foo
          def xxx
          end
        end
      end
      END

      result = compute_graph(file)

      foo = find_class(result, "Foo")
      expect(find_method2(result, foo.id, "xxx")).not_to be_nil
    end

    specify do
      file = <<-END
      class Bar
        module ::Foo
          def xxx
          end
        end
      end
      END

      result = compute_graph(file)

      expect(find_module(result, "Foo")).not_to be_nil
      expect(find_module(result, "Bar::Foo")).to be_nil
    end

    specify do
      file = <<-END
      class Bar
        module ::Foo
          def xxx
          end
        end
      end
      END

      result = compute_graph(file)

      foo = find_module(result, "Foo")
      expect(find_method2(result, foo.id, "xxx")).not_to be_nil
    end

    specify do
      file = <<-END
      def xxx
      end
      END

      result = compute_graph(file)

      xxx = find_kernel_method(result, "xxx")
      expect(xxx).not_to be_nil
      expect(xxx.place_of_definition_id).to be_nil
    end

    specify do
      file = <<-END
      class Foo
        Bar = 32
      end
      END

      result = compute_graph(file)

      bar_const = find_constant(result, "Foo::Bar")
      expect(bar_const).not_to be_nil
    end

    specify do
      file = <<-END
      class Foo
        Ban::Baz::Bar = 32
      end
      END

      result = compute_graph(file)

      bar_const = find_constant(result, "Foo::Ban::Baz::Bar")
      expect(bar_const).not_to be_nil
    end

    specify do
      file = <<-END
      class Foo
        ::Bar = 32
      end
      END

      result = compute_graph(file)

      expect(find_constant(result, "Foo::Bar")).to be_nil
      expect(find_constant(result, "Bar")).not_to be_nil
    end

    specify do
      file = <<-END
      class Foo
        ::Baz::Bar = 32
      end
      END

      result = compute_graph(file)

      expect(find_constant(result, "Baz::Bar")).not_to be_nil
    end

    specify do
      file = <<-END
      class Foo
        ::Baz::Bam::Bar = 32
      end
      END

      result = compute_graph(file)

      expect(find_constant(result, "Baz::Bam::Bar")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some
        module Foo
        end

        module Bar
        end
      end
      END

      result = compute_graph(file)

      expect(find_module(result, "Some::Foo")).not_to be_nil
      expect(find_module(result, "Some::Bar")).not_to be_nil
    end

    specify do
      file = <<-END
      module Some
        module Foo
          def oof
          end
        end

        module Bar
          def rab
          end
        end
      end
      END

      result = compute_graph(file)

      foo = find_module(result, "Some::Foo")
      bar = find_module(result, "Some::Bar")

      expect(find_method2(result, foo.id, "oof")).not_to be_nil
      expect(find_method2(result, bar.id, "rab")).not_to be_nil
    end

    specify "method in method definition" do
      file = <<-END
      class Foo
        def bar
          def baz
          end
        end
      end
      END

      result = compute_graph(file)

      foo = find_class(result, "Foo")

      expect(find_method2(result, foo.id, "bar")).not_to be_nil
      expect(find_method2(result, foo.id, "baz")).not_to be_nil
    end

    describe "inheritance of classes" do
      specify do
        file = <<-END
        class Foo < Bar
        end
        END

        result = compute_graph(file)

        foo = find_class(result, "Foo")
        expect(foo.parent_ref).to eq(ConstRef.from_full_name("Bar", Nesting.empty))
      end

      specify do
        file = <<-END
        class Foo < Bar::Baz
        end
        END

        result = compute_graph(file)

        foo = find_class(result, "Foo")
        expect(foo.parent_ref).to eq(ConstRef.from_full_name("Bar::Baz", Nesting.empty))
      end

      specify do
        file = <<-END
        class Foo < ::Bar::Baz
        end
        END

        result = compute_graph(file)

        foo = find_class(result, "Foo")
        expect(foo.parent_ref).to eq(ConstRef.from_full_name("::Bar::Baz", Nesting.empty))
      end

      specify do
        file = <<-END
        module Some
          class Foo < Bar
          end
        end
        END

        result = compute_graph(file)

        foo = find_class(result, "Some::Foo")
        expect(foo.parent_ref).to eq(
          ConstRef.from_full_name(
            "Bar",
            Nesting.empty.increase_nesting_const(
              ConstRef.from_full_name("Some", Nesting.empty))))
      end

      specify do
        file = <<-END
        Foo = Class.new(Bar)
        END

        result = compute_graph(file)

        foo = find_class(result, "Foo")
        expect(foo.parent_ref).to eq(ConstRef.from_full_name("Bar", Nesting.empty))
      end
    end

    specify do
      file = <<-END
      Foo = Class.new
      END

      result = compute_graph(file)

      expect(find_class(result, "Foo")).not_to be_nil
    end

    specify do
      file = <<-END
      Foo = Module.new
      END

      result = compute_graph(file)

      expect(find_module(result, "Foo")).not_to be_nil
    end

    specify "self method without embracing definition" do
      file = <<-END
      def self.bar
      end
      END

      result = compute_graph(file)

      expect(find_method2(result, nil, "bar")).not_to be_nil
    end

    specify "def self.func in class definition" do
      file = <<-END
      class Foo
        def self.bar
        end
      end
      END

      result = compute_graph(file)

      foo_class = find_class(result, "Foo")
      foo_eigenclass = find_eigenclass(result, foo_class)
      expect(find_method2(result, foo_class.id, "bar")).to be_nil
      expect(find_method2(result, foo_eigenclass.id, "bar")).not_to be_nil
    end

    specify "def self.func outside class definition" do
      file = <<-END
      def self.bar
      end
      END

      result = compute_graph(file)

      expect(find_kernel_method(result, "bar")).not_to be_nil
    end

    specify "using sclass in class definition - MISBEHAVIOUR" do
      file = <<-END
      class Foo
        class << self
          def bar
          end
        end
      end
      END

      result = compute_graph(file)

      foo_class = find_class(result, "Foo")
      foo_eigenclass = find_eigenclass(result, foo_class)
      expect(find_method2(result, foo_class.id, "bar")).to be_nil
      expect(find_method2(result, foo_eigenclass.id, "bar")).not_to be_nil
    end

    specify "using sclass outside class definition" do
      file = <<-END
      class << self
        def bar
        end
      end
      END

      result = compute_graph(file)

      expect(find_kernel_method(result, "bar")).not_to be_nil
    end

    specify "using sclass in class definition but not self - MISBEHAVIOUR" do
      file = <<-END
      class Foo
      end
      class << Foo
        def bar
        end
      end
      END

      result = compute_graph(file)

      expect(find_kernel_method(result, "bar")).not_to be_nil
      # foo_class = find_class(result, "Foo")
      # foo_eigenclass = find_eigenclass(result, foo_class)
      # expect(find_method2(result, foo_class.id, "bar")).to be_nil
      # expect(find_method2(result, foo_eigenclass.id, "bar")).not_to be_nil
    end

    specify "using sclass in module definition but not self - MISBEHAVIOUR" do
      file = <<-END
      module Foo
      end
      class << Foo
        def bar
        end
      end
      END

      result = compute_graph(file)

      expect(find_kernel_method(result, "bar")).not_to be_nil
      # foo_class = find_class(result, "Foo")
      # foo_eigenclass = find_eigenclass(result, foo_class)
      # expect(find_method2(result, foo_class.id, "bar")).to be_nil
      # expect(find_method2(result, foo_eigenclass.id, "bar")).not_to be_nil
    end

    specify "using sclass in some definition but not self - MISBEHAVIOUR" do
      file = <<-END
      class << Foo
        def bar
        end
      end
      END

      result = compute_graph(file)

      expect(find_kernel_method(result, "bar")).not_to be_nil
      # foo_class = find_class(result, "Foo")
      # foo_eigenclass = find_eigenclass(result, foo_class)
      # expect(find_method2(result, foo_class.id, "bar")).to be_nil
      # expect(find_method2(result, foo_eigenclass.id, "bar")).not_to be_nil
    end

    specify "def self.func in module definition" do
      file = <<-END
      module Foo
        def self.bar
        end
      end
      END

      result = compute_graph(file)

      foo_module = find_module(result, "Foo")
      foo_eigenclass = find_eigenclass(result, foo_module)
      expect(find_method2(result, foo_module.id, "bar")).to be_nil
      expect(find_method2(result, foo_eigenclass.id, "bar")).not_to be_nil
    end

    specify "using sclass in module definition" do
      file = <<-END
      module Foo
        class << self
          def bar
          end
        end
      end
      END

      result = compute_graph(file)

      foo_module = find_module(result, "Foo")
      foo_eigenclass = find_eigenclass(result, foo_module)
      expect(find_method2(result, foo_module.id, "bar")).to be_nil
      expect(find_method2(result, foo_eigenclass.id, "bar")).not_to be_nil
    end

    describe "attr_reader/accessor/writer" do
      specify "simple attr_reader example" do
        file = <<-END
        class Foo
          attr_reader :bar, :baz
        end
        END

        result = compute_graph(file)

        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:public)
        expect(meth.args.args).to eq([])
        expect(meth.args.kwargs).to eq([])
        expect(meth.args.blockarg).to be_nil

        meth = find_method(result, "Foo", "baz")
        expect(meth.visibility).to eq(:public)
        expect(meth.args.args).to eq([])
        expect(meth.args.kwargs).to eq([])
        expect(meth.args.blockarg).to be_nil
      end

      specify "simple attr_writer example" do
        file = <<-END
        class Foo
          attr_writer :bar, :baz
        end
        END

        result = compute_graph(file)

        meth = find_method(result, "Foo", "bar=")
        expect(meth.visibility).to eq(:public)
        expect(meth.args.args.size).to eq(1)
        expect(meth.args.kwargs).to eq([])
        expect(meth.args.blockarg).to be_nil
      end

      specify "simple attr_accessor example" do
        file = <<-END
        class Foo
          attr_accessor :bar, :baz
        end
        END

        result = compute_graph(file)

        expect(find_method(result, "Foo", "bar")).not_to be_nil
        expect(find_method(result, "Foo", "bar=")).not_to be_nil
        expect(find_method(result, "Foo", "baz")).not_to be_nil
        expect(find_method(result, "Foo", "baz=")).not_to be_nil
      end
    end

    # Currently does not work
    context "misbehaviours" do
      specify "using private with passing a method definition" do
        file = <<-END
        class Foo
          private def bar
          end
        end
        END

        result = compute_graph(file)
        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:public)
        # expect(meth.visibility).to eq(:private)
      end

      specify "using private with passing something else than literals" do
        file = <<-END
        class Foo
          def bar
          end

          x = "bar"
          private x
        end
        END

        result = compute_graph(file)
        meth = find_method(result, "Foo", "bar")
        expect(meth.visibility).to eq(:public)
        # expect(meth.visibility).to eq(:private)
      end

      it "method in method definition with changed visibility" do
        file = <<-END
        class Foo
          private
          def bar
            def baz
            end
          end
        end
        END

        result = compute_graph(file)

        meth = find_method(result, "Foo", "baz")
        expect(meth.visibility).to eq(:private)
        # expect(meth.visibility).to eq(:public)
      end
    end

    def compute_graph(file)
      worklist = Worklist.new
      graph = Graph.new
      id_generator = UuidIdGenerator.new
      tree = GlobalTree.new(id_generator)
      service = Builder.new(graph, worklist, tree, id_generator)
      result = service.process_file(Parser::CurrentRuby.parse(file), nil)
      OpenStruct.new(
        graph: graph,
        tree: tree)
    end

    def find_method(result, scope, name)
      result.tree.find_instance_method(scope, name)
    end

    def find_method2(result, klass_id, name)
      result.tree.find_instance_method2(klass_id, name)
    end

    def find_kernel_method(result, name)
      find_method2(result, nil, name)
    end

    def find_constant(result, name)
      result.tree.find_constant_by_name(name)
    end

    def find_class(result, name)
      result.tree.find_class_by_name(name)
    end

    def find_module(result, name)
      result.tree.find_module_by_name(name)
    end

    def find_eigenclass(result, definition)
      result.tree.get_eigenclass_of_definition(definition.id)
    end
  end
end
