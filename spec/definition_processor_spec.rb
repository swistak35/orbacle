require 'spec_helper'

RSpec.describe Orbacle::DefinitionProcessor do
  specify do
    file = <<-END
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

  specify do
    file = <<-END
      class Foo
        def bar
          ::Bar::Baz.new
        end
      end
    END

    expect(definition_processor(file, 3, 11)).to be_nil
    expect(definition_processor(file, 3, 12)).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 13)).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 14)).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 15)).to be_nil
    expect(definition_processor(file, 3, 16)).to be_nil
    expect(definition_processor(file, 3, 17)).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 18)).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 19)).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 20)).to be_nil
  end

  def definition_processor(file, line, column)
    service = Orbacle::DefinitionProcessor.new
    service.process_file(file, line, column)
  end
end
