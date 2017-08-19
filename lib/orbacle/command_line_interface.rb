require 'pathname'
require 'logger'

module Orbacle
  class CommandLineInterface
    def call(command, options)
      case ARGV[0]
      when 'index' then index(options)
      when 'file-server' then file_server(options)
      end
    end

    private

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
  end
end
