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
      def initialize(id:, place_of_definition_id:, name:, location:, visibility:, args:)
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
      def initialize(id:, parent_ref:, eigenclass_id: nil)
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
      @metods = Hash.new {|h,k| h[k] = Hash.new {|h2, k2| h2[k2] = [] } }
      @metods_by_id = {}
      @lambdas_by_id = {}
    end

    attr_reader :metods

    def add_method(metod)
      @metods[metod.place_of_definition_id][metod.name] << metod
      @metods_by_id[metod.id] = metod
      return metod
    end

    def add_klass(klass)
      @classes_by_id[klass.id] = klass
      return klass
    end

    def add_klass2(parent_ref)
      add_klass(Klass.new(id: id_generator.call, parent_ref: parent_ref))
    end

    def add_mod(mod)
      @modules_by_id[mod.id] = mod
      return mod
    end

    def add_constant(constant)
      @constants.add_element(constant.scope, constant.name, constant)
      return constant
    end

    def add_lambda(args)
      lamba = Lambda.new(id_generator.call, args)
      @lambdas_by_id[lamba.id] = lamba
      return lamba
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
        return get_class(definition.eigenclass_id)
      else
        eigenclass = add_klass(Klass.new(id: id_generator.call, parent_ref: nil))
        definition.eigenclass_id = eigenclass.id
        return eigenclass
      end
    end

    def solve_reference(const_ref)
      @constants.find_by_const_ref(const_ref)
    end

    def solve_reference2(const_ref)
      @constants.select_by_const_ref(const_ref)
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
      @metods[class_id][method_name].first
    end

    def get_instance_methods_for_class(class_name, method_name)
      klass = find_class_by_name(class_name)
      @metods[klass.id][method_name]
    end

    def get_class_methods_for_class(class_name, method_name)
      klass = find_class_by_name(class_name)
      return [] if klass.nil?
      eigenclass = get_eigenclass_of_definition(klass.id)
      @metods[eigenclass.id][method_name]
    end

    def find_class_method(class_name, method_name)
      get_class_methods_for_class(class_name, method_name).first
    end

    def find_super_method(method_id)
      analyzed_method = @metods_by_id[method_id]
      klass_of_this_method = get_class(analyzed_method.place_of_definition_id)
      return nil if klass_of_this_method.nil?
      parent_klass = solve_reference(klass_of_this_method.parent_ref) if klass_of_this_method.parent_ref
      find_instance_method(parent_klass.full_name, analyzed_method.name) if parent_klass
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
        constant.definition_id == definition_id
      end
    end

    def change_metod_visibility(klass_id, name, new_visibility)
      @metods_by_id.each do |_id, m|
        if m.place_of_definition_id == klass_id && m.name == name
          m.visibility = new_visibility
        end
      end
    end

    def get_lambda(lambda_id)
      @lambdas_by_id[lambda_id]
    end

    private
    attr_reader :id_generator
  end
end
