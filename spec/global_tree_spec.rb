require 'spec_helper'

module Orbacle
  RSpec.describe GlobalTree do
    let(:id_generator) { IntegerIdGenerator.new }

    describe "#add_lambda" do
      specify "returns result" do
        state = GlobalTree.new(id_generator)

        args = GlobalTree::ArgumentsTree.new([], [], nil)
        result = state.add_lambda(args)

        expect(result.id).to eq(1)
        expect(result.args).to eq(args)
      end

      specify "stores result" do
        state = GlobalTree.new(id_generator)

        args = GlobalTree::ArgumentsTree.new([], [], nil)
        result = state.add_lambda(args)

        expect(state.get_lambda(result.id)).to eq(result)
      end
    end

    describe "#get_lambda" do
      specify "stores result" do
        state = GlobalTree.new(id_generator)

        args = GlobalTree::ArgumentsTree.new([], [], nil)
        result = state.add_lambda(args)

        expect(state.get_lambda(result.id)).to eq(result)
      end

      specify "returns nil if no lambda" do
        state = GlobalTree.new(id_generator)

        expect(state.get_lambda(42)).to eq(nil)
      end
    end

    describe "#get_instance_methods_from_class_id" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.get_instance_methods_from_class_id(78, "some_method")

        expect(result).to eq([])
      end

      specify do
        state = GlobalTree.new(id_generator)
        metod = state.add_method(42, 78, "some_method", nil, :public, nil)

        result = state.get_instance_methods_from_class_id(78, "some_method")

        expect(result).to match_array([metod])
      end
    end

    describe "#find_instance_method_from_class_id" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.find_instance_method_from_class_id(78, "some_method")

        expect(result).to eq(nil)
      end

      specify do
        state = GlobalTree.new(id_generator)
        metod = state.add_method(42, 78, "some_method", nil, :public, nil)

        result = state.find_instance_method_from_class_id(78, "some_method")

        expect(result).to eq(metod)
      end

      specify do
        state = GlobalTree.new(id_generator)
        metod1 = state.add_method(42, 78, "some_method", nil, :public, nil)
        _metod2 = state.add_method(43, 78, "some_method", nil, :public, nil)

        result = state.find_instance_method_from_class_id(78, "some_method")

        expect(result).to eq(metod1)
      end
    end

    describe "#get_instance_methods_from_class_name" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.get_instance_methods_from_class_name("SomeClass", "some_method")

        expect(result).to eq([])
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        _constant = state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))
        metod = state.add_method(42, klass.id, "some_method", nil, :public, nil)

        result = state.get_instance_methods_from_class_name("SomeClass", "some_method")

        expect(result).to match_array([metod])
      end
    end

    describe "#find_instance_method_from_class_name" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.find_instance_method_from_class_name("SomeClass", "some_method")

        expect(result).to eq(nil)
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        _constant = state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))
        metod = state.add_method(42, klass.id, "some_method", nil, :public, nil)

        result = state.find_instance_method_from_class_name("SomeClass", "some_method")

        expect(result).to eq(metod)
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        _constant = state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))
        metod1 = state.add_method(42, klass.id, "some_method", nil, :public, nil)
        _metod2 = state.add_method(43, klass.id, "some_method", nil, :public, nil)

        result = state.find_instance_method_from_class_name("SomeClass", "some_method")

        expect(result).to eq(metod1)
      end
    end

    describe "#get_class_methods_from_class_name" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.get_class_methods_from_class_name("SomeClass", "some_method")

        expect(result).to eq([])
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        _constant = state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))
        eigenclass = state.get_eigenclass_of_definition(klass.id)
        metod = state.add_method(42, eigenclass.id, "some_method", nil, :public, nil)

        result = state.get_class_methods_from_class_name("SomeClass", "some_method")

        expect(result).to match_array([metod])
      end
    end

    describe "#find_class_method_from_class_name" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.find_class_method_from_class_name("SomeClass", "some_method")

        expect(result).to eq(nil)
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        _constant = state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))
        eigenclass = state.get_eigenclass_of_definition(klass.id)
        metod1 = state.add_method(42, eigenclass.id, "some_method", nil, :public, nil)
        _metod2 = state.add_method(43, eigenclass.id, "some_method", nil, :public, nil)

        result = state.find_class_method_from_class_name("SomeClass", "some_method")

        expect(result).to eq(metod1)
      end
    end

    describe "#get_methods" do
      specify do
        state = GlobalTree.new(id_generator)

        method1 = state.add_method(42, 78, "foo", nil, :public, nil)
        method2 = state.add_method(43, 78, "bar", nil, :public, nil)
        result = state.get_methods("foo")

        expect(result).to match_array([method1])
      end
    end

    describe "#find_super_method" do
      specify do
        state = GlobalTree.new(id_generator)
        parent_class = state.add_class(nil)
        parent_constant = state.add_constant(GlobalTree::Constant.new("ParentClass", Scope.empty, nil, parent_class.id))
        some_class = state.add_class(ConstRef.from_full_name("ParentClass", Nesting.empty))
        parent_method = state.add_method(42, parent_class.id, "some_method", nil, :public, nil)
        some_method = state.add_method(43, some_class.id, "some_method", nil, :public, nil)

        result = state.find_super_method(43)

        expect(result).to eq(parent_method)
      end

      specify do
        state = GlobalTree.new(id_generator)
        state.add_method(43, 78, "some_method", nil, :public, nil)

        result = state.find_super_method(43)

        expect(result).to eq(nil)
      end

      specify do
        state = GlobalTree.new(id_generator)
        some_class = state.add_class(nil)
        some_method = state.add_method(43, some_class.id, "some_method", nil, :public, nil)

        result = state.find_super_method(43)

        expect(result).to eq(nil)
      end

      specify do
        state = GlobalTree.new(id_generator)
        some_class = state.add_class(ConstRef.from_full_name("ParentClass", Nesting.empty))
        some_method = state.add_method(43, some_class.id, "some_method", nil, :public, nil)

        result = state.find_super_method(43)

        expect(result).to eq(nil)
      end
    end

    describe "#change_method_visibility" do
      specify do
        state = GlobalTree.new(id_generator)
        method1 = state.add_method(42, "77", "some_method", nil, :public, nil)
        method2 = state.add_method(43, "78", "some_method", nil, :public, nil)
        method3 = state.add_method(44, "78", "other_method", nil, :public, nil)

        state.change_method_visibility("78", "some_method", :private)

        expect(method1.visibility).to eq(:public)
        expect(method2.visibility).to eq(:private)
        expect(method3.visibility).to eq(:public)
      end

      specify do
        state = GlobalTree.new(id_generator)

        expect do
          state.change_method_visibility("78", "some_method", :private)
        end.not_to raise_error
      end
    end

    describe "#add_class" do
      specify do
        state = GlobalTree.new(id_generator)

        parent_ref = ConstRef.from_full_name("Foo", Nesting.empty)
        result = state.add_class(parent_ref)

        expect(result.id).to eq(1)
        expect(result.parent_ref).to eq(parent_ref)
      end

      specify do
        state = GlobalTree.new(id_generator)

        result = state.add_class(nil)

        expect(state.get_class(result.id)).to eq(result)
      end
    end

    describe "#get_class" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.add_class(nil)

        expect(state.get_class(result.id)).to eq(result)
      end

      specify "returns nil if no lambda" do
        state = GlobalTree.new(id_generator)

        expect(state.get_class(42)).to eq(nil)
      end
    end

    describe "#add_module" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.add_module

        expect(result.id).to eq(1)
      end

      specify do
        state = GlobalTree.new(id_generator)

        result = state.add_module

        expect(state.get_module(result.id)).to eq(result)
      end
    end

    describe "#get_module" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.add_module

        expect(state.get_module(result.id)).to eq(result)
      end

      specify "returns nil if no module" do
        state = GlobalTree.new(id_generator)

        expect(state.get_module(42)).to eq(nil)
      end
    end

    describe "#get_definition" do
      specify do
        state = GlobalTree.new(id_generator)

        result = state.add_module

        expect(state.get_definition(result.id)).to eq(result)
      end

      specify do
        state = GlobalTree.new(id_generator)

        result = state.add_class(nil)

        expect(state.get_definition(result.id)).to eq(result)
      end

      specify do
        state = GlobalTree.new(id_generator)

        expect(state.get_definition(42)).to eq(nil)
      end
    end

    describe "#get_eigenclass_of_definition" do
      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        eigenclass = state.get_eigenclass_of_definition(klass.id)

        expect(klass.id).to eq(1)
        expect(eigenclass.id).to eq(2)
        expect(klass.eigenclass_id).to eq(eigenclass.id)
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        eigenclass1 = state.get_eigenclass_of_definition(klass.id)
        eigenclass2 = state.get_eigenclass_of_definition(klass.id)

        expect(eigenclass1).to eq(eigenclass2)
      end
    end

    describe "#get_parent_of" do
      specify "there's class and constant" do
        state = GlobalTree.new(id_generator)
        some_module_ref = ConstRef.from_full_name("SomeScope", Nesting.empty)
        scope = Scope.empty.increase_by_ref(some_module_ref)
        state.add_constant(GlobalTree::Constant.new("ParentClass", scope, nil, nil))
        klass = state.add_class(ConstRef.from_full_name("ParentClass", Nesting.empty.increase_nesting_const(some_module_ref)))
        state.add_constant(GlobalTree::Constant.new("SomeClass", scope, nil, klass.id))

        expect(state.get_parent_of("SomeScope::SomeClass")).to eq("SomeScope::ParentClass")
      end

      specify "no const" do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(ConstRef.from_full_name("ParentClass", Nesting.empty))
        state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))

        expect(state.get_parent_of("SomeClass")).to eq("ParentClass")
      end

      specify "Object case" do
        state = GlobalTree.new(id_generator)

        expect(state.get_parent_of("Object")).to eq(nil)
      end

      specify do
        state = GlobalTree.new(id_generator)

        expect(state.get_parent_of("Foo")).to eq("Object")
      end

      specify do
        state = GlobalTree.new(id_generator)
        state.add_constant(GlobalTree::Constant.new("Foo", Scope.empty, nil, nil))

        expect(state.get_parent_of("Foo")).to eq("Object")
      end

      specify do
        state = GlobalTree.new(id_generator)
        state.add_constant(GlobalTree::Constant.new("Foo", Scope.empty, nil, 42))

        expect(state.get_parent_of("Foo")).to eq("Object")
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_class(nil)
        state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))

        expect(state.get_parent_of("SomeClass")).to eq("Object")
      end
    end

    describe "#set_type_of" do
      specify do
        state = GlobalTree.new(id_generator)

        state.set_type_of("foo", NominalType.new("Foo"))

        expect(state.type_of("foo")).to eq(NominalType.new("Foo"))
      end
    end

    describe "#type_of" do
      specify do
        state = GlobalTree.new(id_generator)

        state.set_type_of("foo", NominalType.new("Foo"))

        expect(state.type_of("foo")).to eq(NominalType.new("Foo"))
      end

      specify do
        state = GlobalTree.new(id_generator)

        expect(state.type_of("foo")).to eq(BottomType.new)
      end
    end
  end
end
