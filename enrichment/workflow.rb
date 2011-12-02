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

Workflow.require_workflow 'Translation'

module Enrichment
  extend Workflow
  extend Resource

  input :list, :array, "KEGG Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochber FDR correction", true
  def self.kegg_enrichment(list, cutoff, fdr)
    KEGG.gene_pathway.tsv(:persist => true).enrichment(list, "KEGG Pathway ID", :persist => true, :cutoff => cutoff, :fdr => fdr)
  end
  task :kegg_enrichment=> :tsv
  export_synchronous :kegg_enrichment

  input :organism, :string, "Organism code", "Hsa"
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochber FDR correction", true
  def self.go_bp_enrichment(organism, list, cutoff, fdr)
    Organism.gene_go_bp(organism).tsv(:persist => true).enrichment(list, "GO ID", :persist => true, :cutoff => cutoff, :fdr => fdr)
  end
  task :go_bp_enrichment=> :tsv
  export_synchronous :go_bp_enrichment

  input :organism, :string, "Organism code", "Hsa"
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochber FDR correction", true
  def self.pfam_enrichment(organism, list, cutoff, fdr)
    Organism.gene_pfam(organism).tsv(:persist => true).enrichment(list, "Pfam Domain", :persist => true, :cutoff => cutoff, :fdr => fdr)
  end
  task :pfam_enrichment=> :tsv
  export_synchronous :pfam_enrichment


  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochber FDR correction", true
  def self.reactome_enrichment(list, cutoff, fdr)
    pathways = NCI.reactome_pathways.tsv :key_field => "UniProt/SwissProt Accession", :fields => ["NCI Reactome Pathway ID"], :persist => true, :merge => true, :type => :flat
    pathways.enrichment list, "NCI Reactome Pathway ID", :cutoff => 0.1, :fdr => true, :persist => true, :cutoff => cutoff, :fdr => fdr
  end
  task :reactome_enrichment=> :tsv
  export_synchronous :reactome_enrichment

  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochber FDR correction", true
  def self.biocarta_enrichment(list, cutoff, fdr)
    pathways = NCI.biocarta_pathways.tsv :key_field => "Entrez Gene ID", :fields => ["NCI BioCarta Pathway ID"], :persist => true, :merge => true, :type => :flat
    pathways.enrichment list, "NCI BioCarta Pathway ID", :cutoff => 0.1, :fdr => true, :persist => true, :cutoff => cutoff, :fdr => fdr
  end
  task :biocarta_enrichment=> :tsv
  export_synchronous :biocarta_enrichment

  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochber FDR correction", true
  def self.nature_enrichment(list, cutoff, fdr)
    pathways = NCI.nature_pathways.tsv :key_field => "UniProt/SwissProt Accession", :fields => ["NCI Nature Pathway ID"], :persist => true, :merge => true, :type => :flat
    pathways.enrichment list, "NCI Nature Pathway ID", :cutoff => 0.1, :fdr => true, :persist => true, :cutoff => cutoff, :fdr => fdr
  end
  task :nature_enrichment=> :tsv
  export_synchronous :nature_enrichment

  input :database, :string, "Database code: Kegg, GO_BP"
  input :list, :array, "Gene list in the appropriate format"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochber FDR correction", true
  def self.enrichment(database, list, organism, cutoff, fdr)
    ensembl = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run
    Gene.setup(ensembl, "Ensembl Gene ID", "Hsa")
    case database.downcase
    when "kegg"
      Enrichment.kegg_enrichment(ensembl.to_kegg, cutoff, fdr)
    when "go", "go bp", "go_bp"
      Enrichment.go_bp_enrichment(organism, ensembl, cutoff, fdr)
    when "reactome"
      Enrichment.reactome_enrichment(ensembl.to("UniProt/SwissProt Accession"), cutoff, fdr)
    when "nature"
      Enrichment.nature_enrichment(ensembl.to("UniProt/SwissProt Accession"), cutoff, fdr)
    when "biocarta"
      Enrichment.biocarta_enrichment(ensembl.entrez, cutoff, fdr)
    when "pfam"
      Enrichment.pfam_enrichment(organism, ensembl, cutoff, fdr)
    else
      raise "Unknown database code: #{ database }"
    end
  end
  task :enrichment => :tsv
  export_synchronous :enrichment
end