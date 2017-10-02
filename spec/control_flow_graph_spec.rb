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

    specify do
      snippet = <<-END
        x = y.bar
        z = x.foo
      END

      r = generate_cfg(snippet)
      expect(r).to eq([
        { type: :lvasgn, lvar_name: "x",
          assigned_expr: [:send, :bar, [:send, "y"], []] },
        { type: :lvasgn, lvar_name: "z",
          assigned_expr: [:send, :foo, [:lvar, "x"], []] },
      ])
    end

    specify do
      snippet = <<-END
        x = y.bar.baz
      END

      r = generate_cfg(snippet)
      expect(r).to eq([
        { type: :tmpasgn, tmp_name: "0",
          assigned_expr: [:send, :bar, [:send, "y"], []] },
        { type: :lvasgn, lvar_name: "x",
          assigned_expr: [:send, :baz, [:tmpvar, "0"], []] },
      ])
    end

    def generate_cfg(snippet)
      service = ControlFlowGraph.new
      service.process_method(snippet)
    end
  end
end
