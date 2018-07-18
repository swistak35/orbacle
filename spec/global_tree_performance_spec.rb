require 'spec_helper'
require 'benchmark'

module Orbacle
  RSpec.describe GlobalTree, performance: true do
    describe "#solve_reference" do
      specify "performance 1" do
        tree = GlobalTree.new

        klass = nil
        1000.times do |i|
          1000.times do |j|
            klass = tree.add_constant(
              GlobalTree::Constant.new(
                "Bar#{j}",
                Scope.empty.increase_by_ref(ConstRef.from_full_name("Foo#{i}", Nesting.empty)),
                nil))
          end
        end

        nesting = Nesting.empty
          .increase_nesting_const(ConstRef.from_full_name("Foo999", Nesting.empty))
        const_ref = ConstRef.from_full_name("Bar999", nesting)

        benchmark_result = Benchmark.measure do
          result = tree.solve_reference(const_ref)
          expect(result).to eq(klass)
        end

        expect(benchmark_result.real).to be < 5.0
      end
    end
  end
end
