require 'indices'

module Sequence
  extend Workflow

  desc "Find genes at particular positions in a chromosome. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :positions, :array, "Positions"
  def self.genes_at_chr_positions(organism, chromosome, positions)
    index = gene_position_index(organism, chromosome)
    index.values_at(*positions).collect{|list| list * "|"}
  end
  task :genes_at_chr_positions => :array
  export_exec :genes_at_chr_positions

  desc "Find genes at particular genomic positions. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :positions, :array, "Positions Chr:Position (e.g. 11:533766). Separator can be ':', space or tab. Extra fields are ignored"
  def self.genes_at_genomic_positions(organism, positions)
    chr_positions = {}
    positions.each do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      chr_positions[chr] ||= []
      chr_positions[chr] << pos
    end

    chr_genes = {}
    chr_positions.each do |chr, list|
      chr_genes[chr] = genes_at_chr_positions(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Position", :fields => ["Ensembl Gene ID"], :type => :flat)
    positions.collect do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      tsv[position] = chr_genes[chr].shift.split("|")
    end
    tsv
  end
  task :genes_at_genomic_positions => :tsv
  export_synchronous :genes_at_genomic_positions

  desc "Find exons at particular positions in a chromosome. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :positions, :array, "Positions"
  def self.exons_at_chr_positions(organism, chromosome, positions)
    index = exon_position_index(organism, chromosome)
    index.values_at(*positions).collect{|list| list * "|"}
  end
  task :exons_at_chr_positions => :array
  export_exec :exons_at_chr_positions

  desc "Find exons at particular genomic positions. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :positions, :array, "Positions Chr:Position (e.g. 11:533766). Separator can be ':', space or tab. Extra fields are ignored"
  def self.exons_at_genomic_positions(organism, positions)
    chr_positions = {}
    positions.each do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      chr_positions[chr] ||= []
      chr_positions[chr] << pos
    end

    chr_exons = {}
    chr_positions.each do |chr, list|
      chr_exons[chr] = exons_at_chr_positions(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Position", :fields => ["Ensembl Exon ID"], :type => :flat)
    positions.collect do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      tsv[position] = chr_exons[chr].shift.split("|")
    end
    tsv
  end
  task :exons_at_genomic_positions => :tsv
  export_synchronous :exons_at_genomic_positions

  desc "Find exon junctions at particular positions in a chromosome. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :positions, :array, "Positions"
  def self.exon_junctions_at_chr_positions(organism, chromosome, positions)
    start_index = exon_start_index(organism, chromosome)
    end_index = exon_end_index(organism, chromosome)
    exon_info = exon_info(organism)

    strand_field_pos = exon_info.identify_field "Exon Strand"
    start_field_pos = exon_info.identify_field "Exon Chr Start"
    end_field_pos = exon_info.identify_field "Exon Chr End"
    positions.collect{|pos|
      pos = pos.to_i
      junctions = []

      end_exons = end_index[pos - 3..pos + 3]
      start_exons = start_index[pos - 3..pos + 3]

      end_exons.each do |exon|
        strand, eend = exon_info[exon].values_at strand_field_pos, end_field_pos
        eend = eend.to_i
        diff = pos - eend
        case
        when (strand == "1" and diff.abs <= 2)
          junctions << exon + ":acceptor(#{diff})"
        when (strand == "-1" and diff.abs <= 2)
          junctions << exon + ":donor(#{diff})"
        end
      end

      start_exons.each do |exon|
        strand, start = exon_info[exon].values_at strand_field_pos, start_field_pos
        start = start.to_i
        diff = pos - start

        case
        when (strand == "1" and diff.abs <= 2)
          junctions << exon + ":donor(#{diff})"
        when (strand == "-1" and diff.abs <= 2)
          junctions << exon + ":acceptor(#{diff})"
        end
      end

      junctions * "|"
    }
  end
  task :exon_junctions_at_chr_positions => :array
  export_exec :exon_junctions_at_chr_positions

  desc "Find exon junctions at particular genomic positions. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :positions, :array, "Positions Chr:Position (e.g. 11:533766). Separator can be ':', space or tab. Extra fields are ignored"
  def self.exon_junctions_at_genomic_positions(organism, positions)
    chr_positions = {}
    positions.each do |position|
      chr, pos = position.strip.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      chr_positions[chr] ||= []
      chr_positions[chr] << pos
    end

    chr_exon_junctions = {}
    chr_positions.each do |chr, list|
      chr_exon_junctions[chr] = exon_junctions_at_chr_positions(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Position", :fields => ["Exon Junction"], :type => :flat)
    positions.collect do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      tsv[position] = chr_exon_junctions[chr].shift.split("|")
    end
    tsv
  end
  task :exon_junctions_at_genomic_positions => :tsv
  export_asynchronous :exon_junctions_at_genomic_positions

  desc "Transcript offsets of genomic prositions. transcript:offset:strand"
  input :organism, :string, "Organism code", "Hsa"
  input :positions, :array, "Mutation Chr:Position. Separator can be ':', space or tab. Extra fields are ignored"
  def self.transcript_offsets_for_genomic_positions(organism, positions)
    exons = exons_at_genomic_positions(organism, positions)
    exon_info = exon_info(organism) 
    exon_transcript_offsets = exon_transcript_offsets(organism) 
    exon_transcript_offsets.unnamed = true

    field_positions = ["Exon Strand", "Exon Chr Start", "Exon Chr End"].collect{|field| exon_info.identify_field field}

    exon_offsets = exons.collect do |position, exons|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      pos = pos.to_i
      list = exons.collect do |exon|
        strand, start, eend = exon_info[exon].values_at *field_positions
        if strand == "1"
          offset = pos - start.to_i
        else
          offset = eend.to_i - pos
        end

        [exon, offset, strand]
      end
      [position, list]
    end

    tsv = TSV.setup({}, :key_field => "Genomic Position", :fields => ["Ensembl Transcrip ID:Offset:Strand"], :type => :flat)
    
    exon_transcript_offsets.unnamed = false
    exon_offsets.each do |position, list|
      next if list.empty?
      offsets = []
      list.each do |exon, offset, strand|
        Misc.zip_fields(exon_transcript_offsets[exon]).each do |transcript, exon_offset|
          offsets << [transcript, exon_offset.to_i + offset, strand] * ":"
        end if exon_transcript_offsets.include? exon
      end
      tsv[position] = offsets
    end
    tsv

  end
  task :transcript_offsets_for_genomic_positions => :tsv
  export_synchronous :transcript_offsets_for_genomic_positions

  desc "Return transcript codon at the specified position. Codon:offset:pos"
  input :organism, :string, "Organism code", "Hsa"
  input :transcript, :string, "Ensembl Transcript ID"
  input :offset, :integer, "Offset inside transcript"
  def self.codon_at_transcript_position(organism, transcript, offset)
    transcript_sequence = transcript_sequence(organism) 
    transcript_5utr = transcript_5utr(organism) 
    transcript_3utr = transcript_3utr(organism) 
    transcript_phase = transcript_phase(organism)

    utr5 = transcript_5utr[transcript]
      
    if utr5.nil?
      Log.debug "UTR5 for transcript was missing: #{ transcript }"
      phase = transcript_phase[transcript]
      raise "No UTR5 and no phase for transcript: #{ transcript }" if phase.nil?
      raise "No UTR5 but phase is -1: #{ transcript }" if phase == -1
      utr5 = - phase
    else
      utr5 = utr5.to_i
    end

    return "UTR5" if utr5 > offset

    sequence = transcript_sequence[transcript]
    raise "Sequence for transcript was missing: #{ transcript }" if sequence.nil? if sequence.nil?

    ccds_offset = offset - utr5
    utr3 = transcript_3utr[transcript].to_i
    return "UTR3" if ccds_offset > (sequence.length - utr3)

    if utr5 >= 0
      range = (utr5..-1)
      sequence = sequence[range]
    else
      sequence = "N" * utr5.abs << sequence
    end

    codon = ccds_offset / 3
    codon_offset =  ccds_offset % 3

    [sequence[(codon * 3)..((codon + 1) * 3 - 1)], codon_offset, codon] * ":"
  end
  task :codon_at_transcript_position => :string
  export_exec :codon_at_transcript_position

  desc "Guess if mutations are given in watson or gene strand"
  input :organism, :string, "Organism code", "Hsa"
  input :mutations, :array, "Mutation Chr:Position:Mut (e.g. 19:54646887:A). Separator can be ':', space or tab. Extra fields are ignored"
  def self.to_watson(organism, mutations)
    transcript_offsets = transcript_offsets_for_genomic_positions(organism, mutations)

    fixed = {}
    mutations.each{|mutation| fixed[mutation] = mutation}

    transcript_offsets.each do |mutation, list|
      chr, pos, mut = mutation.split ":"
      next unless Misc::BASE2COMPLEMENT.include? mut
      fixed[mutation] = mutation.sub(mut, Misc::BASE2COMPLEMENT[mut]) if (list.any? and list.first.split(":")[2] == "-1")
    end

    fixed.values_at *mutations
  end
  task :to_watson => :array
  export_synchronous :to_watson

  desc "Guess if mutations are given in watson or gene strand"
  input :organism, :string, "Organism code", "Hsa"
  input :mutations, :array, "Mutation Chr:Position:Mut (e.g. 19:54646887:A). Separator can be ':', space or tab. Extra fields are ignored"
  def self.is_watson(organism, mutations)
    diffs = (mutations - to_watson(organism, mutations)).each

    same = 0
    opposite = 0
    diffs.zip(reference_allele_at_genomic_positions(organism, diffs).values_at *diffs).each do |mutation, reference|
      chr, pos, mut = mutation.split ":"
      same += 1 if mut == reference
      opposite += 1 if mut == Misc::BASE2COMPLEMENT[reference]
    end

    log(:counts, "Opposite: #{ opposite }. Same: #{ same }")
    opposite > same
  end
  task :is_watson => :boolean
  export_synchronous :is_watson

  desc "Reference allele at positions in a chromosome"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :positions, :array, "Positions"
  def self.reference_allele_at_chr_positions(organism, chromosome, positions)
    begin
      File.open(Organism[File.join(organism, "chromosome_#{chromosome}")].produce.find) do |f|
        Misc.process_to_hash(positions.sort){|list| list.collect{|position| f.seek(position.to_i - 1); c = f.getc; c.nil? ? nil : c.chr }}.values_at *positions
      end
    rescue
      if $!.message =~ /Fasta file for chromosome not found/i
        Log.low $!.message
        ["?"] * positions.length
      else
        raise $!
      end
    end
  end
  task :reference_allele_at_chr_positions => :array
  export_exec :reference_allele_at_chr_positions

  desc "Reference allele at genomic positions"
  input :organism, :string, "Organism code", "Hsa"
  input :positions, :array, "Positions Chr:Position (e.g. 19:54646887). Separator can be ':', space or tab. Extra fields are ignored"
  def self.reference_allele_at_genomic_positions(organism, positions)
    chr_positions = {}

    positions.each do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      chr_positions[chr] ||= []
      chr_positions[chr] << pos
    end

    chr_bases = {}
    chr_positions.each do |chr, list|
      chr_bases[chr] = reference_allele_at_chr_positions(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Position", :fields => ["Reference Allele"], :type => :single)
    positions.collect do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr.sub!(/chr/,'')
      tsv[position] = chr_bases[chr].shift
    end
    tsv
  end
  task :reference_allele_at_genomic_positions=> :tsv
  export_synchronous :reference_allele_at_genomic_positions


  desc "Mutated protein isoforms"
  input :organism, :string, "Organism code", "Hsa"
  input :watson, :boolean, "Alleles reported always in the Watson strand (as opposed to the gene's strand)", true
  input :mutations, :array, "Mutation Chr:Position:Mut (e.g. 19:54646887:A). Separator can be ':', space or tab. Extra fields are ignored"
  def self.mutated_isoforms_for_genomic_mutations(organism, watson, mutations)
    transcript_offsets = transcript_offsets_for_genomic_positions(organism, mutations)
    transcript_to_protein = Organism.transcripts(organism).tsv(:persist => true, :fields => ["Ensembl Protein ID"], :type => :single)

    mutated_isoforms = TSV.setup({}, :type => :flat, :key_field => "Genomic Mutation", :fields => ["Mutated Isoform"])

    transcript_offsets.each do |mutation, list|
      chr, pos, mut = mutation.split ":"
      chr.sub!(/chr/,'')
      case
      when (mut.length == 1 and mut != '-')
        alleles = Misc.IUPAC_to_base(mut) || []
      when (mut.length % 3 == 0)
        alleles = ["Indel"]
      else
        alleles = ["FrameShift"]
      end

      isoforms = []
      list.collect{|t| t.split ":"}.each do |transcript, offset, strand|
        offset = offset.to_i
        begin
          codon = codon_at_transcript_position(organism, transcript, offset)
          case codon
          when "UTR5", "UTR3"
            isoforms << [transcript, codon]
          else
            triplet, offset, pos = codon.split ":"
            next if not triplet.length === 3
            original = Bio::Sequence::NA.new(triplet).translate
            alleles.each do |allele|
              case allele
              when "Indel"
                isoforms << [transcript, [original, pos.to_i + 1, "Indel"] * ""]
              when "FrameShift"
                isoforms << [transcript, [original, pos.to_i + 1, "FrameShift"] * ""]
              else
                allele = Misc::BASE2COMPLEMENT[allele] if watson and strand.to_i == -1
                triplet[offset.to_i] = allele 
                new = Bio::Sequence::NA .new(triplet).translate
                isoforms << [transcript, [original, pos.to_i + 1, new] * ""]
              end
            end
          end
        rescue
          Log.debug $!.message
        end
      end

      mutated_isoforms[mutation] = isoforms.collect{|transcript, change| 
        if change =~ /^UTR/
          [transcript, change] * ":"
        else
          protein = transcript_to_protein[transcript]
          [protein, change] * ":"
        end
      }
    end
    mutated_isoforms
  end
  task :mutated_isoforms_for_genomic_mutations => :tsv
  export_synchronous :mutated_isoforms_for_genomic_mutations

  desc "Identify known SNPs in a chromosome"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :positions, :array, "Positions Chr:Position (e.g. 11:533766). Separator can be ':', space or tab. Extra fields are ignored"
  def self.snps_at_chr_positions(organism, chromosome, positions)
    index = snp_position_index(organism, chromosome)
    index.values_at(*positions).collect{|list| list * "|"}
  end
  task :snps_at_chr_positions => :array
  export_exec :snps_at_chr_positions

  def self.somatic_snvs_at_chr_positions(organism, chromosome, positions)
    index = somatic_snv_position_index(organism, chromosome)
    index.values_at(*positions).collect{|list| list * "|"}
  end
  task :somatic_snvs_at_chr_positions => :array
  export_exec :somatic_snvs_at_chr_positions

  desc "Identify known SNPs at genomic positions"
  input :organism, :string, "Organism code", "Hsa"
  input :positions, :array, "Positions Chr:Position (e.g. 11:533766). Separator can be ':', space or tab. Extra fields are ignored"
  def self.snps_at_genomic_positions(organism, positions)
    chr_positions = {}
    positions.each do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      chr_positions[chr] ||= []
      chr_positions[chr] << pos
    end

    chr_snps = {}
    chr_positions.each do |chr, list|
      chr_snps[chr] = snps_at_chr_positions(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Position", :fields => ["Germline SNP"], :type => :double)
    positions.collect do |position|
      chr, pos = position.split(/[\s:\t]/).values_at 0, 1
      tsv[position] = chr_snps[chr].shift.split("|")
    end
    tsv
  end
  task :snps_at_genomic_positions => :tsv
  export_asynchronous :snps_at_genomic_positions

  desc "Find genes at particular ranges in a chromosome. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :ranges, :array, "Ranges"
  def self.genes_at_chr_ranges(organism, chromosome, ranges)
    index = gene_position_index(organism, chromosome)
    r = ranges.collect{|r| s,e = r.split(":"); (s.to_i..e.to_i)}
    index.values_at(*r).collect{|list| list * "|"}
  end
  task :genes_at_chr_ranges => :array
  export_exec :genes_at_chr_ranges

  desc "Find genes at particular genomic ranges. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :ranges, :array, "Positions Chr:Start:End (e.g. 11:533766:553323)"
  def self.genes_at_genomic_ranges(organism, ranges)
    chr_ranges = {}
    ranges.each do |range|
      chr, s, e = range.split(":").values_at 0, 1, 2
      chr.sub!(/chr/,'')
      chr_ranges[chr] ||= []
      chr_ranges[chr] << [s, e] * ":" 
    end

    chr_genes = {}
    chr_ranges.each do |chr, list|
      chr_genes[chr] = genes_at_chr_ranges(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Range", :fields => ["Ensembl Gene ID"], :type => :flat)
    ranges.collect do |range|
      chr, s, e = range.split(":").values_at 0, 1, 2
      chr.sub!(/chr/,'')
      tsv[range] = chr_genes[chr].shift.split("|")
    end
    tsv
  end
  task :genes_at_genomic_ranges => :tsv
  export_synchronous :genes_at_genomic_ranges

  #----- GENES

  desc "Find SNPS at particular ranges in a chromosome. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :ranges, :array, "Ranges"
  def self.snps_at_chr_ranges(organism, chromosome, ranges)
    index = snp_position_index(organism, chromosome)
    r = ranges.collect{|r| s,e = r.split(":"); (s.to_i..e.to_i)}
    index.values_at(*r).collect{|list| list * "|"}
  end
  task :snps_at_chr_ranges => :array
  export_exec :snps_at_chr_ranges

  desc "Find SNPS at particular genomic ranges. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :ranges, :array, "Positions Chr:Start:End (e.g. 11:533766:553323)"
  def self.snps_at_genomic_ranges(organism, ranges)
    chr_ranges = {}
    ranges.each do |range|
      chr, s, e = range.split(":").values_at 0, 1, 2
      chr.sub!(/chr/,'')
      chr_ranges[chr] ||= []
      chr_ranges[chr] << [s, e] * ":" 
    end

    chr_snps = {}
    chr_ranges.each do |chr, list|
      chr_snps[chr] = snps_at_chr_ranges(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Range", :fields => ["SNP ID"], :type => :flat)
    ranges.collect do |range|
      chr, s, e = range.split(":").values_at 0, 1, 2
      chr.sub!(/chr/,'')
      tsv[range] = chr_snps[chr].shift.split("|")
    end
    tsv
  end
  task :snps_at_genomic_ranges => :tsv
  export_synchronous :snps_at_genomic_ranges

  desc "Find somatic SNVs at particular ranges in a chromosome. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :chromosome, :string, "Chromosome name"
  input :ranges, :array, "Ranges"
  def self.somatic_snvs_at_chr_ranges(organism, chromosome, ranges)
    index = somatic_snv_position_index(organism, chromosome)
    r = ranges.collect{|r| s,e = r.split(":"); (s.to_i..e.to_i)}
    index.values_at(*r).collect{|list| list * "|"}
  end
  task :somatic_snvs_at_chr_ranges => :array
  export_exec :somatic_snvs_at_chr_ranges

  desc "Find somatic SNVs at particular genomic ranges. Multiple values separated by '|'"
  input :organism, :string, "Organism code", "Hsa"
  input :ranges, :array, "Positions Chr:Start:End (e.g. 11:533766:553323)"
  def self.somatic_snvs_at_genomic_ranges(organism, ranges)
    chr_ranges = {}
    ranges.each do |range|
      chr, s, e = range.split(":").values_at 0, 1, 2
      chr.sub!(/chr/,'')
      chr_ranges[chr] ||= []
      chr_ranges[chr] << [s, e] * ":" 
    end

    chr_somatic_snvs = {}
    chr_ranges.each do |chr, list|
      chr_somatic_snvs[chr] = somatic_snvs_at_chr_ranges(organism, chr, list)
    end

    tsv = TSV.setup({}, :key_field => "Genomic Range", :fields => ["SNP ID"], :type => :flat)
    ranges.collect do |range|
      chr, s, e = range.split(":").values_at 0, 1, 2
      chr.sub!(/chr/,'')
      tsv[range] = chr_somatic_snvs[chr].shift.split("|")
    end
    tsv
  end
  task :somatic_snvs_at_genomic_ranges => :tsv
  export_synchronous :somatic_snvs_at_genomic_ranges


end
