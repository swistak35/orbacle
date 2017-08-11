class SQLDatabaseAdapter
  def initialize(project_root:)
    @db_path = project_root.join(".orbacle.db")
    @db = SQLite3::Database.new(@db_path.to_s)
  end

  def reset
    File.delete(@db_path) if File.exists?(@db_path)
    @db = SQLite3::Database.new(@db_path.to_s)
  end

  def find_constants(name, possible_scopes)
    db.execute("select * from constants where name = ? AND scope IN (#{possible_scopes.map(&:inspect).join(", ")})", name)
  end

  def create_table_constants
    db.execute <<-SQL
      create table constants (
        scope varchar(255),
        name varchar(255),
        type varchar(255),
        file varchar(255),
        line int
      );
    SQL
  end

  def add_constant(scope:, name:, type:, path:, line:)
    @db.execute("insert into constants values (?, ?, ?, ?, ?)", [
      scope.to_s,
      name,
      type,
      path,
      line,
    ])
  end

  private
  attr_reader :db
end
