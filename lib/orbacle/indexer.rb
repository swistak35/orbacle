require 'pathname'
require 'thread'
require 'benchmark'

module Orbacle
  class Indexer
    QueueElement = Struct.new(:ast, :file_path)
    class StatsRecorder
      def initialize
        @timers = Hash.new(0.0)
        @counters = Hash.new(0)
        @values = Hash.new
      end

      def measure(timer)
        started_at = Time.now.to_f
        process_result = yield
        finished_at = Time.now.to_f
        process_result
      rescue Exception => e
        finished_at ||= Time.now.to_f
        raise
      ensure
        @timers[timer] += finished_at - started_at
      end

      def all_stats
        @timers.merge(@counters).merge(@values)
      end

      def inc(counter_key, by = 1)
        @counters[counter_key] += by
      end

      def counter(counter_key)
        @counters[counter_key]
      end

      def set_value(key, value)
        @values[key] = value
      end
    end

    class ParsingProcess
      def initialize(logger, queue, files)
        @logger = logger
        @queue = queue
        @files = files
      end

      def call
        parser = RubyParser.new
        @files.each do |file_path|
          begin
            file_content = File.read(file_path)
            ast = parser.parse(file_content)
            @queue.push(QueueElement.new(ast, file_path))
          rescue RubyParser::Error => e
            logger.warn "Warning: Skipped #{file_path} because of #{e}"
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

    def initialize(logger, stats)
      @logger = logger
      @stats = stats
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
      @stats.measure(:parsing) { parsing_process.call() }

      logger.info "Building graph..."
      building_process = BuildingProcess.new(queue, @parser)
      @stats.measure(:building) { building_process.call() }

      logger.info "Typing..."
      typing_service = TypingService.new(logger, @stats)
      typing_result = @stats.measure(:typing) { typing_service.(graph, worklist, tree) }

      @stats.set_value(:typed_nodes_all, typing_result.size)
      @stats.set_value(:typed_nodes_not_bottom, typing_result.count {|k,v| !v.bottom? })
      @stats.set_value(:typed_nodes_call_result, typing_result.count {|k,v| k.type == :call_result })
      @stats.set_value(:typed_nodes_call_result_not_bottom, typing_result.count {|k,v| k.type == :call_result && !v.bottom? })

      return tree, typing_result, graph
    end

    private
    attr_reader :logger
  end
end
