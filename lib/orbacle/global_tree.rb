require 'securerandom'

module Orbacle
  class GlobalTree
    class Method
      class ArgumentsTree < Struct.new(:args, :kwargs, :blockarg)
        Regular = Struct.new(:name)
        Optional = Struct.new(:name)
        Splat = Struct.new(:name)
        Nested = Struct.new(:args)
      end

      def initialize(id: SecureRandom.uuid, place_of_definition_id:, name:, location:, visibility:, args:)
        raise ArgumentError.new(visibility) if ![:public, :private, :protected].include?(visibility)

        @id = id
        @place_of_definition_id = place_of_definition_id
        @name = name
        @location = location
        @visibility = visibility
        @args = args
      end

      attr_reader :id, :name, :location, :args, :place_of_definition_id
      attr_accessor :visibility
    end

    class Klass
      def initialize(id: SecureRandom.uuid, name:, scope:, location:, parent_ref:, eigenclass_id: nil)
        @id = id
        @name = name
        @scope = scope
        @location = location
        @parent_ref = parent_ref
        @eigenclass_id = eigenclass_id
      end

      attr_reader :id, :name, :scope, :location, :parent_ref, :eigenclass_id
      attr_writer :eigenclass_id

      def ==(other)
        @id == other.id &&
          @name == other.name &&
          @scope == other.scope &&
          @parent_ref == other.parent_ref &&
          @location == location
      end

      def full_name
        if scope
          [*scope.elems, @name].join("::")
        else
          ""
        end
      end
    end

    class Mod
      def initialize(id: SecureRandom.uuid, name:, scope:, location:)
        @id = id
        @name = name
        @scope = scope
        @location = location
      end

      attr_reader :id, :name, :scope, :location

      def ==(other)
        @id = other.id &&
          @name == other.name &&
          @scope == other.scope &&
          @location == location
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    class Constant
      def initialize(name:, scope:, location:)
        @name = name
        @scope = scope
        @location = location
      end

      attr_reader :name, :scope, :location

      def ==(other)
        @name == other.name &&
          @scope == other.scope &&
          @location == location
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    def initialize
      @constants = []
      @metods = []
      @lambdas = []
    end

    attr_reader :metods, :constants

    def add_method(metod)
      @metods << metod
      return metod
    end

    def add_klass(klass)
      @constants << klass
      return klass
    end

    def add_mod(mod)
      @constants << mod
      return mod
    end

    def add_constant(constant)
      @constants << constant
      return constant
    end

    def add_lambda
      lambda_id = SecureRandom.uuid
      @lambdas << lambda_id
      return lambda_id
    end

    def get_class(klass_id)
      @constants.find {|c| (c.is_a?(Klass) || c.is_a?(Mod)) && c.id == klass_id }
    end

    def get_eigenclass_of_klass(klass_id)
      klass = get_class(klass_id)
      if klass.eigenclass_id
        return get_class(klass.eigenclass_id)
      else
        eigenclass = add_klass(Klass.new(name: nil, scope: nil, location: nil, parent_ref: nil, eigenclass_id: nil))
        klass.eigenclass_id = eigenclass.id
        return eigenclass
      end
    end

    def solve_reference(const_ref)
      nesting = const_ref.nesting
      while !nesting.empty?
        scope = nesting.to_scope
        @constants.each do |constant|
          return constant if constant.name && scope.increase_by_ref(const_ref).to_const_name == ConstName.from_string(constant.full_name)
        end
        nesting = nesting.decrease_nesting
      end
      @constants.find do |constant|
        constant.full_name != "" && const_ref.const_name == ConstName.from_string(constant.full_name)
      end
    end

    def get_parent_of(class_name)
      possible_parents = @constants
        .select {|c| c.is_a?(Klass) }
        .select {|c| c.full_name == class_name }
        .map(&:parent_ref)
        .reject(&:nil?)
        .map(&method(:solve_reference))
        .reject(&:nil?)
        .map(&:full_name)
      if class_name == "Object"
        nil
      elsif possible_parents.empty?
        "Object"
      else
        possible_parents[0]
      end
    end

    def find_instance_method(class_name, method_name)
      klass = find_class_by_name(class_name)
      return nil if klass.nil?
      find_instance_method2(klass.id, method_name)
    end

    def find_instance_method2(class_id, method_name)
      @metods.find {|m| m.place_of_definition_id == class_id && m.name == method_name }
    end

    def find_class_method(class_name, method_name)
      klass = find_class_by_name(class_name)
      return nil if klass.nil?
      eigenclass = get_eigenclass_of_klass(klass.id)
      @metods.find {|m| m.place_of_definition_id == eigenclass.id && m.name == method_name }
    end

    def find_any_methods(method_name)
      @metods.select {|m| m.name == method_name }
    end

    def find_super_method(method_id)
      analyzed_method = get_method(method_id)
      klass_of_this_method = get_class(analyzed_method.place_of_definition_id)
      parent_klass = solve_reference(klass_of_this_method.parent_ref)
      find_instance_method(parent_klass.full_name, analyzed_method.name)
    end

    def get_method(method_id)
      @metods.find {|m| m.id == method_id }
    end

    def find_class_by_name(full_name)
      @constants.find do |constant|
        !constant.name.nil? && constant.is_a?(Klass) && constant.full_name == full_name
      end
    end

    def find_module_by_name(full_name)
      @constants.find do |constant|
        !constant.name.nil? && constant.is_a?(Mod) && constant.full_name == full_name
      end
    end

    def find_constant_by_name(full_name)
      @constants.find do |constant|
        !constant.name.nil? && constant.is_a?(Constant) && constant.full_name == full_name
      end
    end

    def change_metod_visibility(klass_id, name, new_visibility)
      @metods.each do |m|
        if m.place_of_definition_id == klass_id && m.name == name
          m.visibility = new_visibility
        end
      end
    end
  end
end
