# frozen_string_literal: true

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

    class ReadingProcess
      def initialize(logger, queue, files)
        @logger = logger
        @queue = queue
        @files = files
      end

      def call
        @files.each do |file_path|
          file_content = File.read(file_path)
          @queue.push(QueueElement.new(file_content, file_path))
        end
        @queue.close
      end

      private
      attr_reader :logger
    end

    class ParsingProcess
      def initialize(logger, queue_contents, queue_asts)
        @logger = logger
        @queue_contents = queue_contents
        @queue_asts = queue_asts
      end

      def call
        parser = RubyParser.new
        while !@queue_contents.closed? || !@queue_contents.empty?
          element = @queue_contents.shift
          begin
            ast = parser.parse(element.ast)
            @queue_asts.push(QueueElement.new(ast, element.file_path))
          rescue RubyParser::Error => e
            logger.warn "Warning: Skipped #{element.file_path} because of #{e}"
          end
        end
        @queue_asts.close
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
      id_generator = IntegerIdGenerator.new
      worklist = Worklist.new
      state = GlobalTree.new(id_generator)
      graph = Graph.new
      DefineBuiltins.new(graph, state, id_generator).()
      @parser = Builder.new(graph, worklist, state, id_generator)

      queue_contents = Queue.new
      queue_asts = Queue.new

      logger.info "Reading..."
      reading_process = ReadingProcess.new(logger, queue_contents, files)
      @stats.measure(:reading) { reading_process.call() }

      logger.info "Parsing..."
      parsing_process = ParsingProcess.new(logger, queue_contents, queue_asts)
      @stats.measure(:parsing) { parsing_process.call() }

      logger.info "Building graph..."
      building_process = BuildingProcess.new(queue_asts, @parser)
      @stats.measure(:building) { building_process.call() }

      logger.info "Typing..."
      typing_service = TypingService.new(logger, @stats)
      @stats.measure(:typing) { typing_service.(graph, worklist, state) }

      type_mapping = state.instance_variable_get(:@type_mapping)
      @stats.set_value(:typed_nodes_all, type_mapping.size)
      @stats.set_value(:typed_nodes_not_bottom, type_mapping.count {|k,v| !v.bottom? })
      @stats.set_value(:typed_nodes_call_result, type_mapping.count {|k,v| k.type == :call_result })
      @stats.set_value(:typed_nodes_call_result_not_bottom, type_mapping.count {|k,v| k.type == :call_result && !v.bottom? })

      return state, graph, worklist
    end

    private
    attr_reader :logger
  end
end
