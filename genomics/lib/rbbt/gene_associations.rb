require 'rbbt/association'

require 'rbbt/entity'
require 'rbbt/entity/gene'
require 'rbbt/sources/organism'
require 'rbbt/sources/pina'
require 'rbbt/sources/kegg'
require 'rbbt/sources/go'
require 'rbbt/sources/reactome'
require 'rbbt/sources/NCI'
require 'rbbt/sources/InterPro'


Association.databases['kegg']     = KEGG.gene_pathway
Association.databases['go']       = Organism.gene_go('NAMESPACE')
Association.databases['go_bp']    = Organism.gene_go_bp('NAMESPACE')
Association.databases['go_mf']    = Organism.gene_go_mf('NAMESPACE')
Association.databases['go_cc']    = Organism.gene_go_cc('NAMESPACE')
Association.databases['pfam']     = Organism.gene_pfam('NAMESPACE')
Association.databases['interpro'] = InterPro.protein_domains
Association.databases['reactome'] = Reactome.protein_pathways
Association.databases['nature']   = NCI.nature_pathways
Association.databases['biocarta'] = NCI.biocarta_pathways

Association.databases["pina"] = [Pina.protein_protein, {:undirected => true, :target => ["Ensembl Gene ID", "Interactor UniProt/SwissProt Accession=~UniProt/SwissProt Accession"]}]

