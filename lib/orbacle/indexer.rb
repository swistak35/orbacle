require 'orbacle/parse_file_methods'
require 'sqlite3'

module Orbacle
  class Indexer
    def index(dir:)
      Dir.chdir(dir)

      File.delete(".orbacle.db") if File.exists?(".orbacle.db")
      db = SQLite3::Database.new(".orbacle.db")
      create_table_constants(db)

      files  = Dir.glob('**/*.rb')

      parser = ParseFileMethods.new

      files.each do |input_file|
        begin
          # puts "Processing #{input_file}"
          result = parser.process_file(File.read(input_file))
          result[:constants].each do |c|
            scope, name, type, opts = c

            db.execute("insert into constants values (?, ?, ?, ?, ?)", [
              scope,
              name,
              type.to_s,
              input_file,
              opts.fetch(:line)
            ])
          end
        rescue Parser::SyntaxError
          puts "Warning: Skipped #{input_file} because of syntax error"
        end
      end
    end

    def create_table_constants(db)
      db.execute <<-SQL
        create table constants (
          scope varchar(255),
          name varchar(255),
          type varchar(255),
          file varchar(255),
          line int
        );
      SQL
    end
  end
end
