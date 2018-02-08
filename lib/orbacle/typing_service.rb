require 'rgl/adjacency'

module Orbacle
  class TypingService
    class DoubleEdgedGraph
      def initialize(graph)
        @original = graph
        @reversed = graph.reverse
      end

      def add_vertex(node)
        @original.add_vertex(node)
        @reversed.add_vertex(node)
      end

      def add_edge(u, v)
        @original.add_edge(u, v)
        @reversed.add_edge(v, u)
      end

      attr_reader :original, :reversed
    end

    class NominalType < Struct.new(:name)
      def each_possible_type
        yield self
      end
    end
    class ClassType < Struct.new(:klasslike)
      def name
        "Class"
      end

      def each_possible_type
        yield self
      end
    end
    UnionType = Struct.new(:types)
    class GenericType < Struct.new(:name, :parameters)
      def each_possible_type
        yield self
      end
    end

    def call(graph, message_sends)
      @graph = DoubleEdgedGraph.new(graph)

      @result = {}
      @fresh_nodes = []
      recently_changed = Set.new

      recently_changed = Set.new
      @graph.original.each_vertex do |v|
        @result[v] = compute_result(v, @graph.reversed.adjacent_vertices(v))
        if @result[v]
          recently_changed << v
          # puts "Marked #{v} as dirty after setting it's value to #{@result[v].inspect}"
        end
      end

      while !recently_changed.empty?
        @changed_in_this_iteration = Set.new

        # we could compute here just the set of "affected" vertices set and not iterate

        @fresh_nodes.each do |node|
          @result[node] = compute_result(node, @graph.reversed.adjacent_vertices(node))
        end
        @fresh_nodes = []

        @graph.original.edges.each do |edge|
          if recently_changed.include?(edge.source)
            previous_result = @result[edge.target]
            @result[edge.target] = compute_result(edge.target, @graph.reversed.adjacent_vertices(edge.target))
            if previous_result != @result[edge.target]
              @changed_in_this_iteration << edge.target
              # puts "Marked #{edge.target} as dirty after setting it's value to #{@result[edge.target].inspect}"
            end
          end
        end

        message_sends.each do |message_send|
          if satisfied_message_send?(message_send)
            handle_message_send(message_send, graph)
          end
        end

        recently_changed = @changed_in_this_iteration
      end

      return @result
    end

    def dependent_on_input?(node)
      ![:int].include?(node.type)
    end

    def compute_result(node, sources)
      case node.type
      when :int then handle_int(node, sources)
      when :lvar then handle_lvar(node, sources)
      when :array then handle_array(node, sources)
      when :lvasgn then handle_lvasgn(node, sources)
      when :call_obj then handle_call_obj(node, sources)
      when :call_result then handle_call_result(node, sources)
      when :block_arg then handle_block_arg(node, sources)
      when :block_result then handle_block_result(node, sources)
      when :primitive_integer_succ then handle_primitive_integer_succ(node, sources)
      when :primitive_integer_to_s then handle_primitive_integer_to_s(node, sources)
      when :primitive_array_map_1 then handle_primitive_array_map_1(node, sources)
      when :primitive_array_map_2 then handle_primitive_array_map_2(node, sources)
      when :class then handle_class(node, sources)
      when :constructor then handle_constructor(node, sources)
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
      raise if sources.size > 1
      @result[sources.first]
    end

    def handle_block_arg(_node, sources)
      raise if sources.size > 1
      @result[sources.first]
    end

    def handle_block_result(_node, sources)
      raise if sources.size > 1
      @result[sources.first]
    end

    def build_union(sources_types)
      if sources_types.size == 0
        nil
      elsif sources_types.size == 1
        sources_types.first
      else
        UnionType.new(sources_types)
      end
    end

    def handle_class(node, _sources)
      klasslike = node.params.fetch(:klasslike)
      ClassType.new(klasslike)
    end

    def satisfied_message_send?(message_send)
      @result[message_send.send_obj] &&
        message_send.send_args.all? {|a| @result[a] }
    end

    def handle_message_send(message_send, graph)
      @result[message_send.send_obj].each_possible_type do |possible_type|
        if primitive_send?(possible_type, message_send.message_send)
          handle_primitive(possible_type, message_send, graph)
        else
          raise "Not implemented yet"
        end
      end
    end

    def primitive_send?(type, message_name)
      if type.name == "Class" && message_name == "new"
        true
      elsif type.name == "Integer" && ["succ", "to_s"].include?(message_name)
        true
      elsif type.name == "Array" && message_name == "map"
        true
      else
        false
      end
    end

    def handle_primitive(type, message_send, graph)
      message_name = message_send.message_send

      if type.name == "Integer" && message_name == "succ"
        send_primitive_integer_succ(type, message_send, graph)
      elsif type.name == "Integer" && message_name == "to_s"
        send_primitive_integer_to_s(type, message_send, graph)
      elsif type.name == "Array" && message_name == "map"
        send_primitive_array_map(type, message_send, graph)
      elsif message_name == "new"
        send_constructor(type, message_send, graph)
      else
        raise ArgumentError.new(possible_type)
      end
    end

    def send_constructor(type, message_send, graph)
      already_handled = @graph.original.adjacent_vertices(message_send.send_obj).any? do |adjacent_node|
        adjacent_node.type == :constructor
      end
      return if already_handled

      node = ControlFlowGraph::Node.new(:constructor, { name: type.klasslike.name })
      @graph.add_vertex(node)
      @fresh_nodes << node
      @graph.add_edge(message_send.send_obj, node)
      @graph.add_edge(node, message_send.send_result)
      @changed_in_this_iteration << node
    end

    def send_primitive_integer_succ(type, message_send, graph)
      already_handled = @graph.original.adjacent_vertices(message_send.send_obj).any? do |adjacent_node|
        adjacent_node.type == :primitive_integer_succ
      end
      return if already_handled

      node = ControlFlowGraph::Node.new(:primitive_integer_succ)
      @graph.add_vertex(node)
      @fresh_nodes << node
      @graph.add_edge(message_send.send_obj, node)
      @graph.add_edge(node, message_send.send_result)
      @changed_in_this_iteration << node
    end

    def send_primitive_integer_to_s(type, message_send, graph)
      already_handled = @graph.original.adjacent_vertices(message_send.send_obj).any? do |adjacent_node|
        adjacent_node.type == :primitive_integer_to_s
      end
      return if already_handled

      node = ControlFlowGraph::Node.new(:primitive_integer_to_s)
      @graph.add_vertex(node)
      @fresh_nodes << node
      @graph.add_edge(message_send.send_obj, node)
      @graph.add_edge(node, message_send.send_result)
      @changed_in_this_iteration << node
    end

    def send_primitive_array_map(type, message_send, graph)
      already_handled = @graph.original.adjacent_vertices(message_send.send_obj).any? do |adjacent_node|
        adjacent_node.type == :primitive_array_map_1
      end
      return if already_handled

      raise if message_send.block.nil?

      unwrapping_node = ControlFlowGraph::Node.new(:primitive_array_map_1)
      @graph.add_vertex(unwrapping_node)
      @fresh_nodes << unwrapping_node
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @graph.add_edge(unwrapping_node, message_send.block.args.first)

      wrapping_node = ControlFlowGraph::Node.new(:primitive_array_map_2)
      @graph.add_vertex(wrapping_node)
      @fresh_nodes << wrapping_node
      @graph.add_edge(message_send.block.result, wrapping_node)
      @graph.add_edge(wrapping_node, message_send.send_result)

      @changed_in_this_iteration << unwrapping_node
      @changed_in_this_iteration << wrapping_node
    end

    def handle_primitive_integer_succ(_node, _sources)
      NominalType.new("Integer")
    end

    def handle_primitive_integer_to_s(_node, _sources)
      NominalType.new("String")
    end

    def handle_primitive_array_map_1(_node, sources)
      raise if sources.size != 1
      source = sources.first
      @result[source].parameters.first
    end

    def handle_primitive_array_map_2(_node, sources)
      raise if sources.size != 1
      source = sources.first
      GenericType.new("Array", [@result[source]])
    end

    def handle_constructor(node, sources)
      NominalType.new(node.params.fetch(:name))
    end
  end
end
