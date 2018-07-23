# frozen_string_literal: true

require 'spec_helper'
require 'benchmark'

module Orbacle
  RSpec.describe ConstantsTree, performance: true do
    describe "performance" do
      specify "#find_by_const_ref 1" do
        tree = ConstantsTree.new

        const = nil
        1000.times do |i|
          1000.times do |j|
            const = Object.new
            tree.add_element(
              Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo#{i}", Nesting.empty)),
              "Bar#{j}",
              const)
          end
        end

        nesting = Nesting.empty
          .increase_nesting_const(ConstRef.from_full_name("Foo999", Nesting.empty))
        const_ref = ConstRef.from_full_name("Bar999", nesting)

        benchmark_result = Benchmark.measure do
          result = tree.find_by_const_ref(const_ref)
          expect(result).to eq(const)
        end

        expect(benchmark_result.real).to be < 0.01
      end
    end
  end
end
