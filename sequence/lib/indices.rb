require 'rbbt/sources/organism'
module Sequence

  def self.gene_position_index(organism, chromosome)
    key = [organism, chromosome]
    @@gene_position ||= {}
    if @@gene_position[key].nil?
      @@gene_position[key] = TSV.range_index(Organism.gene_positions(organism).produce, "Gene Start", "Gene End", :filters => [["field:Chromosome Name", chromosome]], :persist => true, :data_persist => true, :unnamed => true)
    end
    @@gene_position[key]
  end

  def self.exon_position_index(organism, chromosome)
    key = [organism, chromosome]
    @@exon_position ||= {}
    if @@exon_position[key].nil?
      @@exon_position[key] = TSV.range_index(Organism.exons(organism).produce, "Exon Chr Start", "Exon Chr End", :filters => [["field:Chromosome Name", chromosome]], :persist => true, :data_persist => true, :unnamed => true)
    end
    @@exon_position[key]
  end

  def self.exon_start_index(organism, chromosome)
    key = [organism, chromosome]
    @@exon_start ||= {}
    if @@exon_start[key].nil?
      @@exon_start[key] = TSV.pos_index(Organism.exons(organism).produce, "Exon Chr Start", :filters => [["field:Chromosome Name", chromosome]], :persist => true, :data_persist => true, :unnamed => true)
    end
    @@exon_start[key]
  end

  def self.exon_end_index(organism, chromosome)
    key = [organism, chromosome]
    @@exon_end ||= {}
    if @@exon_end[key].nil?
      @@exon_end[key] = TSV.pos_index(Organism.exons(organism).produce, "Exon Chr End", :filters => [["field:Chromosome Name", chromosome]], :persist => true, :data_persist => true, :unnamed => true)
    end
    @@exon_end[key]
  end


  def self.exon_info(organism)
    key = organism
    @@exon_info ||= {}
    if @@exon_info[key].nil?
      @@exon_info[key] = Organism.exons(organism).tsv :persist => true, :serializer => :list, :unnamed => true
      @@exon_info[key].unnamed = true
    end
    @@exon_info[key]
  end

  def self.exon_transcript_offsets(organism)
    key = organism
    @@exon_transcript_offsets ||= {}
    if @@exon_transcript_offsets[key].nil?
      @@exon_transcript_offsets[key] = Organism.exon_offsets(organism).tsv :persist => true, :serializer => :double, :unnamed => true
    end
    @@exon_transcript_offsets[key]
  end

  def self.transcript_sequence(organism)
    key = organism
    @@transcript_sequence ||= {}
    if @@transcript_sequence[key].nil?
      @@transcript_sequence[key] = Organism.transcript_sequence(organism).tsv(:single, :persist => true, :unnamed => true)
    end
    @@transcript_sequence[key]
  end

  def self.transcript_5utr(organism)
    key = organism
    @@transcript_5utr ||= {}
    if @@transcript_5utr[key].nil?
      @@transcript_5utr[key] = Organism.transcript_5utr(organism).tsv(:single, :persist => true, :unnamed => true)
    end
    @@transcript_5utr[key]
  end
   
  def self.transcript_3utr(organism)
    key = organism
    @@transcript_3utr ||= {}
    if @@transcript_3utr[key].nil?
      @@transcript_3utr[key] = Organism.transcript_3utr(organism).tsv(:single, :persist => true, :unnamed => true)
    end
    @@transcript_3utr[key]
  end

  def self.transcript_phase(organism)
    key = organism
    @@transcript_phase ||= {}
    if @@transcript_phase[key].nil?
      @@transcript_phase[key] = Organism.transcript_phase(organism).tsv(:single, :persist => true, :unnamed => true)
    end
    @@transcript_phase[key]
  end

  def self.snp_position_index(organism, chromosome)
    key = [organism, chromosome]
    @@snp_position ||= {}
    @@germline_variations ||= Organism.germline_variations(organism).tsv :persist => true, :unnamed => true
    if @@snp_position[key].nil?
      @@germline_variations.filter
      @@germline_variations.add_filter "field:Chromosome Name", chromosome
      @@snp_position[key] = @@germline_variations.pos_index("Chromosome Start", :persist => true, :unnamed => true) #TSV.pos_index(Organism.germline_variations(organism), "Chromosome Start", :filters => [["field:Chromosome Name", chromosome]], :persist => true, :data_persist => true, :monitor => true)
    end
    @@snp_position[key]
  end

  def self.somatic_snv_position_index(organism, chromosome)
    key = [organism, chromosome]
    @@snv_position ||= {}
    @@germline_variations ||= Organism.somatic_variations(organism).tsv :persist => true, :unnamed => true
    if @@snv_position[key].nil?
      @@germline_variations.filter
      @@germline_variations.add_filter "field:Chromosome Name", chromosome
      @@snv_position[key] = @@germline_variations.pos_index("Chromosome Start", :persist => true, :unnamed => true) #TSV.pos_index(Organism.germline_variations(organism), "Chromosome Start", :filters => [["field:Chromosome Name", chromosome]], :persist => true, :data_persist => true, :monitor => true)
    end
    @@snv_position[key]
  end
end
