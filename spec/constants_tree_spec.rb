require 'spec_helper'

module Orbacle
  RSpec.describe ConstantsTree do
    let(:const1) { Object.new }
    let(:const2) { Object.new }

    describe "#select_by_const_ref" do
      specify "no result" do
        tree = ConstantsTree.new

        const_ref = ConstRef.from_full_name("Foo", Nesting.empty)

        expect(tree.select_by_const_ref(const_ref)).to eq([])
      end

      specify "simple reference" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(Scope.empty, "Foo", const2)

        const_ref = ConstRef.from_full_name("Foo", Nesting.empty)

        expect(tree.select_by_const_ref(const_ref)).to eq([const2])
      end

      specify "simple reference of a nested class" do
        tree = ConstantsTree.new
        tree.add_element(
            Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo", Nesting.empty)),
            "Bar",
            const1)

        const_ref = ConstRef.from_full_name("Foo::Bar", Nesting.empty)
        expect(tree.select_by_const_ref(const_ref)).to eq([const1])
      end

      specify "reference of a nested class from inside class" do
        tree = ConstantsTree.new
        tree.add_element(
          Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo", Nesting.empty)),
          "Baz",
          const1)
        tree.add_element(
          Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo", Nesting.empty)),
          "Bar",
          const2)

        nesting = Nesting.empty
          .increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
        const_ref = ConstRef.from_full_name("Bar", nesting)

        expect(tree.select_by_const_ref(const_ref)).to eq([const2])
      end

      specify "reference of a not nested class from inside class" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)

        nesting = Nesting.empty
          .increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
        const_ref = ConstRef.from_full_name("Bar", nesting)

        expect(tree.select_by_const_ref(const_ref)).to eq([const1])
      end

      specify "reference returns all elements" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(Scope.empty, "Bar", const2)

        const_ref = ConstRef.from_full_name("Bar", Nesting.empty)
        expect(tree.select_by_const_ref(const_ref)).to eq([const1, const2])
      end
    end

    describe "#select_by_const_ref" do
      specify "no result" do
        tree = ConstantsTree.new

        const_ref = ConstRef.from_full_name("Foo", Nesting.empty)

        expect(tree.find_by_const_ref(const_ref)).to eq(nil)
      end

      specify "simple reference" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(Scope.empty, "Foo", const2)

        const_ref = ConstRef.from_full_name("Foo", Nesting.empty)

        expect(tree.find_by_const_ref(const_ref)).to eq(const2)
      end

      specify "reference returns all elements" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(Scope.empty, "Bar", const2)

        const_ref = ConstRef.from_full_name("Bar", Nesting.empty)
        expect(tree.find_by_const_ref(const_ref)).to eq(const1)
      end
    end

    describe "#find" do
      specify "element in root level" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(Scope.empty, "Foo", const2)

        expect(tree.find {|c| c == const2 }).to eq(const2)
      end

      specify "element in nested level" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(
          Scope.empty.increase_by_ref(ConstRef.from_full_name("Bar", Nesting.empty)),
          "Baz",
          const2)

        expect(tree.find {|c| c == const2 }).to eq(const2)
      end
    end

    describe "#find_by_const_name" do
      specify do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(Scope.empty, "Foo", const2)

        expect(tree.find_by_const_name(ConstName.from_string("Foo"))).to eq(const2)
      end

      specify "returns first constant added" do
        tree = ConstantsTree.new
        tree.add_element(Scope.empty, "Bar", const1)
        tree.add_element(Scope.empty, "Bar", const2)

        expect(tree.find_by_const_name(ConstName.from_string("Bar"))).to eq(const1)
      end

      specify "nil for unknown" do
        tree = ConstantsTree.new

        expect(tree.find_by_const_name(ConstName.from_string("Foo"))).to eq(nil)
      end
    end
  end
end
