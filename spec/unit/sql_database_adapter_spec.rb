require 'spec_helper'

module Orbacle
  RSpec.describe SQLDatabaseAdapter do
    specify do
      db = SQLDatabaseAdapter.new(project_root: Pathname.new("/tmp"))
      db.reset

      db.create_table_metods

      db.add_metod(name: "bar", file: "foo.rb", target: "self", line: 34)
      results = db.find_metods("bar")
      expect(results.size).to eq(1)
      expect(results[0].name).to eq("bar")
      expect(results[0].file).to eq("foo.rb")
      expect(results[0].target).to eq("self")
      expect(results[0].line).to eq(34)
    end

    specify do
      db = SQLDatabaseAdapter.new(project_root: Pathname.new("/tmp"))
      db.reset

      db.create_table_klasslikes

      db.add_klasslike(scope: "Foo", name: "Bar", type: "klass", inheritance: "Baz")
      results = db.find_all_klasslikes
      expect(results.size).to eq(1)
      expect(results[0].scope).to eq("Foo")
      expect(results[0].name).to eq("Bar")
      expect(results[0].type).to eq("klass")
      expect(results[0].inheritance).to eq("Baz")
    end
  end
end
