require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/association'
require 'rbbt/knowledge_base'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/statistics/random_walk'

Workflow.require_workflow 'Genomics'
require 'genomics_kb'

Workflow.require_workflow 'Translation'
Workflow.require_workflow 'TSVWorkflow'

module Enrichment
  extend Workflow
  extend Resource

  self.subdir = "MutationEnrichment"

  class << self
    attr_accessor :knowledge_base_dir

    def knowledge_base_dir
      @knowledge_base_dir ||= Enrichment.var.knowledge_base
    end
  end


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

  DATABASES = Genomics.knowledge_base.registry.keys

  helper :database_info do |database, organism|
    @organism_kb ||= {}
    @organism_kb[organism] ||= begin
                                 dir = Enrichment.knowledge_base_dir

                                 kb = KnowledgeBase.new dir, organism
                                 kb.format["Gene"] = "Ensembl Gene ID"
                                 kb.registry = Genomics.knowledge_base.registry
                                 kb
                               end

    db = @organism_kb[organism].get_database(database, :persist => true)

    tsv, total_keys, source_field, target_field = [db, db.keys, db.key_field, db.fields.first]

    if target_field == "Ensembl Gene ID"
      pathway_field, gene_field = source_field, target_field
      total_genes = Gene.setup(tsv.values.flatten.compact.uniq, "Ensembl Gene ID", organism)
    else
      pathway_field, gene_field = target_field, source_field
      total_genes = total_keys
    end

    tsv.namespace = organism

    [tsv, total_genes, gene_field, pathway_field]
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
    raise ParameterException, "No list given" if list.nil? or list.empty?

    ensembl    = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact.uniq
    background = Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => background, :organism => organism).run.compact.uniq if background and background.any?
    Gene.setup(ensembl, "Ensembl Gene ID", "Hsa")
    Gene.setup(background, "Ensembl Gene ID", "Hsa") if background

    database_tsv, all_db_genes, database_key_field, database_field = database_info database, organism

    if invert_background and background
      background = all_db_genes - background
    end

    log :reordering, "Reordering database"
    database_tsv.with_unnamed do
      database_tsv.with_monitor :desc => "Reordering" do
        database_tsv = database_tsv.reorder "Ensembl Gene ID"
      end
    end unless "Ensembl Gene ID" == database_field

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

    missing = (all_db_genes - list).length if count_missing

    cutoff = cutoff.to_f

    log :enrichment, "Performing enrichment"
    database_tsv = database_tsv.to_flat
    database_tsv.rank_enrichment(ensembl,  :persist => (background.nil? or background.empty?), :cutoff => cutoff, :fdr => fdr, :background => background, :rename => (fix_clusters ? RENAMES : nil), :permutations => permutations, :persist_permutations => true, :missing => missing || 0, :masked => masked).select("p-value"){|p| p.to_f <= cutoff}.tap{|tsv| tsv.namespace = organism}
  end
  export_asynchronous :rank_enrichment
end
