require 'rbbt/rest/web_tool'
require 'graph'

include Sinatra::RbbtToolHelper

Rbbt.claim Rbbt.www.views.public.js.cytoscape.find(:lib), :proc do |dir|
  url = "http://cytoscapeweb.cytoscape.org/file/lib/cytoscapeweb_v1.0.3.zip"
  TmpFile.with_file(nil, true, :extension => 'zip') do |zip_file|
    Open.write(zip_file, Open.read(url, :mode => 'rb', :noz => true), :mode => 'wb')
    TmpFile.with_file do |unzip_dir|
      FileUtils.mkdir_p unzip_dir unless File.exists? unzip_dir
      CMD.cmd("unzip -x '#{zip_file}' -d '#{unzip_dir}'")
      Dir.glob(File.join(unzip_dir, '*')).each do |file|
        FileUtils.mv(file, dir)
      end
    end
  end
  nil
end

Rbbt.www.views.public.js.cytoscape.find(:lib).produce

get '/tool/cytoscape/edge_schema' do
  content_type "application/json"

  halt 200, Graph.edge_schema.to_json
end

get '/tool/cytoscape/node_schema' do
  content_type "application/json"

  halt 200, Graph.node_schema.to_json
end

post '/tool/cytoscape/get_nodes' do
  type, entity_str = params.values_at :type, :entities

  nodes = Graph.nodes(type, entity_str.split("|"), params)

  content_type "application/json"

  halt 200, nodes.to_json
end

post '/tool/cytoscape/get_edges' do
  database, entity_json = params.values_at "database", "entities"

  entities = JSON.parse(entity_json)

  all_edges = []
  entities.each do |type, list|
    Misc.prepare_entity(list, type, params)
    all_edges.concat Graph.edges(database, list)
  end


  content_type "application/json"
  halt 200, all_edges.to_json
end

