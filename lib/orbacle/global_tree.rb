require 'securerandom'

module Orbacle
  class GlobalTree
    class ConstantsTree
      ScopeLevel = Struct.new(:constants, :children) do
        def self.empty
          new([], build_empty_hash)
        end

        def self.build_empty_hash
          Hash.new {|h, k| h[k] = ScopeLevel.empty }
        end
      end

      def initialize
        @tree = ScopeLevel.build_empty_hash
      end

      def add_constant(constant)
        current_children = @tree
        constant.scope.elems.each do |scope_level|
          current_children = current_children[scope_level].children
        end
        current_children[constant.name].constants << constant
        return constant
      end

      def children_of_scope(scope)
        scope.elems.reduce(@tree) do |current_scope_level, scope_elem|
          current_scope_level[scope_elem].children
        end
      end

      def get_by_const_name(const_name)
        scope_children = children_of_scope(const_name.scope)
        scope_children[const_name.name].constants
      end

      def solve_reference(const_ref)
        nesting = const_ref.nesting
        while !nesting.empty?
          scope = nesting.to_scope
          scope_level = children_of_scope(scope.increase_by_ref(const_ref).decrease)[const_ref.name]
          return scope_level.constants[0] if scope_level && !scope_level.constants.empty?
          nesting = nesting.decrease_nesting
        end
        scope_level = children_of_scope(Scope.empty.increase_by_ref(const_ref).decrease)[const_ref.name]
        return scope_level.constants[0] if scope_level && !scope_level.constants.empty?
      end

      def get_by_definition(definition_id, children = @tree)
        children.each do |child_name, child_level|
          child_level.constants.each do |constant|
            return constant if constant.definition_id == definition_id
          end
          definition_in_child_level = get_by_definition(definition_id, child_level.children)
          return definition_in_child_level if definition_in_child_level
        end
        nil
      end
    end

    class ArgumentsTree < Struct.new(:args, :kwargs, :blockarg)
      Regular = Struct.new(:name)
      Optional = Struct.new(:name)
      Splat = Struct.new(:name)
      Nested = Struct.new(:args)
    end

    class Method
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

    class Lambda
      def initialize(id, args)
        @id = id
        @args = args
      end

      attr_reader :id, :args
    end

    class Klass
      def initialize(id: SecureRandom.uuid, parent_ref:, eigenclass_id: nil)
        @id = id
        @parent_ref = parent_ref
        @eigenclass_id = eigenclass_id
      end

      attr_reader :id, :parent_ref, :eigenclass_id
      attr_writer :eigenclass_id

      def ==(other)
        @id == other.id &&
          @parent_ref == other.parent_ref &&
          @eigenclass_id == other.eigenclass_id
      end
    end

    class Mod
      def initialize(id = SecureRandom.uuid, eigenclass_id = nil)
        @id = id
        @eigenclass_id = eigenclass_id
      end

      attr_reader :id, :eigenclass_id
      attr_writer :eigenclass_id

      def ==(other)
        @id == other.id &&
          @eigenclass_id == other.eigenclass_id
      end
    end

    class Constant
      def initialize(name, scope, location, definition_id = nil)
        @name = name
        @scope = scope
        @location = location
        @definition_id = definition_id
      end

      attr_reader :name, :scope, :location, :definition_id

      def ==(other)
        @name == other.name &&
          @scope == other.scope &&
          @location == other.location &&
          @definition_id == other.definition_id
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    def initialize
      @constants = ConstantsTree.new
      @classes = []
      @modules = []
      @metods = []
      @lambdas = []
    end

    attr_reader :metods

    def add_method(metod)
      @metods << metod
      return metod
    end

    def add_klass(klass)
      @classes << klass
      return klass
    end

    def add_mod(mod)
      @modules << mod
      return mod
    end

    def add_constant(constant)
      @constants.add_constant(constant)
      return constant
    end

    def add_lambda(args)
      lamba = Lambda.new(SecureRandom.uuid, args)
      @lambdas << lamba
      return lamba
    end

    def get_class(class_id)
      @classes.find {|c| c.id == class_id }
    end

    def get_module(module_id)
      @modules.find {|m| m.id == module_id }
    end

    def get_definition(definition_id)
      get_class(definition_id) || get_module(definition_id)
    end

    def get_eigenclass_of_definition(definition_id)
      definition = get_definition(definition_id)
      if definition.eigenclass_id
        return get_class(definition.eigenclass_id)
      else
        eigenclass = add_klass(Klass.new(parent_ref: nil))
        definition.eigenclass_id = eigenclass.id
        return eigenclass
      end
    end

    def solve_reference(const_ref)
      @constants.solve_reference(const_ref)
    end

    def get_parent_of(class_name)
      return nil if class_name == "Object"

      const = find_constant_by_name(class_name)
      return "Object" if const.nil?

      klass = get_class(const.definition_id)
      return "Object" if klass.nil?

      return "Object" if klass.parent_ref.nil?
      parent_const = solve_reference(klass.parent_ref)
      if parent_const
        parent_const.full_name
      else
        klass.parent_ref.relative_name
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
      eigenclass = get_eigenclass_of_definition(klass.id)
      @metods.find {|m| m.place_of_definition_id == eigenclass.id && m.name == method_name }
    end

    def find_any_methods(method_name)
      @metods.select {|m| m.name == method_name }
    end

    def find_super_method(method_id)
      analyzed_method = get_method(method_id)
      klass_of_this_method = get_class(analyzed_method.place_of_definition_id)
      return nil if klass_of_this_method.nil?
      parent_klass = solve_reference(klass_of_this_method.parent_ref) if klass_of_this_method.parent_ref
      find_instance_method(parent_klass.full_name, analyzed_method.name) if parent_klass
    end

    def get_method(method_id)
      @metods.find {|m| m.id == method_id }
    end

    def find_class_by_name(full_name)
      const = find_constant_by_name(full_name)
      return nil if const.nil?
      get_class(const.definition_id)
    end

    def find_module_by_name(full_name)
      const = find_constant_by_name(full_name)
      return nil if const.nil?
      get_module(const.definition_id)
    end

    def find_constant_by_name(full_name)
      @constants.get_by_const_name(ConstName.from_string(full_name)).first
    end

    def find_constant_for_definition(definition_id)
      @constants.get_by_definition(definition_id)
    end

    def change_metod_visibility(klass_id, name, new_visibility)
      @metods.each do |m|
        if m.place_of_definition_id == klass_id && m.name == name
          m.visibility = new_visibility
        end
      end
    end

    def get_lambda(lambda_id)
      @lambdas.find {|l| l.id == lambda_id }
    end
  end
end
