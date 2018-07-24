# frozen_string_literal: true

require 'support/test_project'
require 'logger'

module Orbacle
  RSpec.describe Engine do
    let(:logger) { Logger.new(nil) }

    describe "#get_type_information" do
      specify do
        file1 = <<-END
foo = 42
foo
foo
END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)
        result = engine.get_type_information(proj.path_of("file1.rb"), Position.new(2, 2))

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

    describe "#get_type_of_caller_from_message_send" do
      specify do
        file1 = <<-END
        foo = Foo.new
        foo.bar
        END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)
        result = engine.get_type_of_caller_from_message_send(proj.path_of("file1.rb"), PositionRange.new(Position.new(1, 12), Position.new(1, 14)))
        expect(result).to eq(NominalType.new("Foo"))
      end
    end
  end
end
