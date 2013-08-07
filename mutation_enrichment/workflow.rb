require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/statistics/random_walk'

Workflow.require_workflow 'Genomics'
Workflow.require_workflow 'TSVWorkflow'

require 'rbbt/entity/gene'
require 'rbbt/entity/genomic_mutation'

require 'rbbt/association'
require 'rbbt/gene_associations'

module MutationEnrichment
  extend Workflow

  DATABASES = Association.databases.keys

  helper :database_info do |database, organism|
    @@databases ||= {}
    @@databases[database] ||= {}
    @@databases[database][organism] ||= begin
      file, options = Association.databases[database]
      options[:fields] ||= [1]
      options ||= {}
      association = Association.open(file, options.merge(:namespace => organism, :source_type => "Ensembl Gene ID", :target_type => "Ensembl Gene ID", :type => :flat))
      [association, association.keys, association.key_field, association.fields.first]
    end
  end

  #{{{ BASE AND GENE COUNTS
  input :masked_genes, :array, "Ensembl Gene ID list of genes to mask", []
  input :organism, :string, "Organism code", "Hsa"
  task :pathway_base_counts => :tsv do |masked_genes, organism|
    database = clean_name
    log :loading_genes, "Loading genes from #{ database } #{ organism }"

    tsv, total_genes, gene_field, pathway_field = database_info database, organism

    total_genes = total_genes.ensembl.compact.uniq

    tsv = tsv.reorder pathway_field, [gene_field]

    tsv.namespace = organism

    counts = TSV.setup({}, :key_field => tsv.key_field, :fields => ["Bases"], :type => :single, :cast => :to_i, :namespace => organism)

    log :processing_database, "Processing database #{database}"
    tsv.with_monitor :desc => "Computing exon bases for pathways" do
      tsv.through do |pathway, genes|
        next if genes.nil? or genes.empty? 
        size = Gene.gene_list_exon_bases(genes.ensembl.compact.uniq.remove(masked_genes))
        counts[pathway] = size
      end
    end

    log :computing_exome_size, "Computing number of exome bases covered by pathway annotations"
    total_size = Gene.gene_list_exon_bases(total_genes.remove(masked_genes))

    set_info :total_size, total_size
    set_info :total_gene_list, total_genes.remove(masked_genes).clean_annotations

    counts
  end

  input :masked_genes, :array, "Ensembl Gene ID list of genes to mask", []
  input :organism, :string, "Organism code"
  task :pathway_gene_counts => :tsv do |masked_genes,organism|
    database = clean_name

    tsv, total_genes, gene_field, pathway_field = database_info database, organism

    tsv = tsv.reorder pathway_field, [gene_field]

    tsv.namespace = organism

    counts = TSV.setup({}, :key_field => tsv.key_field, :fields => ["Genes"], :type => :single, :cast => :to_i, :namespace => organism)

    tsv.through do |pathway, genes|
      next if genes.nil? or genes.empty? 
      genes = genes.ensembl.remove(masked_genes)
      num = genes.length
      counts[pathway] = num
    end

    set_info :total_genes, total_genes.remove(masked_genes).length
    set_info :total_gene_list, total_genes.remove(masked_genes).clean_annotations

    counts
  end

  #{{{ Mutation enrichment
   
  dep do |jobname, inputs| job(inputs[:baseline] || :pathway_base_counts, inputs[:database].to_s, inputs) end
  input :database, :select, "Database code", nil, :select_options => DATABASES
  input :baseline, :select, "Type of baseline to use", :pathway_base_counts, :select_options => [:pathway_base_counts, :pathway_gene_counts]
  input :mutations, :array, "Genomic Mutation"
  input :fdr, :boolean, "BH FDR corrections", true
  input :masked_genes, :array, "Ensembl Gene ID list of genes to mask", []
  input :organism, :string, "Organism code", "Hsa"
  input :watson, :boolean, "Alleles reported in the watson (forward) strand", true
  task :mutation_pathway_enrichment => :tsv do |database,baseline,mutations,fdr,masked_genes,organism, watson|
    counts        = step(baseline).load
    total_covered = step(baseline).info[:total_size] || step(baseline).info[:total_genes]
    GenomicMutation.setup(mutations, "MutationEnrichment", organism, watson)


    affected_genes = mutations.genes.compact.flatten.uniq

    # Get database tsv and native ids

    database_tsv, all_db_genes, db_gene_field = database_info database, organism

    affected_genes = affected_genes.remove(masked_genes)
    affected_genes_db = affected_genes.to db_gene_field
    all_db_genes = all_db_genes.ensembl.remove(masked_genes).compact.sort

    affected_genes_db = affected_genes_db.clean_annotations

    # Annotate each pathway with the affected genes that are involved in it

    log :pathway_matches, "Finding affected genes per pathway"
    affected_genes_per_pathway = {}
    database_tsv.with_unnamed do
      affected_genes_db.zip(affected_genes.clean_annotations).each do |gene_db,gene|
        next if gene_db.nil?
        pathways = database_tsv[gene_db]
        next if pathways.nil?
        pathways.uniq.each do |pathway|
          affected_genes_per_pathway[pathway] ||= []
          affected_genes_per_pathway[pathway] << gene
        end
      end
    end

    log :mutation_genes, "Finding genes overlapping mutatiosn"
    mutation_genes = {}
    gene_mutations = {}
    mutations.genes.zip(mutations.clean_annotations).each do |genes, mutation|
      mutation_genes[mutation] = genes.sort
      genes.each do |gene|
        gene_mutations[gene] ||= []
        gene_mutations[gene] << mutation
      end
    end
    mutations = mutations.clean_annotations

    log :covered_mutations, "Finding mutations overlapping genes in pathway"
    covered_mutations = mutations.select{|mutation| Misc.intersect_sorted_arrays(mutation_genes[mutation].dup, all_db_genes.dup).any? }.length
    set_info :covered_mutations, covered_mutations

    log :pvalue, "Calculating binomial pvalues"
    pvalues = TSV.setup({}, :key_field => database_tsv.fields.first, :fields => ["Matches", "Pathway total", "p-value", "Ensembl Gene ID"], :namespace => organism, :type => :double)
    counts.unnamed = true
    affected_genes_per_pathway.each do |pathway, genes|
      pathway_total = counts[pathway]
      #matches = mutations.select{|mutation| Misc.intersect_sorted_arrays(mutation_genes[mutation], genes.sort).any? }.length
      matches = gene_mutations.values_at(*genes).compact.flatten.length
      pvalue = RSRuby.instance.binom_test(matches, covered_mutations, pathway_total.to_f / total_covered.to_f, "greater")["p.value"]

      common_genes = affected_genes.subset(genes).uniq
      pvalues[pathway] = [[matches], [pathway_total], [pvalue], common_genes.sort_by{|g| g.name || g}]
    end

    FDR.adjust_hash! pvalues, 2 if fdr

    set_info :total_covered, total_covered

    pvalues
  end
  export_asynchronous :mutation_pathway_enrichment

  #{{{ Sample enrichment
  
  dep do |jobname, inputs| job(inputs[:baseline], inputs[:database].to_s, inputs) end
  input :database, :select, "Database code", nil, :select_options => DATABASES
  input :baseline, :select, "Type of baseline to use", :pathway_base_counts, :select_options => [:pathway_base_counts, :pathway_gene_counts]
  input :mutations, :tsv, "Genomic Mutation and Sample. Example row: '10:12345678:A{TAB}Sample01{TAB}Sample02'"
  input :permutations, :integer, "Number of permutations in test", 10000
  input :fdr, :boolean, "BH FDR corrections", true
  input :masked_genes, :array, "Ensembl Gene ID list of genes to mask", []
  input :organism, :string, "Organism code", "Hsa"
  input :watson, :boolean, "Alleles reported in the watson (forward) strand", true
  task :sample_pathway_enrichment => :tsv do |database,baseline,mutations,permutations,fdr,masked_genes,organism,watson|
    pathway_counts                         = step(baseline).load
    total_covered                          = step(baseline).info[:total_size] || step(baseline).info[:total_genes]
    total_pathway_genes_list               = step(baseline).info[:total_gene_list]

    mutations.extend TSV unless TSV === mutations

    if mutations.fields.nil?
      mutations.key_field = "Genomic Mutation"
      mutations.fields = ["Sample"]
      mutations.type = :double
    end

    database_g2p, all_db_genes, gene_field, pathway_field = database_info database, organism

    all_db_genes = all_db_genes.ensembl

    database_p2g = database_g2p.reorder pathway_field, [gene_field]

    all_mutations = GenomicMutation.setup(mutations.keys, "MutationEnrichment", organism, watson)
    mutation_genes = Misc.process_to_hash(all_mutations){|all_mutations| all_mutations.genes}

    affected_samples_per_pathway = TSV.setup({}, :key_field => pathway_field, :fields => ["Sample"], :type => :flat)
    covered_genes_per_samples = {}
    all_samples = []
    sample_mutation_tokens = []
    covered_mutations = []
    log :classify, "Classifying mutations by pathway"
    mutations.slice("Sample").each do |mutation,samples|
      samples = [samples] unless Array === samples
      samples = samples.flatten

      next if mutation_genes[mutation].nil? or mutation_genes[mutation].empty?
      pathways = database_g2p.values_at(*(mutation_genes[mutation].to(gene_field))).compact.flatten.compact
      next if pathways.empty?
      pathways.each do |pathway|
        affected_samples_per_pathway[pathway] ||= []
        affected_samples_per_pathway[pathway].concat samples
      end
      samples.each do |sample|
        covered_genes_per_samples[sample] ||= []
        covered_genes_per_samples[sample].concat mutation_genes[mutation] unless mutation_genes[mutation].nil?
      end
      all_samples.concat samples

      if (mutation_genes[mutation] & all_db_genes).any?
        sample_mutation_tokens.concat samples
        covered_mutations << mutation
      end
    end

    affected_genes = mutation_genes.values.compact.flatten.uniq

    set_info :covered_mutations, covered_mutations.length

    pathways = pathway_counts.keys

    pathway_expected_counts = {}
    log :expected_counts, "Calculating expected counts"
    pathway_counts.with_monitor :desc => "Calculating expected counts" do
      pathway_counts.with_unnamed do
        affected_samples_per_pathway.with_unnamed do
          pathway_counts.through do |pathway, count|
            next unless affected_samples_per_pathway.include?(pathway) and affected_samples_per_pathway[pathway].any?
            ratio = count.to_f / total_covered
            num_token_list = RSRuby.instance.rbinom(permutations, sample_mutation_tokens.length, ratio)
            pathway_expected_counts[pathway] = num_token_list.collect{|num_tokens|
              # Add 1 to estabilize estimates
              Misc.sample(sample_mutation_tokens, num_tokens.to_i).uniq.length + 1
            }
          end
        end
      end
    end

    tsv = TSV.setup({}, :key_field => affected_samples_per_pathway.key_field, :fields => ["Sample", "Matches", "Expected", "Ratio", "Pathway total", "p-value", "Ensembl Gene ID"], :namespace => organism, :type => :double)
    log :pvalues, "Comparing observed vs expected counts"
    affected_samples_per_pathway.through do |pathway, samples|
      next unless samples.any?
      next unless pathway_expected_counts.include? pathway
      pathway_genes = database_p2g[pathway].ensembl
      samples = samples.uniq.select{|sample| (covered_genes_per_samples[sample] & pathway_genes).any?}
      # Add 1 to estabilize estimates
      count = samples.length
      expected = Misc.mean(pathway_expected_counts[pathway]).floor
      pvalue = pathway_expected_counts[pathway].select{|exp_c| exp_c > count}.length.to_f / permutations
      tsv[pathway] = [samples.sort, [count], [expected], [count.to_f / expected], [pathway_counts[pathway]], [pvalue], pathway_genes.subset(affected_genes)]
    end

    FDR.adjust_hash! tsv, 5 if fdr

    set_info :total_covered, total_covered

    tsv
  end
  export_asynchronous :sample_pathway_enrichment
end
