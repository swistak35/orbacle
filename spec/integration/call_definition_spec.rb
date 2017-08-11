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
          END
        ).add_file(path: "some.rb",
          content: <<-END
            class Some
            end
          END
        )
      test_indexer.(project_root: Pathname.new(project.root))

      result = call_definition.({
        textDocument: { uri: "file://#{project.root}/bar.rb" },
        position: { line: 2, character: 18 },
      })

      expect(result[:uri]).to eq("file://#{project.root}/some.rb")
      expect(result[:range][:start][:line]).to eq(0)
    end

    def test_indexer
      test_indexer = Indexer.new(db_adapter: SQLDatabaseAdapter)
    end

    def call_definition
      call_definition = CallDefinition.new(db_adapter: SQLDatabaseAdapter)
    end
  end
end
