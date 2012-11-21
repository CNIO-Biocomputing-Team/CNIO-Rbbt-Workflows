$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))
require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/persist'
require 'rbbt/workflow'
require 'rbbt/GE/GEO'
require 'rbbt/statistics/fdr'
require 'signature'

Workflow.require_workflow "Expression"

Workflow.require_workflow "Enrichment"

require 'gene_enrichment'

class Matrix
  extend Resource
  self.subdir = "var/matrices"
  MATRIX_DIR = Matrix.root.find

  def self.geo_matrix_for(gds, key_field = nil, organism = nil)
    data    = GEO[gds].values.produce.find
    samples = GEO[gds].samples.produce.find

    dataset_info = GEO[gds]['info.yaml'].produce.yaml
    platform     = dataset_info[:platform]
    identifiers  = GEO[platform].codes.produce.find

    log2         = ["count"].include? dataset_info[:value_type]

    Matrix.new(data, identifiers, samples, key_field, organism, log2)
  end

  attr_accessor :data, :identifiers, :labels, :key_field, :organism, :samples, :log2, :channel
  def initialize(data, identifiers, labels = nil, key_field = nil, organism = nil, log2 = false, channel = false)
    @data        = data
    @samples     = TSV::Parser.new(Open.open(data)).fields
    @identifiers = identifiers
    @labels      = TSV.open(labels) unless labels.nil?
    @key_field   = key_field
    @log2        = log2
    @channel     = channel
    @organism    = organism
  end

  def matrix_file
    path = Persist.persistence_path(data, {:dir => Matrix::MATRIX_DIR}, {:identifiers => identifiers, :labels => labels, :key_field => key_field, :organism => organism})
    Persist.persist(data, :tsv, :file => path, :check => [data]) do
      Expression.load_matrix(data, identifiers, key_field, organism)
    end
    path
  end

  def average_samples(samples)
    path = Persist.persistence_path(matrix_file, {:dir => File.join(Matrix::MATRIX_DIR, 'averaged_samples')}, {:samples => samples})
    Persist.persist(data, :tsv, :file => path, :no_load => true, :check => [matrix_file]) do
      Expression.average_samples(matrix_file, samples)
    end
    path
  end

  def find_samples(value, field = nil)
    labels.select(field){|k,v|
      Array === v ? v.flatten.include?(value) : v == value
    }.keys
  end

  def remove_missing(samples)
    @samples & samples
  end

  def average_label(value, field = nil)
    samples = find_samples(value, field)
    samples = remove_missing(samples)
    average_samples(samples)
  end

  def sample_differences(main, contrast)
    path = Persist.persistence_path(matrix_file, {:dir => File.join(Matrix::MATRIX_DIR, 'sample_differences')}, {:main => main, :contrast => contrast, :log2 => log2, :channel => channel})
    Persist.persist(data, :tsv, :file => path, :no_load => true, :check => [matrix_file]) do
      Expression.differential(matrix_file, main, contrast, log2, channel)
    end
    path
  end

  def label_differences(main, contrast = nil, field = nil)
    all_samples = labels.keys
    main_samples = find_samples(main, field)
    if contrast
      contrast_samples = find_samples(contrast, field)
    else
      contrast_samples = all_samples - main_samples
    end

    main_samples = remove_missing(main_samples)
    contrast_samples = remove_missing(contrast_samples)

    sample_differences(main_samples, contrast_samples)
  end

  def signature_set(field, cast = nil)
    path = Persist.persistence_path(matrix_file, {:dir => File.join(Matrix::MATRIX_DIR, 'signature_set')}, {:field => field, :cast => cast})
    Persist.persist(data, :tsv, :file => path, :no_load => true, :check => [matrix_file]) do
      signatures = TSV.open(matrix_file, :fields => [], :type => :list, :cast => cast)
      labels.values.flatten.uniq.sort.each do |value|
        begin
          s = Signature.tsv_field(label_differences(value), field, cast)
          s.fields = [value]
          signatures.attach s
        rescue Exception
          Log.warn("Signature for #{ value } did not compute")
        end
      end
      signatures
    end
    path
  end

  def random_forest_importance(main, contrast = nil, field = nil, options = {})
    features = Misc.process_options options, :features
    features ||= []

    path = Persist.persistence_path(matrix_file, {:dir => File.join(Matrix::MATRIX_DIR, 'random_forest_importance')}, {:main => main, :contrast => contrast, :field => field, :features => features})
    Persist.persist(data, :tsv, :file => path, :no_load => false, :check => [matrix_file]) do
      all_samples = labels.keys
      main_samples = find_samples(main, field)
      if contrast
        contrast_samples = find_samples(contrast, field)
      else
        contrast_samples = all_samples - main_samples
      end


      main_samples     = remove_missing(main_samples)
      contrast_samples = remove_missing(contrast_samples)

      TmpFile.with_file do |result|
        R.run <<-EOF
library(randomForest);
orig = rbbt.tsv('#{matrix_file}');
main = c('#{main_samples * "', '"}')
contrast = c('#{contrast_samples * "', '"}')
features = c('#{features * "', '"}')

features = intersect(features, rownames(orig));
data = t(orig[features, c(main, contrast)])
data = cbind(data, Class = 0)
data[main, "Class"] = 1

rf = randomForest(factor(Class) ~ ., data, na.action = na.exclude)
rbbt.tsv.write(rf$importance, filename='#{ result }', key.field = '#{@key_field}')
        EOF

        TSV.open(result, :type => :single, :cast => :to_f)
      end
    end
  end
end

if __FILE__ == $0
  Workflow.require_workflow "StudyExplorer"
  require 'rbbt/sources/string'

  cll = Study.setup('CLL_new')
  m = cll.matrix(:gene_expression)
  relevant_genes = Gene.setup("BCL2", "Associated Gene Name", "Hsa/jun2011").string_interactors.reverse
  m.random_forest_importance("Mutated", "Unmutated", "IGHV Status", :features => relevant_genes).sort_by(nil).each{|g,s|
    puts [g.name, s] * ": "
  }

  exit
  cll = Study.setup('CLL')
  cll_gene = cll.matrix :gene_expression, "Ensembl Gene ID"
  #  m = Matrix.new(cll.dir.gene_expression.data, cll.dir.gene_expression.identifiers, cll.sample_file, "Ensembl Gene ID", "Hsa/jun2011")
  #

  #m = Matrix.new(GEO['GDS3717'].values.produce.find, nil, GEO['GDS3717'].samples.produce.find, "Ensembl Gene ID", "Hsa/jun2011")

  #exp = Signature.tsv_field(cll_gene.label_differences("Unmutated", "Mutated"), 'p.values', :to_f)
  exp = Signature.tsv_field(cll_gene.label_differences("C2", "C1"), 'p.values', :to_f)
  #up   = exp.pvalue_fdr_adjust!.select("p.values"){|p| p > 0 && p.abs < 0.0001}.keys.ortholog("Mmu/jun2011").flatten.clean_annotations.compact
  #down = exp.pvalue_fdr_adjust!.select("p.values"){|p| p < 0 && p.abs < 0.0001}.keys.ortholog("Mmu/jun2011").flatten.clean_annotations.compact
  up   = exp.pvalue_fdr_adjust!.select("p.values"){|p| p > 0 && p.abs < 0.0001}.keys.clean_annotations
  down = exp.pvalue_fdr_adjust!.select("p.values"){|p| p < 0 && p.abs < 0.0001}.keys.clean_annotations

  genes = exp.pvalue_sorted[0.100]


  geo = Matrix::geo_matrix_for('GDS3635', "Ensembl Gene ID", "Hsa/jun2011")

  set = TSV.open(geo.signature_set('p.values', :to_f), :unnamed => true)
  Log.debug "Starting comparison. Up: #{up.length}. Down: #{down.length}"
  set.fields.each do |field|
    s = Signature.tsv_field(set, field).pvalue_sorted_weights
    ddd s.hits(genes)
    ddd [field,'up', s.score(up), s.pvalue_weights(up, 0.1, :permutations => 10000)]
    ddd [field,'down', s.score(down), s.pvalue_weights(down, 0.1, :permutations => 10000)]
    ddd [field,'up', s.score(up), s.pvalue(up, 0.1, :permutations => 10000)]
    ddd [field,'down', s.score(down), s.pvalue(down, 0.1, :permutations => 10000)]
  end
end



