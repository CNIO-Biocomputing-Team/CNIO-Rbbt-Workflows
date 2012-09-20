require 'rbbt-util'
require 'rbbt/workflow'
require 'circos'

Workflow.require_workflow "StudyExplorer"

module Circos
  extend Workflow

  helper :study do
    Study.setup("CLL")
  end

  task :gene_expression => :tsv do
    tsv = study.dir.gene_expression.data.tsv :type => :list

    probe2gene = study.dir.gene_expression.identifiers.tsv

    tsv.add_field "Associated Gene Name" do |probe,values|
      probe2gene[probe].first
    end

    tsv.namespace = study.metadata[:organism]

    tsv.unnamed = true
    
    tsv.to_s
  end

  dep :gene_expression
  task :averaged_expression => :tsv do
    gene_expression = TSV.open step(:gene_expression).path, :type => :double
    gene_expression = gene_expression.reorder "Associated Gene Name", gene_expression.fields.reject{|field| field === "Associated Gene Name"}

    averaged_expression = TSV.setup({}, :key_field => gene_expression.key_field, :fields => gene_expression.fields, :type => :list, :cast => :to_f)
    gene_expression.with_unnamed do
      gene_expression.through do |gene, values|
        averaged_expression[gene] = values.collect{|list| Misc.mean(list.collect{|v| v.to_f}) }
      end
    end

    averaged_expression.namespace = gene_expression.namespace

    averaged_expression
  end

  dep :averaged_expression
  task :range_expression => :string do
    averaged_expression = step(:averaged_expression).load

    float_size = 10
    value_size = (float_size + 1) * averaged_expression.fields.length

    chromosome_range_expression = {}
    genes = averaged_expression.keys
    gene_range = Misc.process_to_hash(genes){|genes| genes.ensembl.chr_range}
    gene_chromosome = Misc.process_to_hash(genes){|genes| genes.ensembl.chromosome}
    averaged_expression.with_unnamed do
      averaged_expression.collect do |gene,values|
        range = gene_range[gene]
        next if range.nil?
        formatted_range = [range.begin, range.end]
        chromosome = gene_chromosome[gene]
        formatted_values = values.collect{|v| "%.#{float_size - 3}f" % v} * "\t"
        chromosome_range_expression[chromosome] ||= {}
        chromosome_range_expression[chromosome][range] = formatted_values
      end
    end

    chromosome_range_expression.each do |chromosome,range_expression|
      log "saving_#{chromosome}", "Saving chromosome #{ chromosome }"
      data = range_expression.collect{|range, values| [values, [range.begin, range.end]]}
      filename = file(chromosome)
      dirname = File.dirname(filename)
      FileUtils.mkdir_p dirname unless File.exists? dirname
      fwt = FixWidthTable.new(filename, value_size, true, true)
      fwt.add_range data
      fwt.close
    end

    set_info :fields, averaged_expression.fields
    set_info :organism, averaged_expression.namespace
    set_info :value_size, value_size

    "done"
  end

  dep :range_expression
  input :chunk_size, :integer, "Chunk size"
  task :circos_data => :tsv do |chunk_size|
    range_expression_step = step(:range_expression)

    value_size = range_expression_step.info[:value_size]
    fields = range_expression_step.info[:fields]
    organism = range_expression_step.info[:organism]

    tsv = TSV.setup({}, :key_field => "Genomic Range", :fields => fields, :type => :list, :namespace => organism)
    Dir.glob(File.join(range_expression_step.files_dir, "*")).each do |chromosome_file|
      chromosome = File.basename(chromosome_file)
      fwt = FixWidthTable.get(chromosome_file, value_size, true)
      last_pos = fwt.last_pos
      offset = 0
      while offset < last_pos - 1
        next_offset = [offset + chunk_size, last_pos].min
        range = (offset..next_offset-1)
        gene_profiles = fwt[range].collect{|gene_profiles| gene_profiles.split("\t").collect{|v| v.to_f}}
        if gene_profiles.empty?
          values = [0.0] * fields.length
        else
          values = Misc.zip_fields(gene_profiles).collect{|list| Misc.mean(list)}
        end
        tsv[[chromosome, offset, next_offset] * ":"] = values
        offset = next_offset-1
      end
    end
    
    tsv
  end

  dep :circos_data
  input :sample, :string, "Sample to process"
  task :circos_sample_data => :text do |sample|
    circos_data = step(:circos_data).load
    text = ""
    circos_data.slice(sample).through do |range, value|
      chromosome, start, eend = range.split(":")
      next unless chromosome =~ /^[0-9XY]+/
      chromosome = "hs" + chromosome
      text << [chromosome, start, eend, value] * "\t" << "\n"
    end
    text
  end

  dep :circos_sample_data
  task :circos_plot => :string do
    circos_sample_data = step(:circos_sample_data)

    conf_dir = file(:conf)
    FileUtils.mkdir_p conf_dir
    %w(colors.all.conf colors.conf colors.values.conf fonts.conf ideogram.conf ticks.conf).each do |file|
      FileUtils.cp Rbbt.share.circos[file].find, File.join(conf_dir, file)
    end

    image_dir = file(:img)
    FileUtils.mkdir_p image_dir

    image_file = File.join(image_dir, name)

    conf = []

    header = Circos.header
    image  = Circos.image(image_file)
    plot   = Circos.plot(circos_sample_data.path)

    plots = [{:plots => plot}]

    
    conf.concat header
    conf.concat image
    conf.concat plots

    Open.write(File.join(conf_dir, 'circos.conf'), Circos.print_conf(conf)) 

    `circos -conf #{File.join(conf_dir, 'circos.conf')}`
    "done"
  end

end
