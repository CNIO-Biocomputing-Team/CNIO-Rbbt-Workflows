require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/workflow/rest/entity'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/entity'
require 'rbbt/entity/gene'
require 'rbbt/sources/go'
require 'rbbt/sources/kegg'
require 'rbbt/sources/organism'
require 'rbbt/sources/NCI'
require 'rbbt/sources/pfam'

[Gene, GOTerm, KeggPathway, NCINaturePathways, NCIBioCartaPathways, NCIReactomePathways, PfamDomain].each do |mod|
  mod.module_eval do
    include Entity::REST
  end
end

Workflow.require_workflow 'Translation'
Workflow.require_workflow 'Enrichment'

module GeneList
  extend Workflow
  extend Resource

  input :list, :array, "Gene list in the appropriate format"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  def self.annotate_gene_list(list, organism)
    set_info :organism, organism
    ensembl = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact
    tsv = TSV.setup(Misc.process_to_hash(ensembl){ensembl.collect{[]}}, :key_field => "Ensembl Gene ID", :type => :double, :fields => [])
    tsv.identifiers = Organism.identifiers(organism).find
    tsv = tsv.attach Organism.gene_go_bp(organism).find, :fields => ["GO ID"], :persist_input => true
    tsv = tsv.attach KEGG.gene_pathway.find, :fields => ["KEGG Pathway ID"], :persist_input => true
    tsv = tsv.attach NCI.nature_pathways.find, :fields => ["NCI Nature Pathway ID"], :persist_input => true
    tsv = tsv.attach NCI.biocarta_pathways.find, :fields => ["NCI BioCarta Pathway ID"], :persist_input => true
    tsv = tsv.attach NCI.reactome_pathways.find, :fields => ["NCI Reactome Pathway ID"], :persist_input => true
    tsv = tsv.attach Organism.gene_pfam(organism).find, :fields => ["Pfam Domain"], :persist_input => true
    tsv
  end
  task :annotate_gene_list => :tsv
  export_exec :annotate_gene_list

  input :tsv, :tsv, "Gene list in the appropriate format"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  def self.tsv_annotate_gene_list(tsv, organism)
    set_info :organism, organism
    tsv.identifiers = Organism.identifiers(organism).produce

    tsv = tsv.attach Organism.gene_go_bp(organism).find, :fields => ["GO ID"], :persist_input => true
    tsv.identifiers = Organism.identifiers(organism).find
    tsv = tsv.attach KEGG.gene_pathway.find, :fields => ["KEGG Pathway ID"], :persist_input => true
    tsv.identifiers = Organism.identifiers(organism).find
    tsv = tsv.attach NCI.nature_pathways.find, :fields => ["NCI Nature Pathway ID"], :persist_input => true
    tsv.identifiers = Organism.identifiers(organism).find
    tsv = tsv.attach NCI.biocarta_pathways.find, :fields => ["NCI BioCarta Pathway ID"], :persist_input => true
    tsv.identifiers = Organism.identifiers(organism).find
    tsv = tsv.attach NCI.reactome_pathways.find, :fields => ["NCI Reactome Pathway ID"], :persist_input => true
    tsv.identifiers = Organism.identifiers(organism).find
    tsv = tsv.attach Organism.gene_pfam(organism).find, :fields => ["Pfam Domain"], :persist_input => true

    tsv.namespace = organism

    tsv
  end
  task :tsv_annotate_gene_list => :tsv
  export_synchronous :tsv_annotate_gene_list

end
