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
      @db.create_table_nodes

      files = Dir.glob("#{project_root_path}/**/*.rb")
      @parser = DataFlowGraph.new

      files.each do |file_path|
        begin
          file_content = File.read(file_path)
          puts "Processing #{file_path}"
          @parser.process_file(file_content, file_path)
        rescue Parser::SyntaxError
          puts "Warning: Skipped #{file_path} because of syntax error"
        end
      end

      puts "Typing..."
      typing_result = TypingService.new.(@parser.result.graph, @parser.result.message_sends, @parser.result.tree)

      puts "Saving..."
      store_result(@parser.result, typing_result)
    end

    def store_result(result, typing_result)
      puts "Saving constants..."
      result.tree.constants.each do |c|
        @db.add_constant(
          scope: c.scope.absolute_str,
          name: c.name,
          type: type_of(c),
          path: c.position.uri,
          line: c.position.position_range.start.line)
      end
      puts "Saving methods..."
      result.tree.metods.each do |m|
        @db.add_metod(
          name: m.name,
          file: m.position&.uri,
          line: m.position&.position_range&.start&.line)
      end
      puts "Saving klasslikes..."
      klasslikes = result.tree.constants.select {|c| [GlobalTree::Klass, GlobalTree::Mod].include?(c.class)}
      klasslikes.each do |kl|
        @db.add_klasslike(
          scope: kl.scope.absolute_str,
          name: kl.name,
          type: type_of(kl),
          inheritance: type_of(kl) == "klass" ? kl.inheritance_ref&.full_name : nil,
          nesting: nil)
      end
      puts "Saving typings..."
      @db.bulk_add_nodes(typing_result)
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
