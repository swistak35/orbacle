require 'hash_diff'

RSpec::Matchers.define :include_edge do |expected_source, expected_target|
  match do |graph|
    graph.edges.any? do |edge|
      edge.source == expected_source && edge.target == expected_target
    end
  end

  failure_message do |graph|
    if graph.edges.empty?
      "There are no edges in this graph"
    else
      graph.edges.each_with_index.map do |edge, index|
        if edge.source.type != expected_source.type || edge.target.type != expected_target.type
          <<-EOS
          Not matching edge types
            at index: #{index}
            expected: #{expected_source.type} -> #{expected_target.type}
            actual:   #{edge.source.type} -> #{edge.target.type}
          EOS
        elsif edge.source.params != expected_source.params
          <<-EOS
          Invalid source node data
            at index: #{index}
            in node:  #{edge.source.type}
            data:     #{HashDiff.diff(expected_source.params, edge.source.params)}
            data differences in form: {:key=>[expected, actual]
          EOS
        elsif edge.target.params != expected_target.params
          <<-EOS
          Invalid target node data
            at index: #{index}
            in node:  #{edge.target.type}
            data:     #{HashDiff.diff(expected_target.params, edge.target.params)}
            data differences in form: {:key=>[expected, actual]
          EOS
        else
          raise "That should not happen"
        end
      end.join("\n")
    end
  end
end


RSpec::Matchers.define :include_node do |expected_node|
  match do |graph|
    graph.vertices.any? do |node|
      node == expected_node
    end
  end

  failure_message do |graph|
    if graph.vertices.empty?
      "There are no vertices in this graph"
    else
      graph.vertices.each_with_index.map do |node, index|
        if node.type != expected_node.type
          <<-EOS
          Not matching node types
            at index: #{index}
            expected: #{expected_node.type}
            actual:   #{node.type}
          EOS
        elsif node.params != expected_node.params
          <<-EOS
          Invalid source node data
            at index: #{index}
            in node:  #{node.type}
            data:     #{HashDiff.diff(expected_node.params, node.params)}
            data differences in form: {:key=>[expected, actual]
          EOS
        else
          raise "That should not happen"
        end
      end.join("\n")
    end
  end
end
