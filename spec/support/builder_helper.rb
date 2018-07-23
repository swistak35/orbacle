# frozen_string_literal: true

module BuilderHelper
  def build_graph(file)
    worklist = Orbacle::Worklist.new
    graph = Orbacle::Graph.new
    id_generator = Orbacle::UuidIdGenerator.new
    tree = Orbacle::GlobalTree.new(id_generator)
    service = Orbacle::Builder.new(graph, worklist, tree, id_generator)
    result = service.process_file(Parser::CurrentRuby.parse(file), nil)
    OpenStruct.new(
      graph: graph,
      final_lenv: result.context.lenv,
      final_node: result.node,
      message_sends: worklist.message_sends.to_a)
  end

  def node(type, params = {})
    Orbacle::Node.new(type, params)
  end
end
