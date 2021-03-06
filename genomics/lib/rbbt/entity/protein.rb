require 'rbbt/entity'
require 'rbbt/workflow'
require 'rbbt/sources/organism'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/network/paths'
require 'rbbt/entity/gene'

Workflow.require_workflow "Translation"

module Protein
  extend Entity
  include Entity::Adjacent
  include Entity::Enriched

  self.annotation :format
  self.annotation :organism

  self.format = "Ensembl Protein ID"

  def self.ensp2sequence(organism, protein)
    @@ensp2sequence ||= {}
    @@ensp2sequence[organism] ||= Organism.protein_sequence(organism).tsv :persist => true, :unnamed => true
    if Array === protein
      @@ensp2sequence[organism].chunked_values_at protein
    else
      @@ensp2sequence[organism][protein]
    end
  end

  def self.ensp2enst(organism, protein)
    @@ensp2enst ||= {}
    @@ensp2enst[organism] ||= Organism.transcripts(organism).tsv(:type => :single, :key_field => "Ensembl Protein ID", :fields => ["Ensembl Transcript ID"], :persist => true, :unnamed => true)
    @@ensp2enst[organism][protein]
  end

  property :uniprot => :array2single do
    to "UniProt/SwissProt Accession"
  end

  property :ensembl => :array2single do
    to "Ensembl Protein ID"
  end

  property :transcript => :array2single do
    res = ensembl.collect{|ensp|
      Protein.ensp2enst(organism, ensp)
    }
    Transcript.setup(res, "Ensembl Transcript ID", self.organism) if defined? Transcript
    res
  end

  property :ensembl_protein_image_url => :single2array do
    organism = self.organism || "Hsa"
    ensembl_url = if organism == "Hsa" then "www.ensembl.org" else "#{organism.sub(/.*\//,'')}.archive.ensembl.org" end
    "http://#{ensembl_url}/Homo_sapiens/Component/Transcript/Web/TranslationImage?db=core;p=#{ensembl};_rmd=d2a8;export=svg"
  end

  property :to => :array2single do |new_format|
    return self if format == new_format
    Protein.setup(Translation.job(:tsv_translate_protein, "", :organism => organism, :proteins => self, :format => new_format).exec.chunked_values_at(self), new_format, organism)
  end

  property :__to => :array2single do |new_format|
    return self if format == new_format
    to!(new_format).collect!{|v| v.nil? ? nil : v.first}
  end

  property :ortholog => :array2single do |other|
    return self if organism =~ /^#{ other }(?!\w)/
    self.zip(self.gene.ortholog(other)).collect do |this_protein,other_gene|
      next if other_gene.nil? or other_gene.empty?
      this_protein_length = this_protein.sequence.length
      proteins = Gene.setup(other_gene, "Ensembl Gene ID", other).proteins.flatten.reject{|p| p.sequence.nil?}
      best = proteins.sort_by{|other_protein| (other_protein.sequence.length - this_protein_length).abs }.first
      best
    end
  end

  property :gene => :array do
    Gene.setup(to("Ensembl Protein ID").clean_annotations.collect{|e| e.nil? ? e : e.dup}, "Ensembl Protein ID", organism).ensembl
  end

  property :pfam => :array2single do
    index = Organism.gene_pfam(organism).tsv :flat, :persist => true, :unnamed => true
    pfam = index.chunked_values_at(self).flatten
    Pfam.setup pfam
  end

  property :sequence => :array2single do
    Protein.ensp2sequence(organism, self.ensembl)
  end

  property :sequence_length => :array2single do
    sequence.collect{|seq| seq.nil? ? nil : seq.length}
  end

  property :marked_svg => :single2array do |*args|
    positions = args.first
    svg = Open.read(ensembl_protein_image_url)
    
    seq_len = sequence_length

    doc = Nokogiri::XML(svg)
    return nil unless doc.css('svg').any?
    width = doc.css('svg').first.attr('width').to_f
    height = doc.css('svg').first.attr('height').to_f
    start = doc.css('rect.ac').first.attr('x').to_f

    positions.each do |position|
      if width and height and start and seq_len and position
        offset = (width - start)/seq_len * position + start + rand * 10
        svg = svg.sub(/<\/svg>/,"<rect x='#{offset}' y='1' width='1' height='#{height}' style='fill:rgb(255,0,0);opacity:0.5;stroke:none;'></svg>")
      end
    end

    svg = svg.sub(/<svg /,"<svg attr-rbbt-entity='protein'")
    svg
  end

  property :pdbs => :single do
    next if uniprot.nil?
    UniProt.pdbs(uniprot)
  end


end
