require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  class GlobalTree
    RSpec.describe ConstantsTree do
      describe "#solve_reference" do
        specify "no result" do
          tree = ConstantsTree.new

          const_ref = ConstRef.from_full_name("Foo", Nesting.empty)

          expect(tree.solve_reference(const_ref)).to eq(nil)
        end

        specify "simple reference" do
          tree = ConstantsTree.new
          klass = tree.add_constant(
            GlobalTree::Constant.new("Bar", Scope.empty, nil))
          klass = tree.add_constant(
            GlobalTree::Constant.new("Foo", Scope.empty, nil))

          const_ref = ConstRef.from_full_name("Foo", Nesting.empty)

          expect(tree.solve_reference(const_ref)).to eq(klass)
        end

        specify "simple reference of a nested class" do
          tree = ConstantsTree.new
          klass = tree.add_constant(
            GlobalTree::Constant.new(
              "Bar",
              Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo", Nesting.empty)),
              nil))

          const_ref = ConstRef.from_full_name("Foo::Bar", Nesting.empty)

          expect(tree.solve_reference(const_ref)).to eq(klass)
        end

        specify "reference of a nested class from inside class" do
          tree = ConstantsTree.new
          tree.add_constant(
            GlobalTree::Constant.new(
              "Baz",
              Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo", Nesting.empty)),
              nil))
          klass = tree.add_constant(
            GlobalTree::Constant.new(
              "Bar",
              Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo", Nesting.empty)),
              nil))

          nesting = Nesting.empty
            .increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
          const_ref = ConstRef.from_full_name("Bar", nesting)

          expect(tree.solve_reference(const_ref)).to eq(klass)
        end

        specify "reference of a not nested class from inside class" do
          tree = GlobalTree.new
          klass = tree.add_constant(
            GlobalTree::Constant.new("Bar", Scope.empty, nil))

          nesting = Nesting.empty
            .increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
          const_ref = ConstRef.from_full_name("Bar", nesting)

          expect(tree.solve_reference(const_ref)).to eq(klass)
        end
      end
    end
  end
end
