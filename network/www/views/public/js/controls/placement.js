function cytoscape_fix_positions(tool){
  var vis = tool.cytoscape_tool('vis');
  var all_nodes = vis.nodes();
  var zoom = vis.zoom();
  var points = {}
  $.each(all_nodes, function(){
    var node = this;
    points[node.data.id]= {id:node.data.id, x: node.x / zoom, y: node.y / zoom};
  })
  tool.cytoscape_tool('set_points', points)
}

function cytoscape_pull_first(tool, rootNode, dist){
  var vis = tool.cytoscape_tool('vis');
  var all_nodes = vis.nodes();
  var zoom = vis.zoom();

  if (undefined === dist){
    dist = 100
  }

  var points = tool.cytoscape_tool('get_options').points
  if (undefined === points){ points = {}}

  var root_x;
  var root_y;
  if (undefined === points[rootNode.data.id]){
    root_x = rootNode.x / zoom;
    root_y = rootNode.y / zoom;
  }else{
    root_x = points[rootNode.data.id].x;
    root_y = points[rootNode.data.id].y;
  }

  var fNeighbors = vis.firstNeighbors([rootNode]);
  var neighborNodes = fNeighbors.neighbors;
  var neighborNode_ids = $.map(neighborNodes, function(node){return(node.data.id)})

  $.each(all_nodes, function(){
    var node = this
    if (undefined === points[node.data.id]){
      var node_x = node.x / zoom;
      var node_y = node.y / zoom;
    }else{
      var node_x = points[node.data.id].x;
      var node_y = points[node.data.id].y;
    }

    if ($.inArray(node.data.id, neighborNode_ids) >= 0){
      var dist_x = node_x - root_x;
      var dist_y = node_y - root_y;
      var length = Math.sqrt(Math.pow(dist_x,2) + Math.pow(dist_y, 2));
      node_x = root_x + (dist_x / length * ((dist + Math.random() * dist)));
      node_y = root_y + (dist_y / length * ((dist + Math.random() * dist)));
    }

    points[node.data.id] = ({id:node.data.id, x: node_x, y: node_y});
  })

  points[rootNode.data.id] = ({id:rootNode.data.id, x: root_x, y: root_y});

  return points;
}

function cytoscape_surround_first(tool, rootNode, dist){
  var vis = tool.cytoscape_tool('vis');
  var all_nodes = vis.nodes();
  var zoom = vis.zoom();


  if (undefined === dist){
    dist = 20
  }

  var points = tool.cytoscape_tool('get_options').points
  if (undefined === points){ points = {}}

  var root_x;
  var root_y;
  if (undefined === points[rootNode.data.id]){
    root_x = rootNode.x / zoom;
    root_y = rootNode.y / zoom;
  }else{
    root_x = points[rootNode.data.id].x;
    root_y = points[rootNode.data.id].y;
  }

 
  var fNeighbors = vis.firstNeighbors([rootNode]);
  var neighborNodes = fNeighbors.neighbors;
  var neighborNode_ids = $.map(neighborNodes, function(node){return(node.data.id)})

  var ang = 0
  var num = 0
  var circum = 0
  $.each(all_nodes, function(){
    var node = this
    if ($.inArray(node.data.id, neighborNode_ids) >= 0){
      num += 1;
      if (undefined !== node.data.size){
        circum += tool.cytoscape_tool('get_options').visualStyle.nodes.size.defaultValue + 5;
      }else{
        circum += parseInt(node.data.size) + 5;
      }
    }
  })

  dist += circum / (2 * Math.PI)

  if (dist < 50){ dist = 50}

  var ang_inc = 1.0 / num
  $.each(all_nodes, function(){
    var node = this

    if (undefined === points[node.data.id]){
      var node_x = node.x / zoom;
      var node_y = node.y / zoom;
    }else{
      var node_x = points[node.data.id].x;
      var node_y = points[node.data.id].y;
    }

    if ($.inArray(node.data.id, neighborNode_ids) >= 0){
      ang = ang + ang_inc
      var node_x = root_x + (dist * Math.sin(ang * 2 * Math.PI))
      var node_y = root_y + (dist * Math.cos(ang * 2 * Math.PI))
    }
    points[node.data.id] = {id:node.data.id, x: node_x, y: node_y}
  })

  points[rootNode.data.id] = ({id:rootNode.data.id, x: root_x, y: root_y});
  return points;
}
function cytoscape_placement(tool){

  tool.cytoscape_tool('add_context_menu_item', "Fix positions", "none", function (evt) {
    cytoscape_fix_positions(tool)
    tool.cytoscape_tool('draw')
  });

  tool.cytoscape_tool('add_context_menu_item', "Clear positions", "none", function (evt) {
    tool.cytoscape_tool('set_points', undefined)
    tool.cytoscape_tool('draw')
  });

  tool.cytoscape_tool('add_context_menu_item', "Pull first neighbors", "nodes", function (evt) {
    cytoscape_fix_positions(tool)
    var rootNode = evt.target;
    var points = cytoscape_pull_first(tool, rootNode);
    tool.cytoscape_tool('set_points', points)
    tool.cytoscape_tool('draw')
  });

  tool.cytoscape_tool('add_context_menu_item', "Pull second neighbors", "nodes", function (evt) {
    cytoscape_fix_positions(tool)
    var vis = tool.cytoscape_tool('vis');
    var rootNode = evt.target;
    var points = cytoscape_pull_first(tool, rootNode);
    var orig_points = points
    tool.cytoscape_tool('set_points', points)

    var fNeighbors = vis.firstNeighbors([rootNode]);
    var neighborNodes = fNeighbors.neighbors;
    $.each(neighborNodes, function(){
      var nroot = this
      points = cytoscape_pull_first(tool, nroot);
      $.each(neighborNodes, function(){
        var nnroot = this
        points[nnroot.data.id] = orig_points[nnroot.data.id]
      })
      points[rootNode.data.id] = orig_points[rootNode.data.id]
      tool.cytoscape_tool('set_points', points)
    })

    tool.cytoscape_tool('draw')
  });


  tool.cytoscape_tool('add_context_menu_item', "Surround with first neighbors", "nodes", function (evt) {
    cytoscape_fix_positions(tool)
    var rootNode = evt.target;
    var points = cytoscape_surround_first(tool, rootNode);
    tool.cytoscape_tool('set_points', points)
    tool.cytoscape_tool('draw')
  });

  tool.cytoscape_tool('add_context_menu_item', "Surround with second neighbors", "nodes", function (evt) {
    cytoscape_fix_positions(tool)
    var vis = tool.cytoscape_tool('vis');
    var rootNode = evt.target;
    var points = cytoscape_surround_first(tool, rootNode);
    var orig_points = points
    tool.cytoscape_tool('set_points', points)

    var fNeighbors = vis.firstNeighbors([rootNode]);
    var neighborNodes = fNeighbors.neighbors;

    $.each(neighborNodes, function(){
      var nroot = this
      points = cytoscape_surround_first(tool, nroot);
      $.each(neighborNodes, function(){
        var nnroot = this
        points[nnroot.data.id] = orig_points[nnroot.data.id]
      })
      points[rootNode.data.id] = orig_points[rootNode.data.id]
 
      tool.cytoscape_tool('set_points', points)
    })

    points = cytoscape_surround_first(tool, rootNode);
    tool.cytoscape_tool('set_points', points)
    tool.cytoscape_tool('draw')
  });

  tool.cytoscape_tool('add_context_menu_item', "Horizontally place selected", "none", function (evt) {
    var vis = tool.cytoscape_tool('vis');
    var all_nodes = vis.nodes();
    var selected = vis.selected('nodes')
    var zoom = vis.zoom();
    var root_x = evt.mouseX / zoom
    var root_y = evt.mouseY / zoom
    var dist = 20
    var points = []
    var selected_ids = $.map(selected, function(node){return(node.data.id)})
    var ang = 0
    var num = 0
    var l = 0
    $.each(all_nodes, function(){
      var node = this
      if ($.inArray(node.data.id, selected_ids) >= 0){
        num += 1;
        if (undefined !== node.data.size){
          l += tool.cytoscape_tool('get_options').visualStyle.nodes.size.defaultValue * 2
          }else{
            l += parseInt(node.data.size)  * 2
          }
        }
      })

      var pos = root_x - l / 2
      var pos_inc = l / num

      $.each(all_nodes, function(){
        var node = this
        if ($.inArray(node.data.id, selected_ids) >= 0){
          pos += pos_inc
          var node_x = root_x + pos 
          var node_y = root_y
          node.x = node_x * zoom
          node.y = node_y * zoom
        }
      points[node.data.id] = {id:node.data.id, x: node.x / zoom, y: node.y / zoom}
    })
    tool.cytoscape_tool('set_points', points)
    tool.cytoscape_tool('draw')
  });

  tool.cytoscape_tool('add_context_menu_item', "Vertically place selected", "none", function (evt) {
    var vis = tool.cytoscape_tool('vis');
    var all_nodes = vis.nodes();
    var selected = vis.selected('nodes')
    var zoom = vis.zoom();
    var root_x = evt.mouseX / zoom
    var root_y = evt.mouseY / zoom
    var dist = 20
    var points = []
    var selected_ids = $.map(selected, function(node){return(node.data.id)})
    var ang = 0
    var num = 0
    var l = 0
    $.each(all_nodes, function(){
      var node = this
      if ($.inArray(node.data.id, selected_ids) >= 0){
        num += 1;
        if (undefined !== node.data.size){
          l += tool.cytoscape_tool('get_options').visualStyle.nodes.size.defaultValue * 2
          }else{
            l += parseInt(node.data.size)  * 2
          }
        }
      })

      var pos = root_y - l / 2
      var pos_inc = l / num

      $.each(all_nodes, function(){
        var node = this
        if ($.inArray(node.data.id, selected_ids) >= 0){
          pos += pos_inc
          var node_x = root_x 
          var node_y = root_y + pos
          node.x = node_x * zoom
          node.y = node_y * zoom
        }
      points[node.data.id] = {id:node.data.id, x: node.x / zoom, y: node.y / zoom}
    })
    tool.cytoscape_tool('set_points', points)
    tool.cytoscape_tool('draw')
  });

}
