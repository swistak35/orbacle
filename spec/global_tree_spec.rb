require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe GlobalTree do
    describe "#solve_reference" do
      specify "no result" do
        tree = GlobalTree.new

        const_ref = ConstRef.from_full_name("Foo")
        nesting = Nesting.new

        expect(tree.solve_reference(const_ref, nesting)).to eq(nil)
      end

      specify "simple reference" do
        tree = GlobalTree.new
        klass = tree.add_klass(
          GlobalTree::Klass.new(
            name: "Foo",
            scope: Scope.empty,
            line: 42,
            inheritance_name: nil,
            inheritance_nesting: Nesting.new))

        const_ref = ConstRef.from_full_name("Foo")
        nesting = Nesting.new

        expect(tree.solve_reference(const_ref, nesting)).to eq(klass)
      end

      specify "simple reference of a nested class" do
        tree = GlobalTree.new
        klass = tree.add_klass(
          GlobalTree::Klass.new(
            name: "Bar",
            scope: Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo")),
            line: 42,
            inheritance_name: nil,
            inheritance_nesting: Nesting.new))

        const_ref = ConstRef.from_full_name("Foo::Bar")
        nesting = Nesting.new

        expect(tree.solve_reference(const_ref, nesting)).to eq(klass)
      end

      specify "reference of a nested class from inside class" do
        tree = GlobalTree.new
        klass = tree.add_klass(
          GlobalTree::Klass.new(
            name: "Bar",
            scope: Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo")),
            line: 42,
            inheritance_name: nil,
            inheritance_nesting: Nesting.new))

        const_ref = ConstRef.from_full_name("Bar")
        nesting = Nesting.new
          .increase_nesting_const(ConstRef.from_full_name("Foo"))

        expect(tree.solve_reference(const_ref, nesting)).to eq(klass)
      end
    end
  end
end
