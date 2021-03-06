# frozen_string_literal: true

module Orbacle
  class GlobalTree
    class ArgumentsTree < Struct.new(:args, :kwargs, :blockarg)
      Regular = Struct.new(:name)
      Optional = Struct.new(:name)
      Splat = Struct.new(:name)
      Nested = Struct.new(:args)
    end

    class Method
      def initialize(id, place_of_definition_id, name, location, visibility, args)
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
      def initialize(id, parent_ref, eigenclass_id = nil)
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
      def initialize(id, eigenclass_id = nil)
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

    def initialize(id_generator)
      @id_generator = id_generator
      @constants = ConstantsTree.new
      @classes_by_id = {}
      @modules_by_id = {}
      @methods_by_class_id = Hash.new {|h,k| h[k] = Hash.new {|h2, k2| h2[k2] = [] } }
      @methods_by_id = {}
      @lambdas_by_id = {}
      @type_mapping = Hash.new(BottomType.new)
    end

    ### Methods

    def add_method(id, place_of_definition_id, name, location, visibility, args)
      metod = Method.new(id, place_of_definition_id, name, location, visibility, args)
      @methods_by_class_id[metod.place_of_definition_id][metod.name] << metod
      @methods_by_id[metod.id] = metod
      metod
    end

    def find_instance_method_from_class_name(class_name, method_name)
      get_instance_methods_from_class_name(class_name, method_name).first
    end

    def find_instance_method_from_class_id(class_id, method_name)
      get_instance_methods_from_class_id(class_id, method_name).first
    end

    def get_instance_methods_from_class_id(class_id, method_name)
      @methods_by_class_id[class_id][method_name]
    end

    def get_instance_methods_from_class_name(class_name, method_name)
      klass = find_class_by_name(class_name)
      return [] if klass.nil?
      get_instance_methods_from_class_id(klass.id, method_name)
    end

    def get_class_methods_from_class_name(class_name, method_name)
      klass = find_class_by_name(class_name)
      return [] if klass.nil?
      eigenclass = get_eigenclass_of_definition(klass.id)
      get_instance_methods_from_class_id(eigenclass.id, method_name)
    end

    def get_all_instance_methods_from_class_name(class_name)
      klass = find_class_by_name(class_name)
      return [] if klass.nil?
      @methods_by_class_id[klass.id].values.flatten
    end

    def find_class_method_from_class_name(class_name, method_name)
      get_class_methods_from_class_name(class_name, method_name).first
    end

    def get_methods(method_name)
      @methods_by_id.values.select do |m|
        m.name.eql?(method_name)
      end
    end

    def find_super_method(method_id)
      analyzed_method = @methods_by_id.fetch(method_id)
      klass_of_this_method = get_class(analyzed_method.place_of_definition_id)
      return nil if klass_of_this_method.nil? || klass_of_this_method.parent_ref.nil?
      parent_klass = solve_reference(klass_of_this_method.parent_ref)
      return nil if parent_klass.nil?
      find_instance_method_from_class_name(parent_klass.full_name, analyzed_method.name)
    end

    def change_method_visibility(klass_id, name, new_visibility)
      @methods_by_class_id[klass_id][name].each do |m|
        m.visibility = new_visibility
      end
    end

    def find_method_including_position(file_path, position)
      @methods_by_id
        .values
        .select {|m| m.location &&
                 m.location.uri.eql?(file_path) &&
                 m.location.position_range.include_position?(position) }
        .sort_by {|m| m.location.span }
        .first
    end

    ### Definitions

    def add_class(parent_ref)
      klass = Klass.new(id_generator.call, parent_ref)
      @classes_by_id[klass.id] = klass
      klass
    end

    def add_module
      mod = Mod.new(id_generator.call)
      @modules_by_id[mod.id] = mod
      mod
    end

    def get_class(class_id)
      @classes_by_id[class_id]
    end

    def get_module(module_id)
      @modules_by_id[module_id]
    end

    def get_definition(definition_id)
      get_class(definition_id) || get_module(definition_id)
    end

    def get_eigenclass_of_definition(definition_id)
      definition = get_definition(definition_id)
      if definition.eigenclass_id
        get_class(definition.eigenclass_id)
      else
        eigenclass = add_class(nil)
        definition.eigenclass_id = eigenclass.id
        eigenclass
      end
    end

    ### Constants

    def add_constant(constant)
      @constants.add_element(constant.scope, constant.name, constant)
      constant
    end

    def solve_reference(const_ref)
      @constants.find_by_const_ref(const_ref)
    end

    def solve_reference2(const_ref)
      @constants.select_by_const_ref(const_ref)
    end

    ### Lambdas

    def add_lambda(args)
      lamba = Lambda.new(id_generator.call, args)
      @lambdas_by_id[lamba.id] = lamba
      lamba
    end

    def get_lambda(lambda_id)
      @lambdas_by_id[lambda_id]
    end

    ### Other

    def get_parent_of(class_name)
      return nil if class_name.eql?("Object")

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
      @constants.find_by_const_name(ConstName.from_string(full_name))
    end

    def find_constant_for_definition(definition_id)
      @constants.find do |constant|
        constant.definition_id.equal?(definition_id)
      end
    end

    def find_deep_instance_method_from_class_name(class_name, method_name)
      get_deep_instance_methods_from_class_name(class_name, method_name).first
    end

    def get_deep_instance_methods_from_class_name(class_name, method_name)
      found_methods = get_instance_methods_from_class_name(class_name, method_name)
      if found_methods.empty?
        parent_name = get_parent_of(class_name)
        if parent_name
          get_deep_instance_methods_from_class_name(parent_name, method_name)
        else
          []
        end
      else
        found_methods
      end
    end

    def find_deep_class_method_from_class_name(class_name, method_name)
      get_deep_class_methods_from_class_name(class_name, method_name).first
    end

    def get_deep_class_methods_from_class_name(class_name, method_name)
      found_methods = get_class_methods_from_class_name(class_name, method_name)
      if found_methods.empty?
        parent_name = get_parent_of(class_name)
        if parent_name
          get_deep_class_methods_from_class_name(parent_name, method_name)
        else
          []
        end
      else
        found_methods
      end
    end

    ### Types

    def type_of(node)
      @type_mapping[node]
    end

    def set_type_of(node, new_type)
      @type_mapping[node] = new_type
    end

    private
    attr_reader :id_generator
  end
end
