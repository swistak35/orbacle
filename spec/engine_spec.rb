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
END
        proj = TestProject.new.add_file("file1.rb", file1)

        engine = Engine.new(logger)
        engine.index(proj.root)
        result = engine.get_type_information(proj.path_of("file1.rb"), 2, 2)

        expect(result).to eq("Integer")
      end
    end
  end
end
