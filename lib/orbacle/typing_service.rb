require 'rgl/adjacency'

module Orbacle
  class TypingService
    class NominalType < Struct.new(:name)
      def each_possible_type
        yield self
      end
    end
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
        @changed_in_this_iteration = Set.new

        # we could compute here just the set of "affected" vertices set and not iterate

        original_graph.edges.each do |edge|
          if recently_changed.include?(edge.source)
            previous_result = @result[edge.target]
            @result[edge.target] = compute_result(edge.target, graph.adjacent_vertices(edge.target))
            if previous_result != @result[edge.target]
              @changed_in_this_iteration << edge.target
            end
          end
        end

        message_sends.each do |message_send|
          if satisfied_message_send?(message_send)
            handle_message_send(message_send, graph, original_graph)
          end
        end

        recently_changed = @changed_in_this_iteration
      end

      return @result
    end

    def dependent_on_input?(node)
      case node.type
      when :int then false
      when :lvar then true
      when :array then true
      when :lvasgn then true
      when :call_obj then true
      when :call_result then true
      else raise ArgumentError.new(node.type)
      end
    end

    def compute_result(node, sources)
      case node.type
      when :int then handle_int(node, sources)
      when :lvar then handle_lvar(node, sources)
      when :array then handle_array(node, sources)
      when :lvasgn then handle_lvasgn(node, sources)
      when :call_obj then handle_call_obj(node, sources)
      when :call_result then handle_call_result(node, sources)
      when :primitive_integer_succ then handle_primitive_integer_succ(node, sources)
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

    def handle_call_obj(_node, sources)
      raise if sources.size != 1
      @result[sources.first]
    end

    def handle_call_result(_node, sources)
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

    def satisfied_message_send?(message_send)
      @result[message_send.send_obj] &&
        message_send.send_args.all? {|a| @result[a] }
    end

    def handle_message_send(message_send, graph, original_graph)
      @result[message_send.send_obj].each_possible_type do |possible_type|
        if primitive_send?(possible_type, message_send.message_send)
          handle_primitive(possible_type, message_send, graph, original_graph)
        else
          raise "Not implemented yet"
        end
      end
    end

    def primitive_send?(type, message_name)
      if type.name == "Integer" && message_name == "succ"
        true
      else
        false
      end
    end

    def handle_primitive(type, message_send, graph, original_graph)
      message_name = message_send.message_send

      if type.name == "Integer" && message_name == "succ"
        send_primitive_integer_succ(type, message_send, graph, original_graph)
      else
        raise ArgumentError.new(possible_type)
      end
    end

    def send_primitive_integer_succ(type, message_send, graph, original_graph)
      already_handled = original_graph.adjacent_vertices(message_send.send_obj).any? do |adjacent_node|
        adjacent_node.type == :primitive_integer_succ
      end
      return if already_handled

      node = ControlFlowGraph::Node.new(:primitive_integer_succ)
      original_graph.add_vertex(node)
      original_graph.add_edge(message_send.send_obj, node)
      original_graph.add_edge(node, message_send.send_result)
      graph.add_vertex(node)
      graph.add_edge(node, message_send.send_obj)
      graph.add_edge(message_send.send_result, node)
      @changed_in_this_iteration << node
    end

    def handle_primitive_integer_succ(_node, _sources)
      NominalType.new("Integer")
    end
  end
end
