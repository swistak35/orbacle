class SQLDatabaseAdapter
  def initialize(db:)
    @db = db
  end

  def self.open_for_file(fileuri)
    project_path, db_path = find_closest_db(fileuri)
    db = SQLite3::Database.new(db_path.to_s)
    new(db: db)
  end

  def self.find_closest_db(fileuri)
    dirpath = Pathname(URI(fileuri).path)
    while !dirpath.root?
      dirpath = dirpath.split[0]
      db_path = dirpath.join(".orbacle.db")
      return [dirpath, db_path] if File.exists?(db_path)
    end
    return nil
  end

  def find_constants(constants)
    db.execute("select * from constants where name = ?", constants)
  end

  private
  attr_reader :db
end
