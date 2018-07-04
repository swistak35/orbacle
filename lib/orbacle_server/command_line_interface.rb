require 'pathname'
require 'logger'
require 'fileutils'
require 'orbacle'
require 'lsp'

module OrbacleServer
  class CommandLineInterface
    def call(command, options)
      case ARGV[0]
      when 'init' then init(options)
      when 'index' then index(options)
      when 'file-server' then file_server(options)
      when 'generate-datajs' then generate_datajs(options)
      else no_command
      end
    end

    private

    def init(options)
      project_root = Pathname.new(options.fetch(:dir, Dir.pwd))
      FileUtils.touch(project_root.join(".orbaclerc"))
      puts "Orbacle config initialized at #{project_root}"
    end

    def index(options)
      logger = Logger.new(STDOUT)
      project_root = options.fetch(:dir, Dir.pwd)

      engine = Orbacle::Engine.new(logger)
      engine.index(project_root)
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
      project_root = options.fetch(:dir, Dir.pwd)
      engine = Orbacle::Engine.new(logger)
      tree, typing_result, graph = engine.index(project_root)

      nodes = graph.vertices
      filepaths = nodes.map {|n| n.location&.uri }.compact.uniq
      type_pretty_printer = Orbacle::TypePrettyPrinter.new

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

