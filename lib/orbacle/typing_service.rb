require 'rgl/adjacency'

module Orbacle
  class TypingService
    NominalType = Struct.new(:name)
    UnionType = Struct.new(:types)
    GenericType = Struct.new(:name, :parameters)

    def call(original_graph, message_sends)
      graph = original_graph.reverse

      @result = {}
      recently_changed = Set.new

      graph.vertices.select do |node|
        if !dependent_on_input?(node)
          @result[node] = compute_result(node, graph.adjacent_vertices(node))
          recently_changed << node
        end
      end

      while !recently_changed.empty?
        changed_in_this_iteration = Set.new

        # we could compute here just the set of "affected" vertices set and not iterate

        original_graph.edges.each do |edge|
          if recently_changed.include?(edge.source)
            previous_result = @result[edge.target]
            @result[edge.target] = compute_result(edge.target, graph.adjacent_vertices(edge.target))
            if previous_result != @result[edge.target]
              changed_in_this_iteration << edge.target
            end
          end
        end

        recently_changed = changed_in_this_iteration
      end

      return @result
    end

    def dependent_on_input?(node)
      case node.type
      when :int then false
      when :lvar then true
      when :array then true
      when :lvasgn then true
      else raise ArgumentError.new(node.type)
      end
    end

    def compute_result(node, sources)
      case node.type
      when :int then handle_int(node, sources)
      when :lvar then handle_lvar(node, sources)
      when :array then handle_array(node, sources)
      when :lvasgn then handle_lvasgn(node, sources)
      else raise ArgumentError.new(node.type)
      end
    end

    def handle_int(node, sources)
      NominalType.new("Integer")
    end

    def handle_lvar(_node, sources)
      sources_types = sources.map {|source_node| @result[source_node] }.compact.uniq
      build_union(sources_types)
    end

    def handle_array(_node, sources)
      sources_types = sources.map {|source_node| @result[source_node] }.compact.uniq
      GenericType.new("Array", sources_types)
    end

    def handle_lvasgn(_node, sources)
      raise if sources.size != 1
      @result[sources.first]
    end

    def build_union(sources_types)
      if sources_types.size == 1
        sources_types.first
      else
        UnionType.new(sources_types)
      end
    end
  end
end
