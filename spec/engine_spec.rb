# frozen_string_literal: true

require 'support/test_project'
require 'logger'

module Orbacle
  RSpec.describe Engine do
    let(:logger) { Logger.new(nil) }

    describe "#get_type_information" do
      specify do
        file1 = <<-END
        foo = x("bar")
        something(foo)
        END
        file2 = <<-END
        foo = 42
        something(foo)
        END
        proj = TestProject.new
          .add_file("file1.rb", file1)
          .add_file("file2.rb", file2)

        expect(Dir).to receive(:glob).and_return([proj.path_of("file1.rb"), proj.path_of("file2.rb")])
        engine = Engine.new(logger)
        engine.index(proj.root)

        result = engine.get_type_information(proj.path_of("file1.rb"), Position.new(0, 19))
        expect(result).to eq("String")

        result = engine.get_type_information(proj.path_of("file2.rb"), Position.new(1, 20))
        expect(result).to eq("Integer")
      end

      specify "engine understands line and col 0-based indexing" do
        proj = TestProject.new
          .add_file("file1.rb", "1")
          .add_file("file2.rb", "2 \n2 ")
          .add_file("file3.rb", "33\n  ")

        engine = Engine.new(logger)
        engine.index(proj.root)
        expect(engine.get_type_information(proj.path_of("file1.rb"), Position.new(0, 0))).to eq("Integer")
        expect(engine.get_type_information(proj.path_of("file2.rb"), Position.new(1, 1))).to eq("unknown")
        expect(engine.get_type_information(proj.path_of("file3.rb"), Position.new(1, 1))).to eq("unknown")
      end
    end

    describe "#locations_for_definition_under_position" do
      specify "constant result" do
        file1 = <<-END
        class Foo
        end
        Foo
        END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)
        locations = engine.locations_for_definition_under_position(proj.path_of("file1.rb"), file1, Position.new(2, 10))
        expect(locations[0].position_range).to eq(PositionRange.new(Position.new(0, 8), Position.new(1, 10)))
      end

      specify "method result" do
        file1 = <<-END
        42
        42
        42
        42
        y,z = a
        x.bar
        END
        file2 = <<-END
        class Foo
          def bar
          end
        end
        x = Foo.new
        x.bar
        END
        proj = TestProject.new
          .add_file("file1.rb", file1)
          .add_file("file2.rb", file2)

        expect(Dir).to receive(:glob).and_return([proj.path_of("file1.rb"), proj.path_of("file2.rb")])
        engine = Engine.new(logger)
        engine.index(proj.root)

        locations = engine.locations_for_definition_under_position(proj.path_of("file2.rb"), file2, Position.new(5, 12))
        expect(locations[0].position_range).to eq(PositionRange.new(Position.new(1, 10), Position.new(2, 12)))
      end

      specify "method result - class method" do
        file1 = <<-END
        class Foo
          def self.bar
          end
        end
        Foo.bar
        END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)

        locations = engine.locations_for_definition_under_position(proj.path_of("file1.rb"), file1, Position.new(4, 14))
        expect(locations[0].position_range).to eq(PositionRange.new(Position.new(1, 10), Position.new(2, 12)))
      end

      specify "method result - on union type" do
        file1 = <<-END
        class Foo1
          def bar
          end
        end
        class Foo2
          def bar
          end
        end
        x = something ? Foo1.new : Foo2.new
        x.bar
        END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)

        locations = engine.locations_for_definition_under_position(proj.path_of("file1.rb"), file1, Position.new(9, 12))
        expect(locations[0].position_range).to eq(PositionRange.new(Position.new(1, 10), Position.new(2, 12)))
        expect(locations[1].position_range).to eq(PositionRange.new(Position.new(5, 10), Position.new(6, 12)))
      end

      specify "method result - on unknown type" do
        file1 = <<-END
        x.bar
        END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)

        locations = engine.locations_for_definition_under_position(proj.path_of("file1.rb"), file1, Position.new(0, 12))
        expect(locations).to eq([])
      end

      specify "method result without location" do
        file1 = <<-END
        x = Object.new
        x.object_id
        END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)

        locations = engine.locations_for_definition_under_position(proj.path_of("file1.rb"), file1, Position.new(1, 12))
        expect(locations).to eq([])
      end

      specify "no result" do
        file1 = <<-END
        42
        END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)

        locations = engine.locations_for_definition_under_position(proj.path_of("file1.rb"), file1, Position.new(0, 10))
        expect(locations).to eq([])
      end
    end
  end
end
