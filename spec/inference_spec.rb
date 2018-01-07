require 'spec_helper'
require 'support/graph_matchers'

module Orbacle
  RSpec.describe Inference do
    it do
      equalities = [
        eq(tVar(0), tNominal("Integer"))
      ]

      result = infer(equalities)

      expect(result.size).to eq(1)
      expect(result[0]).to eq(tNominal("Integer"))
    end
  end

  def tVar(*args)
    Inference::TVar.new(*args)
  end

  def tNominal(*args)
    Inference::TNominal.new(*args)
  end

  def infer(equalities)
    Inference.new.(equalities)
  end

  def eq(left, right)
    [left, right]
  end
end
