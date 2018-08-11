# frozen_string_literal: true

require 'rgl/adjacency'

module Orbacle
  class Graph
    ZSuper = Struct.new(:send_result, :block)
    Yield = Struct.new(:send_args, :send_result)
    Metod = Struct.new(:args, :result, :yields, :zsupers, :caller_node)
    MetodGraph = Struct.new(:args, :result, :yields, :caller_node, :all_nodes, :all_edges)
    Lambda = Struct.new(:args, :result)

    def initialize
      @original = RGL::DirectedAdjacencyGraph.new
      @reversed = RGL::DirectedAdjacencyGraph.new

      @global_variables = {}
      @constants = {}
      @main_ivariables = {}
      @instance_ivariables = {}
      @class_ivariables = {}
      @cvariables = {}
      @metods = {}
      @lambdas = {}
    end

    attr_reader :constants

    def add_vertex(node)
      raise if node.nil?
      @original.add_vertex(node)
      @reversed.add_vertex(node)
      node
    end

    def add_edges(nodes_source, nodes_target)
      Array(nodes_source).each do |source|
        Array(nodes_target).each do |target|
          add_edge(source, target)
        end
      end
    end

    def add_edge(x, y)
      raise if x.nil? || y.nil?
      @original.add_edge(x, y)
      @reversed.add_edge(y, x)
    end

    def edges
      @original.edges
    end

    def vertices
      @original.vertices
    end

    def adjacent_vertices(v)
      @original.adjacent_vertices(v)
    end

    def parent_vertices(v)
      @reversed.adjacent_vertices(v)
    end

    def has_edge?(x, y)
      @original.has_edge?(x, y)
    end

    def get_gvar_definition_node(gvar_name)
      global_variables[gvar_name] ||= add_vertex(Node.new(:gvar_definition, {}))
      return global_variables[gvar_name]
    end

    def get_main_ivar_definition_node(ivar_name)
      main_ivariables[ivar_name] ||= add_vertex(Node.new(:ivar_definition, {}))
      return main_ivariables[ivar_name]
    end

    def get_constant_definition_node(const_name)
      constants[const_name] ||= add_vertex(Node.new(:const_definition, {}))
      return constants[const_name]
    end

    def get_ivar_definition_node(scope, ivar_name)
      instance_ivariables[scope.absolute_str] ||= {}
      instance_ivariables[scope.absolute_str][ivar_name] ||= add_vertex(Node.new(:ivar_definition, {}))
      return instance_ivariables[scope.absolute_str][ivar_name]
    end

    def get_class_level_ivar_definition_node(scope, ivar_name)
      class_ivariables[scope.absolute_str] ||= {}
      class_ivariables[scope.absolute_str][ivar_name] ||= add_vertex(Node.new(:clivar_definition, {}))
      return class_ivariables[scope.absolute_str][ivar_name]
    end

    def get_cvar_definition_node(scope, ivar_name)
      cvariables[scope.absolute_str] ||= {}
      cvariables[scope.absolute_str][ivar_name] ||= add_vertex(Node.new(:cvar_definition, {}))
      return cvariables[scope.absolute_str][ivar_name]
    end

    def get_metod_nodes(method_id)
      metod = metods[method_id]
      if metod.instance_of?(Metod)
        metod
      else
        new_nodes = metod.all_nodes.map(&:clone)
        mapping = metod.all_nodes.zip(new_nodes).to_h
        new_nodes.each(&method(:add_vertex))
        metod.all_edges.each do |v1, v2|
          add_edge(mapping.fetch(v1), mapping.fetch(v2))
        end
        new_arguments_nodes = metod.args.each_with_object({}) do |(k, v), h|
          h[k] = mapping.fetch(v)
        end
        new_yields = metod.yields.map {|y| Yield.new(y.send_args.map {|a| mapping.fetch(a) }, mapping.fetch(y.send_result)) }
        Metod.new(new_arguments_nodes, mapping.fetch(metod.result), new_yields, [], mapping.fetch(metod.caller_node))
      end
    end

    def store_metod_nodes(metod_id, arguments_nodes)
      raise if !arguments_nodes.is_a?(Hash)
      metods[metod_id] ||= Metod.new(arguments_nodes, add_vertex(Node.new(:method_result, {})), [], [], nil)
    end

    def store_metod_subgraph(metod_id, arguments_nodes, caller_node, result_node, yields, all_nodes, all_edges)
      raise if !arguments_nodes.is_a?(Hash)
      metods[metod_id] ||= MetodGraph.new(arguments_nodes, result_node, yields, caller_node, all_nodes, all_edges)
    end

    def get_lambda_nodes(lambda_id)
      return lambdas[lambda_id]
    end

    def store_lambda_nodes(lambda_id, arguments_nodes, result_node)
      lambdas[lambda_id] ||= Lambda.new(arguments_nodes, result_node)
    end

    private
    attr_reader :global_variables, :main_ivariables, :instance_ivariables, :class_ivariables, :cvariables, :metods, :lambdas
  end
end
