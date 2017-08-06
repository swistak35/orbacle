require 'orbacle/parse_file_methods'
require 'sqlite3'

module Orbacle
  class Indexer
    def initialize(db_adapter:)
      @db_adapter = db_adapter
    end

    def call(project_root:)
      @db = @db_adapter.new(project_root: project_root)
      @db.reset
      @db.create_table_constants

      Dir.chdir(project_root) do
        files = Dir.glob("**/*.rb")

        files.each do |file_path|
          begin
            file_content = File.read(file_path)
            index_file(path: file_path, content: file_content)
          rescue Parser::SyntaxError
            puts "Warning: Skipped #{file_path} because of syntax error"
          end
        end
      end
    end

    def index_file(path:, content:)
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
