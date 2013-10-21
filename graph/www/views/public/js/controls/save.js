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

  tool.cytoscape_tool('add_context_menu_item', "List selected", "none", function (evt) {
    var vis = tool.cytoscape_tool('vis');
    var all_nodes = vis.nodes();
    var selected = vis.selected('nodes')

    var types = $.map(selected, function(e){return e.data['entity_type']})
    types = uniq(types)

    if (types.length > 1){
      var select = $('<select>')
      for (i in types){ select.append($('<option>').val(types[i]).html(types[i]))}
      var dialog = $('<form>').append(select).append($('<input>').attr('type', 'submit'))

      $('#modal').modal('ask', dialog, "Select entity type", function(){
        var type = $(this).find('select option:selected').val()
        $('#modal').modal('close')
        tool.cytoscape_tool('list_selected', type, selected)
        return false;
      });

    }else{
      var type = types[0];
      tool.cytoscape_tool('list_selected', type, selected)
    }
  })



}
