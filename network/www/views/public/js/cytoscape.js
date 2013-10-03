require_js('/js/cytoscape/src/AC_OETags.js');
require_js('/js/cytoscape/src/cytoscapeweb.js');

$.widget("rbbt.cytoscape_tool", {

 options: {
  // where you have the Cytoscape Web SWF
  swfPath: "/js-find/cytoscape/swf/CytoscapeWeb",
  flashInstallerPath: "/js/cytoscape/swf/playerProductInstall",
  knowledgebase: undefined,
  entities: {},
  databases: [],
  aesthetics: {nodes:{}, edges:{}},
  node_click: function(event){},
  edge_click: function(event){},
  menu_items: [],
  points: undefined,
  init: false,
  entity_options: { 
   organism: "Hsa/jun2011" 
  },

  visualStyle:{
   nodes:{

    shape:{ 
     defaultValue: "CIRCLE", passthroughMapper: { attrName: 'shape' } 
    },
    size:{ 
     defaultValue: 25, passthroughMapper: { attrName: 'size' } 
    },
    opacity:{ 
     defaultValue: 0.7,
     continuousMapper: {
      attrName: 'opacity',
      minValue: 0.1,
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
    },
    color: { 
     defaultValue: "#f5f5f5", passthroughMapper: { attrName: 'color' } 
    },

   },
   edges:{

    weight:{ 
     defaultValue: 3, passthroughMapper: { attrName: 'weight' } 
    },

    width:{ 
     defaultValue: 3,
     continuousMapper: {
      attrName: 'width',
      minValue: 1,
      maxValue: 10
     }
    },
    opacity:{ 
     defaultValue: 0.3,
     continuousMapper: {
      attrName: 'opacity',
      minValue: 0.2,
      maxValue: 1
     }
    },
    color: { 
     defaultValue: "#999", passthroughMapper: { attrName: 'color' } 
    },
   },
  }
 },

 _update_events: function(){
  var vis = this._vis()
  var tool = this;
  vis.ready(function(){
   tool._process_aesthetics();
   if (tool.options.init == false){
    vis.removeListener("click", "nodes")
    vis.removeListener("click", "edges")
    vis.addListener("click", "nodes", function(event) {
     tool.options.node_click(event);
     return false;
    })
    .addListener("click", "edges", function(event) {
     tool.options.edge_click(event);
     return false;
    })
    tool.options.init = true;
   }

   for (i in this.options.menu_items){
    var menu_item = this.options.menu_items[i]
    vis.addContextMenuItem(menu_item.text, menu_item.elem, menu_item.func);
   }
  })
 },

 _create: function() {
  this.element.addClass('cytoscape_tool_init')
  this.element.find('.window');
  var div_id = this.element.find('.window').attr('id')
  this.options.idToken = div_id;
  var vis = this.options.vis = new org.cytoscapeweb.Visualization(div_id, this.options);
  this.options.init = false

  var tool = this;
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

  _get_node_schema: function(){
    return JSON.parse(get_ajax({method: 'GET', url: '/tool/cytoscape/node_schema', async: false}));
  },

  _get_edge_schema: function(){
    return JSON.parse(get_ajax({method: 'GET', url: '/tool/cytoscape/edge_schema', async: false}));
  },

  _get_network: function(databases, complete){
    return get_ajax({method: 'POST', url: '/tool/cytoscape/get_network', data: $.extend({}, this.options.entity_options, {knowledgebase: this.options.knowledgebase, databases: databases.join("|"), entities: JSON.stringify(this.options.entities), entity_options: JSON.stringify(this.options.entity_options), _format: 'json'}), async: false}, complete);
  },

  _get_neighbours: function(database, entities, complete){
    return get_ajax({method: 'POST', url: '/tool/cytoscape/get_neighbours', data: $.extend({}, this.options.entity_options, {knowledgebase: this.options.knowledgebase, database: database, entities: JSON.stringify(entities), _format: 'json'}), async: false}, complete);
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

  //_network: function(){
  // if (undefined !== this.options.network){ 
  //  return this.options.network;
  // }

  // this.options.init = false
  // var network = this._get_network(this.options.databases)
  // this.options.network = network
  // return network;
  //},

  ////  HIGH LEVEL
 
  //draw: function(){
  // var config = {network: this._network(), visualStyle: this.options.visualStyle}
  // if (undefined !== this.options.points){
  //   var points = array_values(this.options.points);
  //   config.layout = {name:"Preset", options:{fitToScreen: true, points: points}}
  // }
  // this._vis().draw(config)
  // this._update_events()
  //},
 
  set_points: function(points){
   this.options.points = points
  },

  draw: function(){
   var tool = this;
   this._get_network(this.options.databases, function(network){
    tool.options.init = false
    tool.options.network = network

    var config = {network: network, visualStyle: tool.options.visualStyle}

    if (undefined !== tool.options.points){
     var points = array_values(tool.options.points);
     config.layout = {name:"Preset", options:{fitToScreen: true, points: points}}
    }

    tool._vis().draw(config)
    tool._update_events()
   })
  },
 
  set_points: function(points){
   this.options.points = points
  },
  
  vis: function(){ return this._vis()},

  add_context_menu_item: function(text, elem, func){
   this.options.menu_items.push({text:text, elem:elem, func:func})
  },

  get_options: function(){
   return(this.options);
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
    if (undefined === this.options.entities[type]){
      this.options.entities[type] = entities;
    }else{
      this.options.entities[type] = $.unique(this.options.entities[type].concat(entities));
    }
  },

  add_neighbours: function(database){
    var tool = this
    this._get_neighbours(database, this.options.entities, function(info){
      var type = info.type
      var entities = info.entities
      tool.add_entities(type, entities)
      tool.draw()
    })
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

  set_edges: function(databases){
    this.options.network = undefined
    this.options.databases = databases;
  },


  //{{{ ASCETICS
  _elem_feature: function(elem, feature){
   if(undefined === feature) return elem.data.id
   if(typeof feature == 'string' ){
     if (undefined === elem.data[feature] && undefined !== elem.data.info){
      return JSON.parse(elem.data.info)[feature];
     }else{       
      return elem.data[feature];
     }            
   }
   if(typeof feature == 'function' ) return feature(elem)
   return undefined
  },

  _map: function(elem_type, aesthetic, map, feature){
    var vis = this._vis();
    if (elem_type == 'nodes'){
     var elems = vis.nodes();
    }else{
     var elems = vis.edges();
    }

    var updated_elems = []
    for (i in elems){
      var elem = elems[i];
      var code = this._elem_feature(elem, feature)
      if (undefined !== map[code]){
        value = map[code];
        elem.data[aesthetic] = value
        updated_elems.push(elem)
      }
    }
    vis.updateData(updated_elems);
  },


  _map_continuous: function(elem_type, aesthetic, map, feature){
    var vis = this._vis();
    if (elem_type == 'nodes'){
     var elems = vis.nodes();
    }else{
     var elems = vis.edges();
    }
    var tool = this

    if (undefined === map || null === map){
      map = {};
      $.each(elems, function(){
        var elem = this
        var id = elem.data.id
        var val = tool._elem_feature(elem, feature)
        map[id] = val
      })
    }

    var elem_codes = $.map(elems, function(elem){return(tool._elem_feature(elem, feature))})

    if (elem_codes.length == 0){ return }
    var max = 0
    for (entity in map){
      if ($.inArray(entity, elem_codes) > -1){
       var value = parseFloat(map[entity]);
       if (value > max) max = value
      }
    }

    var updated_elems = []
    for (i in elems){
      var elem = elems[i];
      var code = this._elem_feature(elem, feature)
      if (undefined !== map[code]){
        value = parseFloat(map[code]) / max;
        if (typeof value == 'number' && ! isNaN(value)){
          elem.data[aesthetic] = value
          updated_elems.push(elem)
        }
      }
    }
    vis.updateData(updated_elems);
  },


  _add_aesthetic: function(elem, aesthetic, type, feature, map){
   if (undefined === this.options.aesthetics[elem][aesthetic]) this.options.aesthetics[elem][aesthetic] = []
   this.options.aesthetics[elem][aesthetic].push({type:type, feature:feature, map:map})
  },

  _process_aesthetics: function(){
   for (elem in this.options.aesthetics){
    for (aesthetic in this.options.aesthetics[elem]){
     for (i in this.options.aesthetics[elem][aesthetic]){
      var info = this.options.aesthetics[elem][aesthetic][i];
      if(info.type === 'continuous'){
       this._map_continuous(elem, aesthetic, info.map, info.feature)
      }else{
       this._map(elem, aesthetic, info.map, info.feature)
      }
     }
    }
   }
  },

  aesthetic: function(elem, aesthetic, map, feature){
   var type = undefined;
   if (undefined === feature){ feature = 'id' }
   if (undefined !== this.options.visualStyle[elem][aesthetic].continuousMapper) type = 'continuous'
   if (undefined !== this.options.visualStyle[elem][aesthetic].discreteMapper) type = 'discrete'
   if (undefined !== this.options.visualStyle[elem][aesthetic].passthroughMapper) type = 'passthrough'

   this._add_aesthetic(elem, aesthetic, type, feature, map)
   this.options.network = undefined
  },
})

