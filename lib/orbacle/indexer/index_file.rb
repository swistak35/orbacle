module Orbacle
  class Indexer
    class IndexFile
      def initialize(db:)
        @db = db
      end

      def call(path:, content:)
        parser = ControlFlowGraph.new
        result = parser.process_file(content)
        result.constants.each do |c|
          @db.add_constant(
            scope: c.scope,
            name: c.name,
            type: type_of(c),
            path: path,
            line: c.line)
        end
        result.methods.each do |m|
          _scope, name, opts = m

          @db.add_metod(
            name: name,
            file: path,
            line: opts.fetch(:line))
        end
        result.constants.select {|c| [GlobalTree::Klass, GlobalTree::Mod].include?(c.class)}.each do |kl|
          @db.add_klasslike(
            scope: kl.scope,
            name: kl.name,
            type: type_of(kl),
            inheritance: type_of(kl) == "klass" ? kl.inheritance_name : nil,
            nesting: type_of(kl) == "klass" ? kl.inheritance_nesting : nil)
        end
      end

      def type_of(c)
        case c
        when GlobalTree::Klass then "klass"
        when GlobalTree::Mod then "mod"
        when GlobalTree::Constant then "other"
        end
      end
    end
  end
end
