function cytoscape_context_menu(tool){
  tool.cytoscape_tool('add_context_menu_item', "Select first neighbors", "nodes", function (evt) {
    var vis = tool.cytoscape_tool('vis');
    var rootNode = evt.target;
    var fNeighbors = vis.firstNeighbors([rootNode]);
    var neighborNodes = fNeighbors.neighbors;
    vis.select([rootNode]).select(neighborNodes);
  });

  tool.cytoscape_tool('add_context_menu_item', "Remove", "nodes", function (evt) {
    var vis = tool.cytoscape_tool('vis');
    var node = evt.target;
    tool.cytoscape_tool('remove_entities', node.data.entity_type, [node.data.id])
    tool.cytoscape_tool('draw');
  });

  tool.cytoscape_tool('add_context_menu_item', "Remove selected", "none", function (evt) {
    var vis = tool.cytoscape_tool('vis');
    var removed_nodes = vis.selected('nodes')
    $.map(removed_nodes, function(node){
      tool.cytoscape_tool('remove_entities', node.data.entity_type, [node.data.id])
    })
    tool.cytoscape_tool('draw');
  });
}
