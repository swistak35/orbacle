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
      end
    end
  end
end
