require 'optparse'
require 'pathname'
require 'logger'
require 'fileutils'
require 'orbacle'
require 'lsp'
require 'json'

module Orbacle
  class CommandLineInterface
    class Options
      def initialize
        @dir = Dir.pwd
        @stats_file = Pathname.new(Dir.pwd).join("stats.json")
      end
      attr_reader :dir, :stats_file

      def define_options(parser)
        parser.banner = 'Usage: ./orbacle [options]'

        parser.on('-d DIR', '--dir', 'Directory in which project resides') do |dir|
          @dir = dir
        end

        parser.on("-h", "--help", "Prints this help") do
          puts parser
          exit
        end
      end
    end

    def call(args)
      options = Options.new
      OptionParser.new do |parser|
        options.define_options(parser)
      end.parse!(args)
      call_command(args[0], options)
    end

    def call_command(command, options)
      case command
      when 'index' then index(options)
      when 'file-server' then file_server(options)
      when 'generate-datajs' then generate_datajs(options)
      else no_command
      end
    end

    private

    def index(options)
      logger = Logger.new(STDOUT)
      project_root = options.dir

      engine = Engine.new(logger)
      engine.index(project_root)
    ensure
      File.open(options.stats_file, "w") {|f| f.write(engine.stats_recorder.all_stats.to_json) }
    end

    def file_server(options)
      logger = Logger.new('/tmp/orbacle.log', 'monthly')
      logger.level = Logger::INFO

      lang_server = LangServer.new(logger)
      server = Lsp::FileLanguageServer.new(lang_server, logger: logger)
      server.start
    end

    def generate_datajs(options)
      logger = Logger.new(STDOUT)

      require 'base64'
      project_root = options.dir
      engine = Engine.new(logger)
      tree, typing_result, graph = engine.index(project_root)

      nodes = graph.vertices
      filepaths = nodes.map {|n| n.location&.uri }.compact.uniq
      type_pretty_printer = TypePrettyPrinter.new

      File.open("data.js", "w") do |f|
        f.puts "window.orbacleFiles = ["
        filepaths.each do |filepath|
          f.puts "  ['#{filepath[project_root.to_s.size..-1]}', `#{Base64.encode64(File.read(filepath))}`],"
        end
        f.puts "];"
        f.puts "window.orbacleNodes = ["
        sorted_nodes = nodes.reject {|n| n.location&.uri.nil? }
        sorted_nodes.each do |node|
          filepath = node.location.uri[project_root.to_s.size..-1]
          pretty_type = type_pretty_printer.(typing_result[node])
          f.puts "['#{node.type}', '#{pretty_type}', '#{filepath}', #{node.location&.start&.line&.to_i}, #{node.location&.start&.character&.to_i}, #{node.location&.end&.line&.to_i}, #{node.location&.end&.character&.to_i}],"
        end
        f.puts "];"
      end
    end

    def no_command
      puts "No command given."
      exit
    end
  end
end
