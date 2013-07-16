$LOAD_PATH.unshift('./lib')
require 'rbbt-util'
require 'graph/cytoscape'
require 'graph/knowledge_base'

class Graph

  attr_accessor :knowledge_base, :entities, :databases, :aesthetics
  def initialize(knowledge_base, databases = nil)
    @knowledge_base = knowledge_base
    @entities = {}
    @databases = databases || []
    @aesthetics = {:nodes => {}, :edges => {}}
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

  def add_aesthetic(elem, aesthetic, feature, map = nil)
    @aesthetics[elem][aesthetic] = {:feature => feature, :map => map}
  end

  class M
    attr_accessor :entities, :connections
    def initialize(entities, connections)
    end
  end
end

if __FILE__ == $0
  require 'rbbt/workflow'
  Workflow.require_workflow 'Genomics'

  require 'rbbt/entity/gene'
  require 'rbbt/sources/pina'

  ddd Gene.instance_methods.sort

  mdm2 = Gene.setup("MDM2", "Associated Gene Name", "Hsa/jan2013").ensembl
  genes = mdm2.pina_interactors.ensembl.compact.uniq

  dir = Rbbt.var.knowledge_base.find :lib
  knowledge_base = Graph::KnowledgeBase.new dir do |kb|

    associations("pina", Pina.protein_protein, :target => "Interactor UniProt/SwissProt Accession", :target_type => "UniProt/SwissProt Accession")
    associations("string", STRING.protein_protein,  :target => "Interactor Ensembl Protein ID", :source_type => "Gene:Ensembl Protein ID", :target_type => "Gene:Ensembl Protein ID")
    associations("go_bp", Organism.gene_go_bp("Hsa/jan2013"), :target => "GO ID", :type => :flat)
    associations("go_mf", Organism.gene_go_mf("Hsa/jan2013"), :target => "GO ID", :type => :flat)
    associations("go_cc", Organism.gene_go_cc("Hsa/jan2013"), :target => "GO ID", :type => :flat)
    associations("nature", NCI.nature_pathways, :key_field => "UniProt/SwissProt Accession", :target => "NCI Nature Pathway ID", :type => :flat, :merge => true)
    associations("interpro", InterPro.protein_domains, :key_field => "UniProt/SwissProt Accession", :fields => ["InterPro ID"], :type => :flat, :merge => false)
  end

  knowledge_base.info["All"] = {:organism => "Hsa/jan2013"}
  knowledge_base.info["Gene"] = {:format => "Ensembl Gene ID"}

  grap = Graph.new knowledge_base

  grap.add_entities genes
  grap.databases << 'pina'

  grap.nodes("Pathway").each do |pth|
    genes = pth.children("Gene")
    new_nodes << {:id => id, :label => name}
    genes.parent = id
  end
end




