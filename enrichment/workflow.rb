require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/statistics/random_walk'

Workflow.require_workflow 'Genomics'

require 'rbbt/association'
require 'rbbt/gene_associations'

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

  DATABASES = Association.databases.keys

  helper :database_info do |database, organism|
    @@databases ||= {}
    @@databases[database] ||= {}
    @@databases[database][organism] ||= begin
      file, options = Association.get_database(database)
      open_options = options.merge(:namespace => organism, :source_type => "Ensembl Gene ID", :target_type => "Ensembl Gene ID")
      open_options = open_options.merge(:grep => Organism.blacklist_genes(organism).produce.list, :invert_grep => true)
      association = Association.open(file, open_options)
      [association, association.keys, association.key_field, association.fields.first]
    end
  end

  input :database, :select, "Database code", nil, :select_options => DATABASES
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

    if invert_background and background
      background = all_db_genes - background
    end

    if mask_diseases and not Gene == Entity.formats[database_field]
      Log.debug("Masking #{MASKED_TERMS * ", "}")
      masked = MASKED_IDS[database] ||= database_tsv.with_unnamed do
        terms = database_tsv.values.flatten.uniq
        terms = Misc.prepare_entity(terms, database_field)
        if terms.respond_to? :name
          terms.select{|t| t.name =~ /#{MASKED_TERMS * "|"}/i}
        else
          masked = nil
        end
      end
    else
      masked = nil
    end

    database_tsv = database_tsv.to_flat

    database_tsv.enrichment(ensembl, database_field, :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? Enrichment::RENAMES : nil), :masked => masked).tap{|tsv| tsv.namespace = organism}
  end
  export_synchronous :enrichment

  input :database, :select, "Database code", nil, :select_options => DATABASES
  input :list, :array, "Gene list in any supported format; they will be translated acordingly"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  input :permutations, :integer, "Number of permutations used to compute p.value", 10000
  input :cutoff, :float, "Cufoff value", 0.05
  input :fdr, :boolean, "Perform Benjamini-Hochberg FDR correction", true
  input :background, :array, "Enrichment background", nil
  input :mask_diseases, :boolean, "Mask disease related terms", true
  input :fix_clusters, :boolean, "Fixed dependence in gene clusters", true
  input :count_missing, :boolean, "Account for genes with pathway annotations that are missing in list", false
  task :rank_enrichment => :tsv do |database, list, organism, permutations, cutoff, fdr, background, mask_diseases, fix_clusters, count_missing|
    ensembl    = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact.uniq
    background = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => background, :organism => organism).run.compact.uniq if background and background.any?
    Gene.setup(ensembl, "Ensembl Gene ID", "Hsa")
    Gene.setup(background, "Ensembl Gene ID", "Hsa") if background

    database_tsv, all_db_genes, database_key_field, database_field = database_info database, organism

    #if database_key_field != "Ensembl Gene ID"
    #  database_tsv = TSVWorkflow.job(:change_id, "Enrichment", :tsv => database_tsv, :format => "Ensembl Gene ID", :organism => organism).exec
    #  all_db_genes = all_db_genes.to("Ensembl Gene ID").compact.uniq
    #end

    if mask_diseases and not Gene == Entity.formats[database_field]
      Log.debug("Masking #{MASKED_TERMS * ", "}")
      masked = MASKED_IDS[database] ||= database_tsv.with_unnamed do
        terms = database_tsv.values.flatten.uniq
        terms = Misc.prepare_entity(terms, database_field)
        if terms.respond_to? :name
          terms.select{|t| t.name =~ /#{MASKED_TERMS * "|"}/i}
        else
          masked = nil
        end
      end
    else
      masked = nil
    end

    log :reordering, "Reordering database"
    database_tsv.with_unnamed do
      database_tsv.with_monitor :desc => "Reordering" do
        database_tsv = database_tsv.reorder database_field
      end
    end

    missing = (all_db_genes - list).length if count_missing

    cutoff = cutoff.to_f

    log :enrichment, "Performing enrichment"
    database_tsv = database_tsv.to_flat
    database_tsv.rank_enrichment(ensembl,  :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? RENAMES : nil), :permutations => permutations, :persist_permutations => true, :missing => missing || 0, :masked => masked).select("p-value"){|p| p.to_f <= cutoff}.tap{|tsv| tsv.namespace = organism}
  end
  export_asynchronous :rank_enrichment
end
