$LOAD_PATH.unshift('./lib')
require 'rbbt-util'
require 'rbbt/sources/pina'
require 'rbbt/sources/string'
require 'graph/cytoscape'
require 'graph/knowledge_base'

class Graph

  attr_accessor :knowledge_base, :entities, :databases
  def initialize(knowledge_base, databases = nil)
    @knowledge_base = knowledge_base
    @entities = {}
    @databases = databases || []
  end

  def edges
    databases.collect do |database|
      Graph::Cytoscape.edges(knowledge_base.connections(database, entities))
    end.flatten
  end

  def nodes
    entities.collect do |type, list|
      info = @knowledge_base.info["All"]
      info = info.merge(@knowledge_base.info[type]) if @knowledge_base.info[type]
      Graph::Cytoscape.nodes(type, list, info)
    end.flatten
  end

  def network
    {:data => {:nodes => nodes, :edges => edges}, :dataSchema => {:nodes => Graph::Cytoscape.node_schema, :edges => Graph::Cytoscape.edge_schema}}
  end
end

if __FILE__ == $0
  require 'rbbt/sources/pina'
  require 'rbbt/entity/gene'
  require 'rbbt/entity/study'
  require 'rbbt/entity/study/genotypes'

  study = Study.setup("CLL")
  recurrent_genes = study.recurrent_genes

  kb = Graph::KnowledgeBase.new('./var/knowledge_base')
  kb.info["Gene"] = recurrent_genes.info

  kb.info["Sample"] = study.samples.select_by(:has_genotype?).info

  kb.associations("pina", Pina.protein_protein, :target => "Interactor UniProt/SwissProt Accession", :target_type => "UniProt/SwissProt Accession")
  kb.associations("mutations", TSV.setup(study.samples_with_gene_affected, :key_field => "Ensembl Gene ID", :fields => ["Sample"], :type => :flat, :filename => "Genes samples #{ study }"), :target => "Ensembl Gene ID")

  g = Graph.new(kb, %w(pina mutations))

  g.entities["Gene"] = recurrent_genes
  g.entities["Sample"] = study.samples.select_by(:has_genotype?)

end
