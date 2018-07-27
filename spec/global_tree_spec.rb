# frozen_string_literal: true

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
        klass = state.add_klass(nil)
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
        klass = state.add_klass(nil)
        _constant = state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))
        metod = state.add_method(42, klass.id, "some_method", nil, :public, nil)

        result = state.find_instance_method_from_class_name("SomeClass", "some_method")

        expect(result).to eq(metod)
      end

      specify do
        state = GlobalTree.new(id_generator)
        klass = state.add_klass(nil)
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
        klass = state.add_klass(nil)
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
        klass = state.add_klass(nil)
        _constant = state.add_constant(GlobalTree::Constant.new("SomeClass", Scope.empty, nil, klass.id))
        eigenclass = state.get_eigenclass_of_definition(klass.id)
        metod1 = state.add_method(42, eigenclass.id, "some_method", nil, :public, nil)
        _metod2 = state.add_method(43, eigenclass.id, "some_method", nil, :public, nil)

        result = state.find_class_method_from_class_name("SomeClass", "some_method")

        expect(result).to eq(metod1)
      end
    end

    describe "#find_super_method" do
      specify do
        state = GlobalTree.new(id_generator)
        parent_class = state.add_klass(nil)
        parent_constant = state.add_constant(GlobalTree::Constant.new("ParentClass", Scope.empty, nil, parent_class.id))
        some_class = state.add_klass(ConstRef.from_full_name("ParentClass", Nesting.empty))
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
        some_class = state.add_klass(nil)
        some_method = state.add_method(43, some_class.id, "some_method", nil, :public, nil)

        result = state.find_super_method(43)

        expect(result).to eq(nil)
      end

      specify do
        state = GlobalTree.new(id_generator)
        some_class = state.add_klass(ConstRef.from_full_name("ParentClass", Nesting.empty))
        some_method = state.add_method(43, some_class.id, "some_method", nil, :public, nil)

        result = state.find_super_method(43)

        expect(result).to eq(nil)
      end
    end
  end
end
