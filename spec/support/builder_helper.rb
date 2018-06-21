module BuilderHelper
  def build_graph(snippet)
    worklist = Orbacle::Worklist.new
    graph = Orbacle::DataFlowGraph::Graph.new
    service = Orbacle::DataFlowGraph::Builder.new(graph, worklist, Orbacle::GlobalTree.new)
    result = service.process_file(snippet, "")
    OpenStruct.new(
      graph: graph,
      final_lenv: result.context.lenv,
      final_node: result.node,
      message_sends: worklist.message_sends.to_a)
  end

  def node(type, params = {})
    Orbacle::DataFlowGraph::Node.new(type, params)
  end
end
