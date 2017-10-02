require 'spec_helper'

module Orbacle
  RSpec.describe "ControlFlowGraph" do
    specify do
      snippet = <<-END
        x = Foo.new
      END

      r = generate_cfg(snippet)
      expect(r).to eq([
        { type: :lvasgn, lvar_name: "x",
          assigned_expr: [:init, [:constant, "Foo"], []] }
      ])
    end

    specify do
      snippet = <<-END
        x = Foo.bar
      END

      r = generate_cfg(snippet)
      expect(r).to eq([
        { type: :lvasgn, lvar_name: "x",
          assigned_expr: [:send, :bar, [:constant, "Foo"], []] }
      ])
    end

    specify do
      snippet = <<-END
        x = y.bar
      END

      r = generate_cfg(snippet)
      expect(r).to eq([
        { type: :lvasgn, lvar_name: "x",
          assigned_expr: [:send, :bar, [:send, "y"], []] }
      ])
    end

    def generate_cfg(snippet)
      service = ControlFlowGraph.new
      service.process_method(snippet)
    end
  end
end
