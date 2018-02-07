module Orbacle
  class Indexer
    class IndexFile
      def initialize(db:)
        @db = db
      end

      def call(path:, content:)
        parser = ControlFlowGraph.new
        _graph, _final_lenv, _sends, _node, methods, constants, klasslikes = parser.process_file(content)
        # return [@graph, final_local_environment, @message_sends, final_node, @methods, @constants, @klasslikes]
        constants.each do |c|
          scope, name, type, opts = c

          @db.add_constant(
            scope: scope,
            name: name,
            type: type.to_s,
            path: path,
            line: opts.fetch(:line))
        end
        methods.each do |m|
          _scope, name, opts = m

          @db.add_metod(
            name: name,
            file: path,
            line: opts.fetch(:line))
        end
        klasslikes.each do |kl|
          @db.add_klasslike(
            scope: kl.scope,
            name: kl.name,
            type: kl.type,
            inheritance: kl.inheritance,
            nesting: kl.nesting)
        end
      end
    end
  end
end
