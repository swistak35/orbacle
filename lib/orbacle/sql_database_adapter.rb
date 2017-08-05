class SQLDatabaseAdapter
  def initialize(project_root:)
    @db_path = project_root.join(".orbacle.db")
    @db = SQLite3::Database.new(@db_path.to_s)
  end

  def find_constants(constants)
    db.execute("select * from constants where name = ?", constants)
  end

  private
  attr_reader :db
end
