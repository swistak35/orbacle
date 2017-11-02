module Orbacle
  class Indexer
    class IndexFile
      def initialize(db:)
        @db = db
      end

      def call(path:, content:)
        parser = ParseFileMethods.new
        result = parser.process_file(content)
        result[:constants].each do |c|
          scope, name, type, opts = c

          @db.add_constant(
            scope: scope,
            name: name,
            type: type.to_s,
            path: path,
            line: opts.fetch(:line))
        end
        result[:methods].each do |m|
          _scope, name, opts = m

          @db.add_metod(
            name: name,
            file: path,
            target: opts.fetch(:target).to_s,
            line: opts.fetch(:line))
        end
        result[:klasslikes].each do |kl|
          @db.add_klasslike(
            scope: kl.scope,
            name: kl.name,
            type: kl.type,
            inheritance: kl.inheritance)
        end
      end
    end
  end
end
