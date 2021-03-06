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

  input :plots, :yaml, "Plot configuration", nil
  input :image_map, :string, "Produce image map", nil
  input :organism, :string, "Organism code", "Hsa"
  input :image_options, :yaml, "Image options", {}
  task :circos => :string do |plots, image_map, organism, image_options|
    image_options = Misc.add_defaults image_options, "inner_radius" => 0.7, "outer_radius" => 0.95, "gap" => 0.01
    inner_radius = Misc.process_options image_options, "inner_radius"
    outer_radius = Misc.process_options image_options, "outer_radius"
    gap          = Misc.process_options image_options, "gap"

    conf_dir = file(:conf)
    FileUtils.mkdir_p conf_dir

    %w(colors.all.conf colors.conf colors.values.conf fonts.conf ideogram.conf ticks.conf).each do |file|
      FileUtils.cp Rbbt.share.circos[file].find, File.join(conf_dir, file)
    end

    image_dir = file(:img)
    FileUtils.mkdir_p image_dir

    image_file = File.join(image_dir, 'image.png')

    conf = []

    header = Circos.header
    image  = Circos.image(image_file, image_options)

    total = plots.length
    width = outer_radius - inner_radius
    size = width / total 
    plots.each_with_index do |plot, i|
      plot[:plot].first["r0"] = "#{inner_radius + size * i + gap}r"
      plot[:plot].first["r1"] = "#{inner_radius + size * (i + 1)}r"
    end

    plot_config = [{:plots => plots}]

    
    conf.concat header
    conf.concat image
    conf.concat plot_config

    if not image_map.nil? and not image_map.empty?
      conf << { :image_map_use      => 'yes',
        :image_map_missing_parameter => "exit",
        :image_map_name => image_map } 
      Open.write(File.join(conf_dir, 'ideogram.conf'), Rbbt.share.circos['ideogram.conf.map'].read.gsub("[ORGANISM]", organism))
    end
    
    Open.write(File.join(conf_dir, 'circos.conf'), Circos.print_conf(conf)) 

    `circos -conf #{File.join(conf_dir, 'circos.conf')}`
    "done"
  end


  input :value_file, :tsv, "Sample matrix"
  input :chunk_size, :integer, "Chunk size", 10_000_000
  def self.gene_ranges(value_file, chunk_size = 10_000_000)
    if Hash === value_file
      matrix = value_file
    else
      matrix = TSV.open(value_file, :type => :single, :cast => :to_f)
    end
    organism = matrix.namespace

    gene_ranges = Organism.gene_positions(organism).tsv(:persist => true, :fields => ["Chromosome Name", "Gene Start", "Gene End"], :type => :list, :unnamed => true)

    range_expression = {}

    chr_size = Hash.new{|h,chr| File.size(Organism[organism]["chromosome_#{chr}"].find)}

    log :finding, "Finding"
    gene_ranges.through do |gene, values|
      chr, start, eend = values
      next unless chr =~ /^[0-9]+$/ 
      next unless matrix.include? gene

      chunk = start.to_i / chunk_size
      range = (chunk*chunk_size..[((chunk + 1)*chunk_size)-1, chr_size[chr]].min)
      value = matrix[gene]

      range_expression[chr] ||= {}
      range_expression[chr][range] ||= []
      range_expression[chr][range] << value
    end

    text = ""
    log :averagin, "Aver"
    range_expression.each do |chr, values|
      last_pos = chr_size[chr]

      offset = 0
      while offset < last_pos 
        next_offset = [offset + chunk_size, last_pos].min
        range = (offset..next_offset-1)
        expression = Misc.mean(values[range] || [0])
        offset = next_offset
        text << "hs#{chr}\t#{range.begin}\t#{range.end}\t#{expression}\n"
      end
    end
    
    text
  end
  task :gene_ranges => :text

  input :ranges, :array, "Sample matrix"
  input :organism, :string, "Organism code", "Hsa"
  input :chunk_size, :integer, "Chunk size", 10_000_000
  def self.range_values(ranges, organism = "Hsa", chunk_size = 10_000_000)
    range_expression = {}

    chr_size = Hash.new{|h,chr| File.size(Organism[organism]["chromosome_#{chr}"].find)}

    ranges.each do |range|
      chr, start, eend, value = range.split(":")

      size = chr_size[chr]

      start_chunk = start.to_i / chunk_size
      end_chunk = eend.to_i / chunk_size

      (start_chunk..end_chunk).each do |chunk|
        r = (chunk*chunk_size..[((chunk + 1)*chunk_size)-1, chr_size[chr]].min)
        range_expression[chr] ||= {}
        range_expression[chr][r] ||= []
        range_expression[chr][r] << value.to_f
      end
    end

    text = ""
    log :averagin, "Aver"
    range_expression.each do |chr, values|
      last_pos = chr_size[chr]

      offset = 0
      while offset < last_pos 
        next_offset = [offset + chunk_size, last_pos].min
        range = (offset..next_offset-1)
        expression = Misc.mean(values[range] || [0])
        offset = next_offset
        text << "hs#{chr}\t#{range.begin}\t#{range.end}\t#{expression}\n"
      end
    end
    
    text
  end
  task :range_values => :text


end
