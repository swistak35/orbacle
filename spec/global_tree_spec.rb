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
  end
end
