require 'spec_helper'
require 'support/test_project'

module Orbacle
  RSpec.describe CallDefinition do
    specify do
      project = TestProject.new
        .add_file(path: "bar.rb",
          content: <<-END
            class Bar
              def foo
                Some.new
              end
            end

            class FooBase < Something::NotHere
            end

            class MooBase < ::Something::NotThere
            end

            class Foo < FooBase
              class Bar
              end

              class Baz < ::Bar
              end
            end
          END
        )
      test_indexer.(project_root: Pathname.new(project.root))

      db = SQLDatabaseAdapter.new(project_root: Pathname.new(project.root))
      ch = GenerateClassHierarchy.new(db).()

      expect(ch).to include({
        scope: nil,
        name: "Bar",
        inheritance: nil,
        nesting: [],
        real_inheritance: "Object",
      })
      expect(ch).to include({
        scope: "Foo",
        name: "Baz",
        inheritance: "::Bar",
        nesting: [[:klass, [], "Foo"]],
        real_inheritance: "Bar"
      })
      expect(ch).to include({
        scope: nil,
        name: "Foo",
        inheritance: "FooBase",
        nesting: [],
        real_inheritance: "FooBase"
      })
      expect(ch).to include({
        scope: nil,
        name: "FooBase",
        inheritance: "Something::NotHere",
        nesting: [],
        real_inheritance: "Something::NotHere",
        inheritance_faked: true,
      })
      expect(ch).to include({
        scope: nil,
        name: "MooBase",
        inheritance: "::Something::NotThere",
        nesting: [],
        real_inheritance: "Something::NotThere",
        inheritance_faked: true,
      })
    end

    def test_indexer
      test_indexer = Indexer.new(db_adapter: SQLDatabaseAdapter)
    end
  end
end
