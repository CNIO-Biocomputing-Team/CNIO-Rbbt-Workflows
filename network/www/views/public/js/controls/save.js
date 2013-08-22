function cytoscape_save(tool){
  tool.cytoscape_tool('add_context_menu_item', "Store", "none", function (evt) {
    var options = tool.cytoscape_tool('get_options');

    var save = {}
    save.entities = options.entities
    save.databases = options.databases
    save.points = options.points
    save.aesthetics = options.aesthetics

    localStorage['network'] = JSON.stringify(save);
  })

  tool.cytoscape_tool('add_context_menu_item', "Load", "none", function (evt) {
    var options = tool.cytoscape_tool('get_options');

    var save = JSON.parse(localStorage['network']);
    options.entities  = save.entities
    options.databases = save.databases
    options.points    = save.points
    options.aesthetics = save.aesthetics
    options.network = undefined

    tool.cytoscape_tool('draw')

  })


}
