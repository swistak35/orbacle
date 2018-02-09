require 'tree'

module Orbacle
  class GenerateClassHierarchy
    KlassNode = Struct.new(:name, :real, :inheritance)

    def initialize(db)
      @db = db
    end

    def call
      klasslikes = @db
        .find_all_klasslikes
        .select {|kl| kl.type == "klass" }

      klasstree_hash = {}
      klasstree_hash["Object"] = KlassNode.new("Object", false, nil)

      klasslikes.each do |kl|
        if kl.inheritance.nil?
          real_inheritance = "Object"
          full_name = [kl.scope, kl.name].compact.join("::")
          klasstree_hash[full_name] = KlassNode.new(full_name, true, real_inheritance)
        elsif kl.inheritance.start_with?("::")
          real_inheritance = kl.inheritance[2..-1]
          full_name = [kl.scope, kl.name].compact.join("::")
          klasstree_hash[full_name] = KlassNode.new(full_name, true, real_inheritance)

          scope = real_inheritance.split("::")[0..-2].join("::")
          scope = nil if scope == ""
          name = real_inheritance.split("::").last
          result = klasslikes.find do |kkl|
            kkl.scope == scope && kkl.name == name
          end
          if !result
            klasstree_hash[real_inheritance] = KlassNode.new(real_inheritance, false, "Object")
          end
        else
          possible_parents = kl.nesting.each_index.map do |i|
            [nesting_to_scope(kl.nesting[0..i]), kl.inheritance].compact.join("::")
          end
          possible_parents.unshift(kl.inheritance)
          possible_parents2 = possible_parents.map do |parent|
            scope = parent.split("::")[0..-2].join("::")
            scope = nil if scope == ""
            name = parent.split("::").last
            klasslikes.find do |kkl|
              kkl.scope == scope && kkl.name == name
            end
          end.compact
          chosen_real_inheritance = possible_parents2.last

          full_name = [kl.scope, kl.name].compact.join("::")
          if chosen_real_inheritance
            real_inheritance = [chosen_real_inheritance.scope, chosen_real_inheritance.name].compact.join("::")
            klasstree_hash[full_name] = KlassNode.new(full_name, true, real_inheritance)
          else
            real_inheritance = kl.inheritance.dup
            klasstree_hash[full_name] = KlassNode.new(full_name, true, real_inheritance)
            klasstree_hash[real_inheritance] = KlassNode.new(real_inheritance, false, "Object")
          end
        end
      end

      tree = Tree::TreeNode.new("Object", klasstree_hash["Object"])
      build_queue = [tree]
      while !build_queue.empty?
        current_node = build_queue.shift
        klasstree_hash
          .values
          .select {|kn| kn.inheritance == current_node.name }
          .each do |kn|
            tree_node = Tree::TreeNode.new(kn.name, kn)
            build_queue << tree_node
            current_node << tree_node
          end
      end
      # tree.print_tree

      ExportClassHierarchy.new.(tree)

      tree
    end

    def nesting_to_scope(nesting)
      return nil if nesting.empty?

      nesting.map do |_type, pre, name|
        pre + [name]
      end.join("::")
    end

    def scope_from_nesting_and_prename(nesting, prename)
      scope_from_nesting = nesting_to_scope(nesting)
      result = [scope_from_nesting, prename].compact.join("::")
      result if !result.empty?
    end
  end
end
