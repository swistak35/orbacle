module Orbacle
  class Indexer
    class IndexFile
      def initialize(db:)
        @db = db
      end

      def call(path:, content:)
        parser = DataFlowGraph.new
        result = parser.process_file(content)
        result.tree.constants.each do |c|
          @db.add_constant(
            scope: c.scope.absolute_str,
            name: c.name,
            type: type_of(c),
            path: path,
            line: c.line)
        end
        result.tree.metods.each do |m|
          @db.add_metod(
            name: m.name,
            file: path,
            line: m.line)
        end
        klasslikes = result.tree.constants.select {|c| [GlobalTree::Klass, GlobalTree::Mod].include?(c.class)}
        klasslikes.each do |kl|
          @db.add_klasslike(
            scope: kl.scope.absolute_str,
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
