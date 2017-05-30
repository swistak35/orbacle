require 'spec_helper'

RSpec.describe Orbacle::DefinitionProcessor do
  specify do
    file = <<END
      class Foo
        def bar
          Baz.new
        end
      end
END
    expect(definition_processor(file, 3, 9)).to be_nil
    expect(definition_processor(file, 3, 10)).to eq("Baz")
    expect(definition_processor(file, 3, 11)).to eq("Baz")
    expect(definition_processor(file, 3, 12)).to eq("Baz")
    expect(definition_processor(file, 3, 13)).to be_nil
  end

  def definition_processor(file, line, column)
    service = Orbacle::DefinitionProcessor.new
    service.process_file(file, line, column)
  end
end

