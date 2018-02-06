module Orbacle
  class Inference
    TNominal = Struct.new(:name)
    TUnion = Struct.new(:elems)
    TVar = Struct.new(:index)

    def call(equalities)
      assignments = {}

      while !equalities.empty?
        equality = equalities.pop
        left = equality[0]
        right = equality[1]

        if left.is_a?(TVar)
          assignments[left.index] = right
        end
      end

      strict_assignments = assignments.dup
      begin
        varcount = count_variables(strict_assignments)
        strict_assignments.each do |k, v|
          strict_assignments[k] = concretize_type(v, strict_assignments)
        end
      end while count_variables(strict_assignments) < varcount

      strict_assignments
    end

    def concretize_type(type, assignments)
      case type
      when TNominal
        type
      when TVar
        assignments[type.index].dup
      when TUnion
        new_elems = type.elems.map {|e| concretize_type(e, assignments) }
        TUnion.new(new_elems)
      end
    end

    def count_variables(assgns)
      assgns.values.map do |v|
        count_variables_in_type(v)
      end.sum
    end

    def count_variables_in_type(type)
      case type
      when TVar
        1
      when TNominal
        0
      when TUnion
        type.elems.map(&method(:count_variables_in_type)).sum
      end
    end
  end
end
