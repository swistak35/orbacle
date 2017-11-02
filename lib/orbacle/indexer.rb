require 'orbacle/parse_file_methods'
require 'sqlite3'

module Orbacle
  class Indexer
    def initialize(db_adapter:)
      @db_adapter = db_adapter
    end

    def call(project_root:)
      project_root_path = Pathname.new(project_root)

      @db = @db_adapter.new(project_root: project_root_path)
      @db.reset
      @db.create_table_constants
      @db.create_table_metods
      @db.create_table_klasslikes

      files = Dir.glob("#{project_root_path}/**/*.rb")

      files.each do |file_path|
        begin
          file_content = File.read(file_path)
          index_file.(path: file_path, content: file_content)
        rescue Parser::SyntaxError
          puts "Warning: Skipped #{file_path} because of syntax error"
        end
      end
    end

    def index_file
      @index_file ||= IndexFile.new(db: @db)
    end
  end
end
