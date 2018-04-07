require 'pathname'
require 'logger'
require 'fileutils'

module Orbacle
  class CommandLineInterface
    def call(command, options)
      case ARGV[0]
      when 'init' then init(options)
      when 'index' then index(options)
      when 'file-server' then file_server(options)
      when 'generate-class-hierarchy' then generate_class_hierarchy(options)
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
      project_root = options.fetch(:dir, Dir.pwd)
      indexer = Orbacle::Indexer.new(db_adapter: SQLDatabaseAdapter)
      indexer.(project_root: project_root)
    end

    def file_server(options)
      logger = Logger.new('/tmp/orbacle.log', 'monthly')
      logger.level = Logger::INFO
      lang_server = Orbacle::LangServer.new(
        db_adapter: SQLDatabaseAdapter,
        logger: logger)
      file_server = Orbacle::LangFileServer.new(
        lang_server: lang_server,
        logger: logger)
      file_server.start
    end

    def generate_class_hierarchy(options)
      puts "Generating class hierarchy"
      project_root = Pathname.new(options.fetch(:dir, Dir.pwd))
      db = SQLDatabaseAdapter.new(project_root: project_root)
      Orbacle::GenerateClassHierarchy.new(db).()
    end

    def generate_datajs(options)
      require 'base64'
      project_root = Pathname.new(options.fetch(:dir, Dir.pwd))
      db = SQLDatabaseAdapter.new(project_root: project_root)
      nodes = db.find_all_nodes
      filepaths = nodes.map(&:location_uri).compact.uniq

      File.open("data.js", "w") do |f|
        f.puts "window.orbacleFiles = ["
        filepaths.each do |filepath|
          f.puts "  ['#{filepath[project_root.to_s.size..-1]}', `#{Base64.encode64(File.read(filepath))}`],"
        end
        f.puts "];"
        f.puts "window.orbacleNodes = ["
        sorted_nodes = nodes.reject {|n| n.location_uri.nil? }
        sorted_nodes.each do |node|
          filepath = node.location_uri[project_root.to_s.size..-1]
          f.puts "['#{node.kind}', '#{node.type}', '#{filepath}', #{node.location_start_line.to_i}, #{node.location_start_char.to_i}, #{node.location_end_line.to_i}, #{node.location_end_char.to_i}],"
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
