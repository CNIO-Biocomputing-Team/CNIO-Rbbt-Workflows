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
      size:{ 
       defaultValue: 25,
       discreteMapper: {
        attrName: 'selected',
        entries:[
         { attrValue: true, value: 40}
        ]
       }
      },
      opacity:{ 
       defaultValue: 0.7,
       continuousMapper: {
        attrName: 'opacity',
        minValue: 0.2,
        maxValue: 1
       }
      },
      borderWidth:{ 
       defaultValue: 1,
       continuousMapper: {
        attrName: 'borderWidth',
        minValue: 1,
        maxValue: 10
       }
      }
     },
     edges:{
      opacity:{ 
       defaultValue: 0.7,
       continuousMapper: {
        attrName: 'opacity',
        minValue: 0.2,
        maxValue: 1
       }
      },
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
    //return $.ajax({method: 'POST', url: '/tool/cytoscape/get_nodes', data: $.extend(this.options.entity_options, {type: type, entities: entities.join("|"), _format: 'json'}), async: false}).responseJSON;
    return JSON.parse(get_ajax({method: 'POST', url: '/tool/cytoscape/get_nodes', data: $.extend(this.options.entity_options, {type: type, entities: entities.join("|"), _format: 'json'}), async: false}));
  },

  _get_node_schema: function(){
    //return $.ajax({method: 'GET', url: '/tool/cytoscape/node_schema', async: false}).responseJSON;
    return JSON.parse(get_ajax({method: 'GET', url: '/tool/cytoscape/node_schema', async: false}));
  },

  _get_edge_schema: function(){
    //return $.ajax({method: 'GET', url: '/tool/cytoscape/edge_schema', async: false}).responseJSON;
    return JSON.parse(get_ajax({method: 'GET', url: '/tool/cytoscape/edge_schema', async: false}));
  },

  _get_edges: function(database){
    //return $.ajax({method: 'POST', url: '/tool/cytoscape/get_edges', data: $.extend(this.options.entity_options, {database: database, entities: JSON.stringify(this.options.entities), _format: 'json'}), async: false}).responseJSON;
    return JSON.parse(get_ajax({method: 'POST', url: '/tool/cytoscape/get_edges', data: $.extend(this.options.entity_options, {database: database, entities: JSON.stringify(this.options.entities), _format: 'json'}), async: false}));
  },

  _get_network: function(databases){
    return JSON.parse(get_ajax({method: 'POST', url: '/tool/cytoscape/get_network', data: $.extend(this.options.entity_options, {databases: databases.join("|"), entities: JSON.stringify(this.options.entities), _format: 'json'}), async: false}));
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
    var found = []
    $.each(all_entities, function(){found[this] = true})

    return $.grep(edges, function(elem){
      return(undefined !== found[elem.source] && undefined !== found[elem.target])
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
    var vis = this._vis();
    var nodes = vis.nodes();
    var node_ids = $.map(nodes, function(node){return(node.data.id)})

    var max = 0
    for (entity in map){
      if ($.inArray(entity, node_ids) > -1){
       var value = parseFloat(map[entity]);
       if (value > max) max = value
      }
    }

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

  _network_old: function(){
    var network = {};
    var edges = this._edges();
    var nodes = this._nodes();

    network['data'] = {
      nodes: nodes, edges: edges
    };

    network['dataSchema'] = {nodes: this._get_node_schema(), edges: this._get_edge_schema()}
    return network;
  },

  _network: function(){
    if (undefined !== this.options.network){ return this.options.network}
    var network = this._get_network(this.options.databases)
    this.options.network = network
    return network;
  },


  //  HIGH LEVEL
  //
  get_options: function(){
   return(this.options);
  },

  draw: function(){
    this._vis().draw({network: this._network(), visualStyle: this.options.visualStyle})
  },

  select_entities: function(entities){
   var vis = this._vis();
   var nodes = vis.nodes();

   var found = []
   $.each(entities, function(){found[this] = true})
   for (i in nodes){
    var node = nodes[i];
    if (found[node.data.id]){
     node.data.selected = true;
    }else{
     node.data.selected = false;
    }
   }
   vis.updateData(nodes);
  },

  add_entities: function(type, entities){
    this.options.network = undefined
    if (undefined === this.options.entities[type]){
      this.options.entities[type] = entities;
    }else{
      this.options.entities[type] = $.unique(this.options.entities[type].concat(entities));
    }
  },

  remove_entities: function(type, entities){
    this.options.network = undefined
    if (undefined !== this.options.entities[type]){
      var current_list = this.options.entities[type]
      var new_list = [];
      for (i in current_list){
       var entity = current_list[i];
       if ($.inArray(entity, entities) == -1){
        new_list.push(entity)
       }else{
        console.log("Removing: " + entity)
       }
      }
      this.options.entities[type] = new_list
    }
  },

  add_edges: function(database){
    this.options.network = undefined
    this.options.databases.push(database);
    this.options.databases = $.unique(this.options.databases);
  },
  
  add_map: function(aesthetic, map){
    this._map_continuous(aesthetic, map);
  },
})

