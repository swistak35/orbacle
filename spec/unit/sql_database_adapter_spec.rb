require 'spec_helper'

module Orbacle
  RSpec.describe SQLDatabaseAdapter do
    specify do
      db = SQLDatabaseAdapter.new(project_root: Pathname.new("/tmp"))
      db.reset

      db.create_table_metods

      db.add_metod(name: "bar", file: "foo.rb", line: 34)
      results = db.find_metods("bar")
      expect(results.size).to eq(1)
      expect(results[0].name).to eq("bar")
      expect(results[0].file).to eq("foo.rb")
      expect(results[0].line).to eq(34)
    end
  end
end
