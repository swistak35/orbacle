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

    def no_command
      puts "No command given."
      exit
    end
  end
end
