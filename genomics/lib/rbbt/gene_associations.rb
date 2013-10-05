require 'rbbt/association'

require 'rbbt/entity'
require 'rbbt/entity/gene'
require 'rbbt/entity/knowledge_base'
require 'rbbt/sources/organism'
require 'rbbt/sources/pina'
require 'rbbt/sources/kegg'
require 'rbbt/sources/go'
require 'rbbt/sources/reactome'
require 'rbbt/sources/NCI'
require 'rbbt/sources/InterPro'

Association.register 'kegg'     , KEGG.gene_pathway

Association.register 'go'       , Organism.gene_go('NAMESPACE')
Association.register 'go_bp'    , Organism.gene_go_bp('NAMESPACE')
Association.register 'go_mf'    , Organism.gene_go_mf('NAMESPACE')
Association.register 'go_cc'    , Organism.gene_go_cc('NAMESPACE')
Association.register 'pfam'     , Organism.gene_pfam('NAMESPACE')

Association.register 'interpro' , InterPro.protein_domains         , :merge => true

Association.register 'reactome' , Reactome.protein_pathways        , :merge => true
Association.register 'nature'   , NCI.nature_pathways              , :merge => true , :fields => [2] , :key_field => 0
Association.register 'biocarta' , NCI.biocarta_pathways            , :merge => true , :fields => [2] , :key_field => 0

Association.register "pina", Pina.protein_protein, 
  :undirected => true, 
  :target => "Interactor UniProt/SwissProt Accession=~UniProt/SwissProt Accession"

