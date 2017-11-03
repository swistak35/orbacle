require 'yaml'

class SQLDatabaseAdapter
  Metod = Struct.new(:name, :file, :target, :line)
  Klasslike = Struct.new(:scope, :name, :type, :inheritance, :nesting)

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

  def find_all_klasslikes
    db.execute("select * from klasslikes").map do |klasslike_data|
      Klasslike.new(
        klasslike_data[0],
        klasslike_data[1],
        klasslike_data[2],
        klasslike_data[3],
        YAML.load(klasslike_data[4]))
    end
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

  def create_table_metods
    db.execute <<-SQL
      create table metods (
        name varchar(255),
        file varchar(255),
        target varchar(255),
        line int
      );
    SQL
  end

  def create_table_klasslikes
    db.execute <<-SQL
      create table klasslikes (
        scope varchar(255),
        name varchar(255),
        type varchar(255),
        inheritance varchar(255),
        nesting text
      );
    SQL
  end

  def find_metods(name)
    db.execute("select * from metods where name = ?", name).map do |metod_data|
      Metod.new(*metod_data)
    end
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

  def add_metod(name:, file:, target:, line:)
    @db.execute("insert into metods values (?, ?, ?, ?)", [
      name,
      file,
      target,
      line,
    ])
  end

  def add_klasslike(scope:, name:, type:, inheritance:, nesting:)
    @db.execute("insert into klasslikes values (?, ?, ?, ?, ?)", [
      scope,
      name,
      type.to_s,
      inheritance,
      YAML.dump(nesting),
    ])
  end

  private
  attr_reader :db
end
