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
    end
  end
end
