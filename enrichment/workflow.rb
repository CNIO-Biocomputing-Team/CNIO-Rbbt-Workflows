require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/statistics/random_walk'

Workflow.require_workflow 'Genomics'

require 'rbbt/entity'
require 'rbbt/entity/gene'
require 'rbbt/sources/organism'
require 'rbbt/sources/kegg'
require 'rbbt/sources/go'
require 'rbbt/sources/reactome'
require 'rbbt/sources/NCI'
require 'rbbt/sources/InterPro'

Workflow.require_workflow 'Translation'
Workflow.require_workflow 'TSVWorkflow'

module Enrichment
  extend Workflow
  extend Resource


  MASKED_TERMS = %w(cancer melanoma carcinoma glioma hepatitis leukemia leukaemia disease infection opathy hepatitis sclerosis hepatatis glioma Shigellosis)
  MASKED_IDS = {}

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

  DATABASES = %w(kegg go go_bp go_mf go_cc interpro pfam reactome nature biocarta)

  helper :database_info do |database, organism|

    case database.to_s
    when 'kegg'
      database_tsv = KEGG.gene_pathway.tsv :key_field => 'KEGG Gene ID', :fields => ["KEGG Pathway ID"], :type => :double, :persist => true, :unnamed => false, :merge => true
      all_db_genes = Gene.setup(database_tsv.keys, "KEGG Gene ID", organism).uniq
    when 'go'
      database_tsv = Organism.gene_go(organism).tsv :key_field => "Ensembl Gene ID", :fields => ["GO ID"], :type => :double, :persist => true, :unnamed => false, :merge => true
      all_db_genes = Gene.setup(database_tsv.keys, "Ensembl Gene ID", organism).uniq
    when 'go_bp'
      database_tsv = Organism.gene_go_bp(organism).tsv :key_field => "Ensembl Gene ID", :fields => ["GO ID"], :type => :double, :persist => true, :unnamed => false, :merge => true
      all_db_genes = Gene.setup(database_tsv.keys, "Ensembl Gene ID", organism).uniq
    when 'go_mf'
      database_tsv = Organism.gene_go_mf(organism).tsv :key_field => "Ensembl Gene ID", :fields => ["GO ID"], :type => :double, :persist => true, :unnamed => false, :merge => true
      all_db_genes = Gene.setup(database_tsv.keys, "Ensembl Gene ID", organism).uniq
    when 'go_cc'
      database_tsv = Organism.gene_go_cc(organism).tsv :key_field => "Ensembl Gene ID", :fields => ["GO ID"], :type => :double, :persist => true, :unnamed => false, :merge => true
      all_db_genes = Gene.setup(database_tsv.keys, "Ensembl Gene ID", organism).uniq
    when 'interpro'
      database_tsv = InterPro.protein_domains.tsv :key_field => "UniProt/SwissProt Accession", :fields => ["InterPro ID"], :type => :double, :persist => true, :unnamed => false, :merge => true
      all_db_genes = Gene.setup(database_tsv.keys, "UniProt/SwissProt Accession", organism).uniq
    when 'pfam'
      database_tsv = Organism.gene_pfam(organism).tsv :key_field => "Ensembl Gene ID", :fields => ["Pfam Domain"], :type => :double, :persist => true, :unnamed => false, :merge => true
      all_db_genes = Gene.setup(database_tsv.keys, "Ensembl Gene ID", organism).uniq
    when 'reactome'
      database_tsv = Reactome.protein_pathways.tsv :key_field => "UniProt/SwissProt Accession", :fields => ["Reactome Pathway ID"], :persist => true, :merge => true, :type => :double, :unnamed => false
      all_db_genes = Gene.setup(database_tsv.keys, "UniProt/SwissProt Accession", organism).uniq
    when 'nature'
      database_tsv = NCI.nature_pathways.tsv :key_field => "UniProt/SwissProt Accession", :fields => ["NCI Nature Pathway ID"], :persist => true, :merge => true, :type => :double, :unnamed => false
      all_db_genes = Gene.setup(database_tsv.keys, "UniProt/SwissProt Accession", organism).uniq
    when 'biocarta'
      database_tsv = NCI.biocarta_pathways.tsv :key_field => "Entrez Gene ID", :fields => ["NCI BioCarta Pathway ID"], :persist => true, :merge => true, :type => :double, :unnamed => false
      all_db_genes = Gene.setup(database_tsv.keys, "Entrez Gene ID", organism).uniq
    else
      raise "Database #{ database } not recognized"
    end

    [database_tsv, all_db_genes, database_tsv.key_field, database_tsv.fields.first]
  end

  input :database, :select, "Database code: #{DATABASES * ", "}", nil, :select_options => DATABASES
  input :list, :array, "Gene list in any supported format; they will be translated acordingly"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :invert_background, :boolean, "Restrict to elements NOT in background"
  input :mask_diseases, :boolean, "Mask disease related terms", true
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  task :enrichment => :tsv do |database, list, organism, cutoff, fdr, background, invert_background, mask_diseases, fix_clusters|
    ensembl    = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact.uniq
    background = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => background, :organism => organism).run.compact.uniq if background and background.any?
    Gene.setup(ensembl, "Ensembl Gene ID", "Hsa")
    Gene.setup(background, "Ensembl Gene ID", "Hsa") if background

    database_tsv, all_db_genes, database_key_field, database_field = database_info database, organism

    if database_key_field != "Ensembl Gene ID"
      database_tsv = TSVWorkflow.job(:change_id, "Enrichment", :tsv => database_tsv, :format => "Ensembl Gene ID", :organism => organism).run
      all_db_genes = all_db_genes.to("Ensembl Gene ID").compact.uniq
    end

    if invert_background and background
      background = all_db_genes - background
    end

    if mask_diseases
      Log.debug("Masking #{MASKED_TERMS * ", "}")
      masked = (MASKED_IDS[database] ||= Misc.prepare_entity(database_tsv.values.flatten.uniq, database_field).select{|t| t.name =~ /#{MASKED_TERMS * "|"}/i})
    else
      masked = nil
    end

    database_tsv.enrichment(ensembl, database_field, :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? Enrichment::RENAMES : nil), :masked => masked).tap{|tsv| tsv.namespace = organism}
  end
  export_synchronous :enrichment

  input :database, :string, "Database code: Kegg, Nature, Reactome, BioCarta, GO_BP, GO_CC, GO_MF"
  input :list, :array, "Gene list in any supported format; they will be translated acordingly"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  input :permutations, :integer, "Number of permutations used to compute p.value", 10000
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  task :rank_enrichment => :tsv do |database, list, organism, permutations, cutoff, fdr, background, fix_clusters|
    ensembl    = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact.uniq
    background = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => background, :organism => organism).run.compact.uniq if background and background.any?
    Gene.setup(ensembl, "Ensembl Gene ID", "Hsa")
    Gene.setup(background, "Ensembl Gene ID", "Hsa") if background

    database_tsv, all_db_genes, database_key_field, database_field = database_info database, organism

    if database_key_field != "Ensembl Gene ID"
      database_tsv = TSVWorkflow.job(:change_id, "Enrichment", :tsv => database_tsv, :format => "Ensembl Gene ID", :organism => organism).exec
      all_db_genes = all_db_genes.to("Ensembl Gene ID").compact.uniq
    end

    database_tsv = database_tsv.reorder database_field

    missing = (all_db_genes - list).length

    cutoff = cutoff.to_f
    database_tsv.rank_enrichment(ensembl, :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? RENAMES : nil), :permutations => permutations, :persist_permutations => true, :missing => missing).select("p-value"){|p| p.to_f <= cutoff}.tap{|tsv| tsv.namespace = organism}
  end
  export_asynchronous :rank_enrichment


end
