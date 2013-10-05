require 'rbbt/sources/pina'
require 'rbbt/sources/string'
require 'rbbt/sources/InterPro'
require 'graph'

require 'rbbt/gene_associations'

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

dir = Rbbt.var.knowledge_base.find :lib
$default_organism = "Hsa/jan2013"
$knowledge_base = Graph::KnowledgeBase.new dir

$knowledge_base.info["All"] = {:organism => $default_organism}
$knowledge_base.info["Gene"] = {:format => "Ensembl Gene ID"}


Association.databases.each do |database, info|
  file, options = info
  options ||= {}
  options[:namespace] = $default_organism
  options[:source_type] = "Ensembl Gene ID"
  options[:target_type] = "Ensembl Gene ID"

  $knowledge_base.register database, file, options
  #$knowledge_base.associations(database, Association.open(file, options), options)
  #
end

#$knowledge_base.associations("string", STRING.protein_protein,  :target => "Interactor Ensembl Protein ID", :source_type => "Gene:Ensembl Protein ID", :target_type => "Gene:Ensembl Protein ID")
#$knowledge_base.associations("go_bp", Organism.gene_go_bp("Hsa/jan2013"), :target => "GO ID", :type => :flat)
#$knowledge_base.associations("go_mf", Organism.gene_go_mf("Hsa/jan2013"), :target => "GO ID", :type => :flat)
#$knowledge_base.associations("go_cc", Organism.gene_go_cc("Hsa/jan2013"), :target => "GO ID", :type => :flat)
#$knowledge_base.associations("nature", NCI.nature_pathways, :key_field => "UniProt/SwissProt Accession", :target => "NCI Nature Pathway ID", :type => :flat, :merge => true)
#$knowledge_base.associations("interpro", InterPro.protein_domains, :key_field => "UniProt/SwissProt Accession", :fields => ["InterPro ID"], :type => :flat, :merge => false)


Rbbt.www.views.public.js.cytoscape.find(:lib).produce

get '/tool/cytoscape/edge_schema' do
  content_type "application/json"

  content_type "application/json"
  halt 200, Graph::Cytoscape.edge_schema.to_json
end

get '/tool/cytoscape/node_schema' do
  content_type "application/json"

  content_type "application/json"
  halt 200, Graph::Cytoscape.node_schema.to_json
end

post '/tool/cytoscape/get_nodes' do
  type, entity_str = params.values_at :type, :entities

  @cache_type = :async
  content_type "application/json"
  cache('get_nodes', :type => type, :entities => entity_str) do
    nodes = Graph::Cytoscape.nodes(type, entity_str.split("|"), params)

    content_type "application/json"

    nodes.to_json
  end
end

post '/tool/cytoscape/get_neighbours' do
  database, entities_json, knowledgebase = params.values_at :database, :entities, :knowledgebase

  entities = JSON.parse(entities_json)

  if knowledgebase.nil? or knowledgebase.empty?
    knowledgebases = [$knowledge_base]
  else
    knowledgebases = [Graph::KnowledgeBase.new(knowledgebase), $knowledge_base]
  end

  @cache_type = :exec
  content_type "application/json"
  cache('get_neighbours', :database => database, :entities => entities_json, :knowledgebase => knowledgebase) do
    info = knowledgebases.collect{|kb| kb.neighbours(database, entities)}.compact.first

    info.to_json
  end
end


post '/tool/cytoscape/get_edges' do
  database, entity_json = params.values_at "database", "entities"

  @cache_type = :async
  content_type "application/json"
  cache('get_edges', :database => database, :entity_json => entity_json) do
    entities = JSON.parse(entity_json)

    all_edges = []
    entities.each do |type, list|
      Misc.prepare_entity(list, type, params)
      all_edges.concat Graph.edges(database, list)
    end

    all_edges.to_json
  end
end

post '/tool/cytoscape/get_network' do
  entity_json = params[:entities]
  databases = params[:databases]
  knowledgebase = params[:knowledgebase]

  entity_options_json = params[:entity_options]
  entity_options_json = "{}" if entity_options_json.nil? or entity_options_json.empty?

  if knowledgebase.nil? or knowledgebase.empty?
    knowledgebase = $knowledge_base
    g = Graph.new $knowledge_base, databases.split("|")
  else
    knowledgebase = Graph::KnowledgeBase.new knowledgebase
    knowledgebase.info["All"] = JSON.parse(entity_options_json)
    g = Graph.new [$knowledge_base, knowledgebase], databases.split("|")
  end


  g.entities = JSON.parse(entity_json)

  content_type "application/json"
  halt 200, g.network().to_json
end

