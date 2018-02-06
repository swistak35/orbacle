require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe Inference do
    it do
      equalities = [
        tEq(tVar(0), tNominal("Integer")),
      ]

      result = infer(equalities)

      expect(result.size).to eq(1)
      expect(result[0]).to eq(tNominal("Integer"))
    end

    it do
      equalities = [
        tEq(tVar(0), tVar(1)),
        tEq(tVar(1), tNominal("Integer")),
      ]

      result = infer(equalities)

      expect(result.size).to eq(2)
      expect(result[0]).to eq(tNominal("Integer"))
      expect(result[1]).to eq(tNominal("Integer"))
    end

    it do
      equalities = [
        tEq(tVar(0), tNominal("Integer")),
        tEq(tVar(1), tNominal("String")),
        tEq(tVar(2), tUnion([tVar(0), tVar(1)])),
      ]

      result = infer(equalities)

      expect(result.size).to eq(3)
      expect(result[0]).to eq(tNominal("Integer"))
      expect(result[1]).to eq(tNominal("String"))
      expect(result[2]).to eq(tUnion([tNominal("Integer"), tNominal("String")]))
    end

    def tVar(*args)
      Inference::TVar.new(*args)
    end

    def tNominal(*args)
      Inference::TNominal.new(*args)
    end

    def tUnion(*args)
      raise if !args[0].is_a?(Array)
      Inference::TUnion.new(*args)
    end

    def infer(equalities)
      Inference.new.(equalities)
    end

    def tEq(left, right)
      [left, right]
    end
  end
end
