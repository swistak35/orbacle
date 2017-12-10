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

    expect(definition_processor(file, 3, 9)[0]).to be_nil
    expect(definition_processor(file, 3, 10)[0]).to eq("Baz")
    expect(definition_processor(file, 3, 11)[0]).to eq("Baz")
    expect(definition_processor(file, 3, 12)[0]).to eq("Baz")
    expect(definition_processor(file, 3, 13)[0]).to be_nil
  end

  specify do
    file = <<-END
      class Foo
        def bar
          ::Bar::Baz.new
        end
      end
    END

    expect(definition_processor(file, 3, 11)[0]).to be_nil
    expect(definition_processor(file, 3, 12)[0]).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 13)[0]).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 14)[0]).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 15)[0]).to be_nil
    expect(definition_processor(file, 3, 16)[0]).to be_nil
    expect(definition_processor(file, 3, 17)[0]).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 18)[0]).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 19)[0]).to eq("::Bar::Baz")
    expect(definition_processor(file, 3, 20)[0]).to be_nil
  end

  specify do
    file = <<-END
      class Foo
        def bar
          Baz.new
        end
      end
    END

    expected_nesting = [[[], "Foo"]]

    expect(definition_processor(file, 3, 11)[1]).to eq(expected_nesting)
    expect(definition_processor(file, 3, 11)[2]).to eq("constant")
  end

  specify do
    file = <<-END
      class Foo
        def bar
          Baz.new
        end
      end
    END

    expect(definition_processor(file, 3, 13)[0]).to be_nil
    expect(definition_processor(file, 3, 14)[0]).to eq("new")
    expect(definition_processor(file, 3, 15)[0]).to eq("new")
    expect(definition_processor(file, 3, 16)[0]).to eq("new")
    expect(definition_processor(file, 3, 17)[0]).to be_nil

    expect(definition_processor(file, 3, 14)[2]).to eq("send")
  end

  def definition_processor(file, line, column)
    service = Orbacle::DefinitionProcessor.new
    service.process_file(file, line, column)
  end
end
