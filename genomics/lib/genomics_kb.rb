require 'rbbt-util'
require 'rbbt/workflow'
Workflow.require_workflow "Genomics"
require 'rbbt/association'

require 'rbbt/entity'
require 'rbbt/entity/gene'
require 'rbbt/knowledge_base'
require 'rbbt/sources/organism'
require 'rbbt/sources/pina'
require 'rbbt/sources/kegg'
require 'rbbt/sources/go'
require 'rbbt/sources/reactome'
require 'rbbt/sources/NCI'
require 'rbbt/sources/InterPro'

module Genomics
  class << self
    attr_accessor :knowledge_base
  end
end

Genomics.knowledge_base = KnowledgeBase.new Rbbt.var.knowledge_base.genomics, "Hsa/jan2013"
Genomics.knowledge_base.format["Gene"] = "Ensembl Gene ID"

Genomics.knowledge_base.register 'kegg'     , KEGG.gene_pathway
Genomics.knowledge_base.register 'go'       , Organism.gene_go('NAMESPACE'), :merge => true
Genomics.knowledge_base.register 'go_bp'    , Organism.gene_go_bp('NAMESPACE')
Genomics.knowledge_base.register 'go_mf'    , Organism.gene_go_mf('NAMESPACE')
Genomics.knowledge_base.register 'go_cc'    , Organism.gene_go_cc('NAMESPACE')
Genomics.knowledge_base.register 'pfam'     , Organism.gene_pfam('NAMESPACE')
Genomics.knowledge_base.register 'interpro' , InterPro.protein_domains         , :merge => true
Genomics.knowledge_base.register 'reactome' , Reactome.protein_pathways        , :merge => true
Genomics.knowledge_base.register 'nature'   , NCI.nature_pathways              , :merge => true , :target => "UniProt/SwissProt Accession" , :key_field => 0
Genomics.knowledge_base.register 'biocarta' , NCI.biocarta_pathways            , :merge => true , :target => 2 , :key_field => 0
Genomics.knowledge_base.register 'biocarta' , NCI.reactome_pathways            , :merge => true , :target => 2 , :key_field => 0

Genomics.knowledge_base.register "pina", Pina.protein_protein, 
  :undirected => true, 
  :target => "Interactor UniProt/SwissProt Accession=~UniProt/SwissProt Accession"

