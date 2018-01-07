module Orbacle
  class Inference
    TNominal = Struct.new(:name)
    TUnion = Struct.new(:elems)
    TVar = Struct.new(:index)
    # TGeneric = Struct.new(:nominal, :type_vars)
    def call(equalities)
      assignments = {}

      while !equalities.empty?
        equality = equalities.pop
        left = equality[0]
        right = equality[1]

        if left.is_a?(TVar)
          assignments[left.index] = right
        # elsif right.is_a?(TVar)
        #   assignments[right.index] = left
        end
      end

      assignments
    end
  end
end
