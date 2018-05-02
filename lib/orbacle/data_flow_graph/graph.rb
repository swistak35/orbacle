require 'rgl/adjacency'

module Orbacle
  module DataFlowGraph
    class Graph
      Metod = Struct.new(:args, :result, :yields)
      Lambda = Struct.new(:args, :result)

      def initialize
        @graph = RGL::DirectedAdjacencyGraph.new

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
        @graph.add_vertex(node)
        node
      end

      def add_edges(nodes_source, nodes_target)
        Array(nodes_source).each do |source|
          Array(nodes_target).each do |target|
            @graph.add_edge(source, target)
          end
        end
      end

      def add_edge(x, y)
        @graph.add_edge(x, y)
      end

      def edges
        @graph.edges
      end

      def vertices
        @graph.vertices
      end

      def adjacent_vertices(v)
        @graph.adjacent_vertices(v)
      end

      def reverse
        @graph.reverse
      end

      def has_edge?(x, y)
        @graph.has_edge?(x, y)
      end

      def get_gvar_definition_node(gvar_name)
        global_variables[gvar_name] ||= add_vertex(Node.new(:gvar_definition))
        return global_variables[gvar_name]
      end

      def get_main_ivar_definition_node(ivar_name)
        main_ivariables[ivar_name] ||= add_vertex(Node.new(:ivar_definition))
        return main_ivariables[ivar_name]
      end

      def get_constant_definition_node(const_name)
        constants[const_name] ||= add_vertex(Node.new(:const_definition))
        return constants[const_name]
      end

      def get_ivar_definition_node(scope, ivar_name)
        instance_ivariables[scope.absolute_str] ||= {}
        instance_ivariables[scope.absolute_str][ivar_name] ||= add_vertex(Node.new(:ivar_definition))
        return instance_ivariables[scope.absolute_str][ivar_name]
      end

      def get_class_level_ivar_definition_node(scope, ivar_name)
        class_ivariables[scope.absolute_str] ||= {}
        class_ivariables[scope.absolute_str][ivar_name] ||= add_vertex(Node.new(:clivar_definition))
        return class_ivariables[scope.absolute_str][ivar_name]
      end

      def get_cvar_definition_node(scope, ivar_name)
        cvariables[scope.absolute_str] ||= {}
        cvariables[scope.absolute_str][ivar_name] ||= add_vertex(Node.new(:cvar_definition))
        return cvariables[scope.absolute_str][ivar_name]
      end

      def get_metod_nodes(metod_id)
        return metods[metod_id]
      end

      def store_metod_nodes(metod_id, arguments_nodes)
        metods[metod_id] ||= Metod.new(arguments_nodes, add_vertex(Node.new(:method_result)), [])
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
end
