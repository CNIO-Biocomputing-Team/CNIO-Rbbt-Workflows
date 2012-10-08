require 'rbbt'
require 'rbbt/tsv'
require 'rbbt/workflow'
require 'rbbt/GE'

YAML::ENGINE.yamler = 'syck' if defined? YAML::ENGINE and YAML::ENGINE.respond_to? :yamler

module Expression
  extend Workflow

  input :data_file, :string, "Data matrix"
  input :identifier_file, :string, "Identifier equivalence table", nil
  input :identifier_format, :string, "Identifier format to use", nil
  input :organism, :string, "Organism code", "Hsa"
  def self.load_matrix(data_file, identifier_file, identifier_format, organism)
    log :open_data, "Opening data file"
    data = TSV.open(data_file, :type => :double, :unnamed => true)

    organism ||= data.namespace

   
    if not (identifier_file.nil? or identifier_format.nil? or data.key_field == identifier_format)

      case
      when (fields = (TSV.parse_header(Open.open(identifier_file)).fields) and fields.include?(identifier_format))
        log :attach, "Adding #{ identifier_format } from #{ identifier_file }"
        data = data.attach identifier_file, :fields => [identifier_format]
        log :reorder, "Reordering data fields"
        data = data.reorder identifier_format, data.fields.dup.delete_if{|field| field == identifier_format}
      else
        raise "No organism defined and identifier_format did not match available formats" if organism.nil?
        require 'rbbt/sources/organism'
        organism_identifiers = Organism.identifiers(organism)
        data.identifiers = identifier_file
        log :attach, "Adding #{ identifier_format } from #{ organism_identifiers }"
        data = data.attach organism_identifiers, :fields => [identifier_format]
        log :reorder, "Reordering data fields"
        data = data.reorder identifier_format, data.fields.dup.delete_if{|field| field == identifier_format}
        data
      end

      new_data = TSV.setup({}, :key_field => data.key_field, :fields => data.fields, :type => :list, :cast => :to_f, :namespace => organism, :unnamed => true)
      log :averaging, "Averaging multiple values"
      data.with_unnamed do
        data.through do |key, values|
          new_data[key] = values.collect{|list| Misc.mean(list.collect{|v| v.to_f})}
        end
      end

      data = new_data
    end

    data
  end
  task :load_matrix => :tsv 

  input :matrix_file, :string, "Sample matrix"
  input :samples, :array, "Samples to average"
  def self.average_samples(matrix_file, samples)
    matrix = TSV.open(matrix_file)
    new = TSV.setup({}, :key_field => matrix.key_field, :fields => matrix.fields, :cast => matrix.cast, :namespace => matrix.namespace)
    positions = samples.collect{|sample| matrix.identify_field sample}.compact
    matrix.with_unnamed do
      matrix.through do |key,values|
        new[key] = Misc.mean(values.values_at(*positions).compact)
      end
    end

    new
  end
  task :average_samples => :tsv

  input :matrix_file, :string, "Sample matrix"
  input :main, :array, "Samples to average"
  input :contrast, :array, "Samples to average"
  input :log2, :boolean, "Perform log2 correction", false
  input :two_channel, :boolean, "Two channel expression data", false
  def self.differential(matrix_file, main, contrast, log2, two_channel)
    header = TSV.parse_header(Open.open(matrix_file))
    key_field, *fields = header.all_fields
    namespace = header.namespace

    main = main & fields
    contrast = contrast & fields

    if Step === self
      GE.analyze(matrix_file, main, contrast, log2, path, key_field, two_channel)
      TSV.open(path, :type => :list, :cast => :to_f, :namespace => namespace)
    else
      TmpFile.with_file do |path|
        GE.analyze(matrix_file, main, contrast, log2, path, key_field, two_channel)
        TSV.open(path, :type => :list, :cast => :to_f, :namespace => namespace)
      end
    end
  end
  task :differential => :tsv


end

if __FILE__ == $0
  Workflow.require_workflow "StudyExplorer"
  Workflow.require_workflow "Circos"

  cll = Study.setup("CLL")
  organism = cll.metadata[:organism]

  data_file = cll.dir.gene_expression.data
  identifier_file = cll.dir.gene_expression.identifiers

  #data_file = cll.dir.rnaseq["Trans.Expression.Enc7CLL.txt"].find
  #identifier_file = Organism.gene_transcripts(organism).find

  matrix = Expression.job(:load_matrix, "test", :data_file => data_file, :identifier_file => identifier_file, :identifier_format => "Ensembl Gene ID", :organism => organism).run(true).path

  samples = cll.samples
  main_samples = samples.select("Tumor Status" => "Tumor").keys
  contrast_samples = samples.select("Tumor Status" => "Normal").keys

  main_samples = samples.select("IGHV Status" => "Mutated").keys
  contrast_samples = samples.select("IGHV Status" => "Unmutated").keys

  main_values = Expression.job(:average_samples, "test", :matrix_file => matrix, :samples => main_samples).run(true).path
  contrast_values = Expression.job(:average_samples, "test", :matrix_file => matrix, :samples => contrast_samples).run(true).path

  main_values_ranges = Circos.job(:gene_ranges, "test", :value_file => main_values).run(true).path
  contrast_values_ranges = Circos.job(:gene_ranges, "test", :value_file => contrast_values).run(true).path

  main_plot = Circos.plot(main_values_ranges, "color" => 'ylorrd-9-seq')
  contrast_plot = Circos.plot(contrast_values_ranges, "color" => 'ylorrd-9-seq')

  mutation_counts = TSV.({}, :key_field => "Ensembl Gene ID", :fields => ["Mutation Counts"], :type => :single, :cast => :to_f)
  cll.job(:relevant_genes, cll).run.each do |gene|
    mutation_counts[gene] ||= 0.0
  end
  mutation_count_ranges = Circos.job(:gene_ranges, "test", :value_file => mutation_counts).run(true).path

  mutation_plot = Circos.plot(mutation_count_ranges, "color" => 'ylorrd-9-seq')

  plot_path = Circos.job(:circos, "test", :plots => [main_plot, contrast_plot]).clean.run(true).file('img/image.png')

  puts plot_path
end
