require 'pathname'

module Orbacle
  class Indexer
    def initialize(logger)
      @logger = logger
    end

    def call(project_root:)
      project_root_path = Pathname.new(project_root)

      files = Dir.glob("#{project_root_path}/**/*.rb")
      worklist = Worklist.new
      tree = GlobalTree.new
      graph = Graph.new
      DefineBuiltins.new(graph, tree).()
      @parser = Builder.new(graph, worklist, tree)

      files.each do |file_path|
        begin
          file_content = File.read(file_path)
          logger.info "Processing #{file_path}"
          @parser.process_file(file_content, file_path)
        rescue Parser::SyntaxError
          logger.warn "Warning: Skipped #{file_path} because of syntax error"
        end
      end

      logger.info "Typing..."
      typing_result = TypingService.new(logger).(graph, worklist, tree)

      return tree, typing_result, graph
    end

    private
    attr_reader :logger
  end
end
