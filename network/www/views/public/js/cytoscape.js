require_js('/js/cytoscape/src/AC_OETags.js');
require_js("/js/jquery-ui/jquery-ui.js");
require_js('/js/cytoscape/src/cytoscapeweb.js');

$.widget("rbbt.cytoscape_tool", {

  options: {
    // where you have the Cytoscape Web SWF
    swfPath: "/js/cytoscape/swf/CytoscapeWeb",
    flashInstallerPath: "/js/cytoscape/swf/playerProductInstall",
    entities: {},
    databases: [],
    aesthetics: {},
    node_click: function(event){},
    edge_click: function(event){},
    init: false,
    entity_options: { organism: "Hsa/jun2011" },

    visualStyle:{
      nodes:{
        opacity:{ 
          defaultValue: 0.7,
          continuousMapper: {
            attrName: 'opacity',
            minValue: 0.3,
            maxValue: 1
          }
        },
        borderWidth:{ 
          defaultValue: 1,
          continuousMapper: {
            attrName: 'borderWidth',
            minValue: 1,
            maxValue: 5
          }
        }
      }
    }
  },

  _create: function() {
    this.element.addClass('cytoscape_tool_init')
    this.element.find('.window');
    var div_id = this.element.find('.window').attr('id')
    var vis = this.options.vis = new org.cytoscapeweb.Visualization(div_id, this.options);

    var tool = this;
    vis.ready(function(){
      if (this.options.init == false){
        vis.addListener("click", "nodes", function(event) {
          tool.options.node_click(event);
          return false;
        })
        .addListener("click", "edges", function(event) {
          tool.options.edge_click(event);
          return false;
        })
        this.options.init = true
      }
    })
  },

  _vis: function() {
    return this.options.vis;
  },

  _all_entities: function(){
    var result = [];
    var entities = this.options.entities;
    for (var type in entities){
      result = result.concat(entities[type]);
    }
    return result
  },

  //  DRAWING

  _get_nodes: function(type, entities){
    return $.ajax({method: 'POST', url: '/tool/cytoscape/get_nodes', data: $.extend(this.options.entity_options, {type: type, entities: entities.join("|"), _format: 'json'}), async: false}).responseJSON;
  },

  _get_node_schema: function(){
    return $.ajax({method: 'GET', url: '/tool/cytoscape/node_schema', async: false}).responseJSON;
  },

  _get_edge_schema: function(){
    return $.ajax({method: 'GET', url: '/tool/cytoscape/edge_schema', async: false}).responseJSON;
  },

  _get_edges: function(database){
    return $.ajax({method: 'POST', url: '/tool/cytoscape/get_edges', data: $.extend(this.options.entity_options, {database: database, entities: JSON.stringify(this.options.entities), _format: 'json'}), async: false}).responseJSON;
  },

  _nodes: function(){
    var all_nodes = [];

    for (type in this.options.entities){
      var nodes = this._get_nodes(type, this.options.entities[type]);
      all_nodes = all_nodes.concat(nodes)
    }

    return all_nodes;
  },

  _filter_edges: function(edges){
    var tool = this;
    var all_entities = this._all_entities();

    return $.grep(edges, function(elem){
      return $.inArray(elem.source, all_entities) >= 0 && $.inArray(elem.target, all_entities) >= 0
    })
  },

  _edges: function(){
    var all_edges = [];

    for (i in this.options.databases){
      var database = this.options.databases[i];
      var edges = this._get_edges(database);
      all_edges = all_edges.concat(edges);
    }

    all_edges = this._filter_edges(all_edges);
    return all_edges;
  },

  _map_continuous: function(aesthetic, map){
    var max = 0
    for (entity in map){
      var value = parseFloat(map[entity]);
      if (value > max) max = value
    }

    var vis = this._vis();
    var nodes = vis.nodes();
    var updated_nodes = []
    for (i in nodes){
      var node = nodes[i];
      if (undefined !== map[node.data.id]){
        value = parseFloat(map[node.data.id]) / max;
        if (typeof value == 'number' && ! isNaN(value)){
          node.data[aesthetic] = value
          updated_nodes.push(node)
        }
      }
    }
    vis.updateData(updated_nodes);
  },

  _process_maps: function(nodes){
    var aesthetics = this.options.aesthetics;
    for (aesthetic in aesthetics){
      this._map_continuous(aesthetic, aesthetics[aesthetic])
    }
  },

  _network: function(){
    var network = {};
    var edges = this._edges();
    var nodes = this._nodes();

    network['data'] = {
      nodes: nodes, edges: edges
    };

    network['dataSchema'] = {nodes: this._get_node_schema(), edges: this._get_edge_schema()}
    return network;
  },


  //  HIGH LEVEL
  add_entities: function(type, entities){
    if (undefined === this.options.entities[type]){
      this.options.entities[type] = entities;
    }else{
      this.options.entities[type] = $.unique(this.options.entities[type].concat(entities));
    }
  },

  add_edges: function(database){
    this.options.databases.push(database);
    this.options.databases = $.unique(this.options.databases);
  },

  draw: function(){
    this._vis().draw({network: this._network(), visualStyle: this.options.visualStyle})
  },
  
  add_map: function(aesthetic, map){
    //this.options.aesthetics[aesthetic] = map;
    //this._process_maps(this._vis().nodes());
    this._map_continuous(aesthetic, map);
  },

  add_associations: function(database, options){ }
})

