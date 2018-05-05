module Orbacle
  class Indexer
    def call(project_root:)
      project_root_path = Pathname.new(project_root)

      files = Dir.glob("#{project_root_path}/**/*.rb")
      worklist = Worklist.new
      tree = GlobalTree.new
      graph = DataFlowGraph::Graph.new
      DataFlowGraph::DefineBuiltins.new(graph, tree).()
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
      typing_result = TypingService.new.(graph, worklist, tree)

      return tree, typing_result, graph
    end
  end
end
