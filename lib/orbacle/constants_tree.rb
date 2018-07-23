# frozen_string_literal: true

module Orbacle
  class ConstantsTree
    ScopeLevel = Struct.new(:elements, :children) do
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

    def add_element(scope, name, element)
      current_children = @tree
      scope.elems.each do |scope_level|
        current_children = current_children[scope_level].children
      end
      current_children[name].elements << element
    end

    def find_by_const_name(const_name)
      scope_children = children_of_scope(const_name.scope)
      scope_children[const_name.name].elements.first
    end

    def select_by_const_ref(const_ref)
      nesting = const_ref.nesting
      while !nesting.empty?
        result = select_by_scope_and_name(nesting.to_scope.increase_by_ref(const_ref).decrease, const_ref.name)
        return result if !result.empty?
        nesting = nesting.decrease_nesting
      end
      select_by_scope_and_name(Scope.empty.increase_by_ref(const_ref).decrease, const_ref.name)
    end

    def find_by_const_ref(const_ref)
      select_by_const_ref(const_ref).first
    end

    def find(&block)
      find_in_children(@tree, &block)
    end

    private
    def select_by_scope_and_name(scope, name)
      scope_level = children_of_scope(scope)[name]
      scope_level.elements
    end

    def children_of_scope(scope)
      scope.elems.reduce(@tree) do |current_scope_level, scope_elem|
        current_scope_level[scope_elem].children
      end
    end

    def find_in_children(children, &block)
      children.each do |_child_name, child_level|
        child_level.elements.each do |constant|
          return constant if block.call(constant)
        end
        result_in_child_level = find_in_children(child_level.children, &block)
        return result_in_child_level if result_in_child_level
      end
      nil
    end
  end
end
