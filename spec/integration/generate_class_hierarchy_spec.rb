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

      expect(ch.content).to eq(GenerateClassHierarchy::KlassNode.new("Object", false, nil))

      expect(ch.children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("Bar", true, "Object"))
      expect(ch.children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("::Foo::Bar", true, "Object"))
      expect(ch.children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("Something::NotHere", false, "Object"))
      expect(ch.children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("Something::NotThere", false, "Object"))

      expect(ch["Something::NotHere"].children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("FooBase", true, "Something::NotHere"))
      expect(ch["Something::NotThere"].children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("MooBase", true, "Something::NotThere"))

      expect(ch["Something::NotHere"]["FooBase"].children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("Foo", true, "FooBase"))
      expect(ch["Bar"].children.map(&:content)).to include(
        GenerateClassHierarchy::KlassNode.new("::Foo::Baz", true, "Bar"))
    end

    def test_indexer
      test_indexer = Indexer.new(db_adapter: SQLDatabaseAdapter)
    end
  end
end
