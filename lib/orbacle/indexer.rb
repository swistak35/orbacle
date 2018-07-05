require 'pathname'
require 'thread'

module Orbacle
  class Indexer
    QueueElement = Struct.new(:ast, :file_path)

    class ParsingProcess
      def initialize(logger, queue, files)
        @logger = logger
        @queue = queue
        @files = files
      end

      def call
        @files.each do |file_path|
          begin
            file_content = File.read(file_path)
            ast = Parser::CurrentRuby.parse(file_content)
            @queue.push(QueueElement.new(ast, file_path))
          rescue Parser::SyntaxError
            logger.warn "Warning: Skipped #{file_path} because of syntax error"
          end
        end
        @queue.close
      end

      private
      attr_reader :logger
    end

    class BuildingProcess
      def initialize(queue, builder)
        @queue = queue
        @builder = builder
      end

      def call
        while !@queue.closed? || !@queue.empty?
          element = @queue.shift
          @builder.process_file(element.ast, element.file_path)
        end
      end
    end

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

      queue = Queue.new

      logger.info "Parsing..."
      parsing_process = ParsingProcess.new(logger, queue, files)
      parsing_process.call()

      logger.info "Building graph..."
      building_process = BuildingProcess.new(queue, @parser)
      building_process.call()

      logger.info "Typing..."
      typing_result = TypingService.new(logger).(graph, worklist, tree)

      return tree, typing_result, graph
    end

    private
    attr_reader :logger
  end
end
