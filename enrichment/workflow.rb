require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/workflow/rest/entity'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/statistics/random_walk'
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

  RENAMES = Organism.identifiers("Hsa/jun2011").tsv(:persist => false, :key_field => "Ensembl Gene ID", :fields => [], :grep => '^#\|PCDH', :type => :list, :persit_update => true).add_field("Cluster"){ "Cadherin" }
  RENAMES.type = :single
  RENAMES.process("Cluster") do |values|
    values.first
  end

  RENAMES.keys.to_kegg.compact.each do |gene|
    RENAMES[gene] = "Cadherin"
  end

  Organism.identifiers("Hsa/jun2011").tsv(:persist => false, :key_field => "UniProt/SwissProt Accession", :fields => [], :grep => '^#\|PCDH', :type => :list, :persit_update => true).add_field("Cluster"){ "Cadherin" }.keys.each do |gene|
    RENAMES[gene] = "Cadherin"
  end

  Organism.identifiers("Hsa/jun2011").tsv(:persist => false, :key_field => "Entrez Gene ID", :fields => [], :grep => '^#\|PCDH', :type => :list, :persit_update => true).add_field("Cluster"){ "Cadherin" }.keys.each do |gene|
    RENAMES[gene] = "Cadherin"
  end

  input :list, :array, "KEGG Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.kegg_enrichment(list, cutoff, fdr, background, fix_clusters)
    KEGG.gene_pathway.tsv(:persist => true).enrichment(list, "KEGG Pathway ID", :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? RENAMES : nil))
  end
  task :kegg_enrichment=> :tsv
  export_synchronous :kegg_enrichment

  input :organism, :string, "Organism code", "Hsa"
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.biotype_enrichment(organism, list, cutoff, fdr, background, fix_clusters)
    res = Organism.gene_biotype(organism).tsv(:persist => true).enrichment(list, "Biotype", :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? RENAMES : nil))
    res.namespace = organism
    res
  end
  task :biotype_enrichment=> :tsv
  export_synchronous :biotype_enrichment


  input :organism, :string, "Organism code", "Hsa"
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.go_bp_enrichment(organism, list, cutoff, fdr, background, fix_clusters)
    res = Organism.gene_go_bp(organism).tsv(:persist => true).enrichment(list, "GO ID", :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? RENAMES : nil))
    res.namespace = organism
    res
  end
  task :go_bp_enrichment=> :tsv
  export_synchronous :go_bp_enrichment

  input :organism, :string, "Organism code", "Hsa"
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.go_cc_enrichment(organism, list, cutoff, fdr, background, fix_clusters)
    res = Organism.gene_go_cc(organism).tsv(:persist => true).enrichment(list, "GO ID", :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background)
    res.namespace = organism
    res
  end
  task :go_cc_enrichment=> :tsv
  export_synchronous :go_cc_enrichment


  input :organism, :string, "Organism code", "Hsa"
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.go_mf_enrichment(organism, list, cutoff, fdr, background, fix_clusters)
    res = Organism.gene_go_mf(organism).tsv(:persist => true).enrichment(list, "GO ID", :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background)
    res.namespace = organism
    res
  end
  task :go_mf_enrichment=> :tsv
  export_synchronous :go_mf_enrichment


  input :organism, :string, "Organism code", "Hsa"
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.pfam_enrichment(organism, list, cutoff, fdr, background, fix_clusters)
    res = Organism.gene_pfam(organism).tsv(:persist => true).enrichment(list, "Pfam Domain", :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? RENAMES : nil))
    res.namespace = organism
    res
  end
  task :pfam_enrichment=> :tsv
  export_synchronous :pfam_enrichment


  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.reactome_enrichment(list, cutoff, fdr, background, fix_clusters)
    pathways = NCI.reactome_pathways.tsv :key_field => "UniProt/SwissProt Accession", :fields => ["NCI Reactome Pathway ID"], :persist => true, :merge => true, :type => :flat
    res = pathways.enrichment list, "NCI Reactome Pathway ID", :cutoff => 0.1, :fdr => true, :background => background, :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr
  end
  task :reactome_enrichment=> :tsv
  export_synchronous :reactome_enrichment

  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.biocarta_enrichment(list, cutoff, fdr, background, fix_clusters)
    pathways = NCI.biocarta_pathways.tsv :key_field => "Entrez Gene ID", :fields => ["NCI BioCarta Pathway ID"], :persist => true, :merge => true, :type => :flat
    pathways.enrichment list, "NCI BioCarta Pathway ID", :cutoff => 0.1, :fdr => true, :background => background, :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr
  end
  task :biocarta_enrichment=> :tsv
  export_synchronous :biocarta_enrichment
  
  input :list, :array, "Ensembl Gene ID"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.nature_enrichment(list, cutoff, fdr, background, fix_clusters)
    pathways = NCI.nature_pathways.tsv :key_field => "UniProt/SwissProt Accession", :fields => ["NCI Nature Pathway ID"], :persist => true, :merge => true, :type => :flat
    pathways.enrichment list, "NCI Nature Pathway ID", :cutoff => 0.1, :fdr => true, :background => background, :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr
  end
  task :nature_enrichment=> :tsv
  export_synchronous :nature_enrichment

  input :database, :string, "Database code: Kegg, Nature, Reactome, BioCarta, GO_BP, GO_CC, GO_MF"
  input :list, :array, "Gene list in any supported format; they will be translated acordingly"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  def self.enrichment(database, list, organism, cutoff = 0.05, fdr = true, background = nil, fix_clusters = true)
    ensembl    = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact.uniq
    background = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => background, :organism => organism).run.compact.uniq if background and background.any?
    Gene.setup(ensembl, "Ensembl Gene ID", "Hsa")
    Gene.setup(background, "Ensembl Gene ID", "Hsa") if background
    case database.to_s.downcase
    when "kegg"
      background = background.to_kegg.compact.uniq if background and not background.empty?
      res = Enrichment.kegg_enrichment(ensembl.to_kegg.compact, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "KEGG Gene ID", :fields => ["p-value", "KEGG Pathway ID"]) unless TSV === res
      res.namespace = organism
      res

    when "go", "go bp", "go_bp"
      res = Enrichment.go_bp_enrichment(organism, ensembl, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "Ensembl Gene ID", :fields => ["p-value", "GO Term ID"]) unless TSV === res
      res.namespace = organism
      res
      
    when "biotype"
      res = Enrichment.biotype_enrichment(organism, ensembl, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "Ensembl Gene ID", :fields => ["p-value", "Biotype"]) unless TSV === res
      res.namespace = organism
      res

    when "go mf", "go_mf"
      res = Enrichment.go_mf_enrichment(organism, ensembl, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "Ensembl Gene ID", :fields => ["p-value", "GO Term ID"]) unless TSV === res
      res.namespace = organism
      res

    when "go cc", "go_cc"
      res = Enrichment.go_cc_enrichment(organism, ensembl, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "Ensembl Gene ID", :fields => ["p-value", "GO Term ID"]) unless TSV === res
      res.namespace = organism
      res
 
    when "reactome"
      genes = Organism.identifiers(organism).tsv(:key_field => "Ensembl Gene ID", :fields => ["UniProt/SwissProt Accession"], :type => :flat, :persist => true).values_at(*ensembl).compact.flatten.uniq
      background = Organism.identifiers(organism).tsv(:key_field => "Ensembl Gene ID", :fields => ["UniProt/SwissProt Accession"], :type => :flat, :persist => true).values_at(*background).compact.flatten.uniq if background
      res = Enrichment.reactome_enrichment(genes, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "UniProt/SwissProt Accession", :fields => ["p-value", "NCI Reactome Pathway ID"]) unless TSV === res
      res.namespace = organism
      res
    when "nature"
      genes = Organism.identifiers(organism).tsv(:key_field => "Ensembl Gene ID", :fields => ["UniProt/SwissProt Accession"], :type => :flat, :persist => true).values_at(*ensembl).compact.flatten.uniq
      background = Organism.identifiers(organism).tsv(:key_field => "Ensembl Gene ID", :fields => ["UniProt/SwissProt Accession"], :type => :flat, :persist => true).values_at(*background).compact.flatten.uniq if background
      res = Enrichment.nature_enrichment(genes, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "UniProt/SwissProt Accession", :fields => ["p-value", "NCI Nature Pathway ID"]) unless TSV === res
      res.namespace = organism
      res
    when "biocarta"
      background = background.entrez.compact if background and not background.empty?
      res = Enrichment.biocarta_enrichment(ensembl.entrez.compact, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "Entrez Gene ID", :fields => ["p-value", "NCI Biocarta Pathway ID"]) unless TSV === res
      res.namespace = organism
      res
    when "pfam"
      res = Enrichment.pfam_enrichment(organism, ensembl, cutoff, fdr, background, fix_clusters)
      TSV.setup(res, :key_field => "Ensembl Gene ID", :fields => ["p-value", "Pfam Domain ID"]) unless TSV === res
      res.namespace = organism
      res
    else
      raise "Unknown database code: #{ database }"
    end
  end
  task :enrichment => :tsv
  export_synchronous :enrichment

  input :database, :string, "Database code: Kegg, Nature, Reactome, BioCarta, GO_BP, GO_CC, GO_MF"
  input :list, :array, "Gene list in the appropriate format"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :permutations, :integer, "Number of permutations to find pvalue", 1000
  def self.rank_enrichment(database, list, organism, cutoff, fdr, permutations)
    ensembl = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact
    Gene.setup(ensembl, "Ensembl Gene ID", "Hsa")
    case database.to_s.downcase
    when "kegg"

      enrichment = KEGG.gene_pathway.tsv(:persist => true, :key_field => "KEGG Pathway ID", :fields => ["KEGG Gene ID"], :merge => true, :type => :flat).
        rank_enrichment(ensembl.to_kegg.clean_annotations.compact, :fdr => fdr, :permutations => permutations, :cutoff => cutoff)

      res = enrichment.select("p-value"){|pvalue| pvalue and (Array === pvalue ? (pvalue.any? and pvalue.first < cutoff) : pvalue < cutoff)}

      res.namespace = organism
      res

    when "go", "go bp", "go_bp"
      res = Organism.gene_go_bp(organism).tsv(:persist => true, :key_field => "GO ID", :fields => ["Ensembl Gene ID"], :merge => true, :type => :flat).
        rank_enrichment(ensembl.clean_annotations, :fdr => fdr, :permutations => permutations, :cutoff => cutoff).select("p-value"){|pvalue| pvalue and pvalue < cutoff}

      res = enrichment.select("p-value"){|pvalue| pvalue and pvalue.any? and pvalue.first < cutoff}

      res.namespace = organism
      res
     
    else
      raise "Unknown database code: #{ database }"
    end
  end
  task :rank_enrichment=> :tsv
  export_synchronous :rank_enrichment
end
