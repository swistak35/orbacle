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

      expect(result).not_to be_nil
      expect(result[:_count]).to eq(1)
      expect(result[:uri]).to eq("file://#{project.root}/some.rb")
      expect(result[:range][:start][:line]).to eq(0)
    end

    specify do
      project = TestProject.new
        .add_file(path: "bar.rb",
          content: <<-END
            module Bar
              class Foo
              end
            end
          END
        ).add_file(path: "baz.rb",
          content: <<-END
            module Baz
              class Foo
              end
            end
          END
        ).add_file(path: "some.rb",
          content: <<-END
            module Baz
              def x
                Foo
              end
            end
          END
        )
      test_indexer.(project_root: Pathname.new(project.root))

      result = call_definition.({
        textDocument: { uri: "file://#{project.root}/some.rb" },
        position: { line: 2, character: 17 },
      })

      expect(result).not_to be_nil
      expect(result[:_count]).to eq(1)
      expect(result[:uri]).to eq("file://#{project.root}/baz.rb")
      expect(result[:range][:start][:line]).to eq(1)
    end

    specify do
      project = TestProject.new
        .add_file(path: "baz.rb",
          content: <<-END
            module Baz
              class Foo
              end
            end
          END
        ).add_file(path: "bar.rb",
          content: <<-END
            class Foo
            end
          END
        ).add_file(path: "some.rb",
          content: <<-END
            module Baz
              def x
                ::Foo
              end
            end
          END
        )
      test_indexer.(project_root: Pathname.new(project.root))

      result = call_definition.({
        textDocument: { uri: "file://#{project.root}/some.rb" },
        position: { line: 2, character: 19 },
      })

      expect(result).not_to be_nil
      expect(result[:_count]).to eq(1)
      expect(result[:uri]).to eq("file://#{project.root}/bar.rb")
      expect(result[:range][:start][:line]).to eq(0)
    end

    specify do
      project = TestProject.new
        .add_file(path: "baz.rb",
                  content: "module Baz; module Bar; class Foo; end; end; end"
        ).add_file(path: "some.rb",
                   content: "module Baz; module Bar; def x; Foo; end; end; end")
      test_indexer.(project_root: Pathname.new(project.root))

      result = call_definition.({
        textDocument: { uri: "file://#{project.root}/some.rb" },
        position: { line: 0, character: 32 },
      })

      expect(result).not_to be_nil
      expect(result[:_count]).to eq(1)
      expect(result[:uri]).to eq("file://#{project.root}/baz.rb")
    end


    def test_indexer
      test_indexer = Indexer.new(db_adapter: SQLDatabaseAdapter)
    end

    def call_definition
      call_definition = CallDefinition.new(db_adapter: SQLDatabaseAdapter)
    end
  end
end
