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
      worklist = Worklist.new
      tree = GlobalTree.new
      graph = DataFlowGraph::Graph.new
      @parser = DataFlowGraph::Builder.new(graph, worklist, tree)

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
      typing_result = TypingService.new.(@parser.result.graph, worklist, tree)

      puts "Saving..."
      store_result(@parser.result, tree, typing_result)
    end

    def store_result(result, tree, typing_result)
      puts "Saving constants..."
      tree.constants.each do |c|
        @db.add_constant(
          scope: c.scope.absolute_str,
          name: c.name,
          type: type_of(c),
          path: c.location&.uri,
          line: c.location&.position_range&.start&.line)
      end
      puts "Saving methods..."
      tree.metods.each do |m|
        @db.add_metod(
          name: m.name,
          file: m.location&.uri,
          line: m.location&.position_range&.start&.line)
      end
      puts "Saving klasslikes..."
      klasslikes = tree.constants.select {|c| [GlobalTree::Klass, GlobalTree::Mod].include?(c.class)}
      klasslikes.each do |kl|
        @db.add_klasslike(
          scope: kl.scope.absolute_str,
          name: kl.name,
          type: type_of(kl),
          inheritance: type_of(kl) == "klass" ? kl.parent_ref&.full_name : nil,
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
