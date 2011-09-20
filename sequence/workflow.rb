require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/sources/organism'
require 'sequence'
require 'bio'

Workflow.require_workflow 'Mutation'
module Sequence
  extend Workflow
  extend Resource

  desc "Upload genotype"
  input :organism, :string, "Organism code", "Hsa"
  input :cutoff, :float, "Score cutoff value, if scores are available", 0
  input :file, :text, "Genotype file. Chr:Pos:Mut (e.g. 1:1234:A) optionaly with scores (e.g. 1:1234:A:200.5)"
  def self.genotype(organism, cutoff, file)
    file.split(/[\n,]/).collect do |line|
      chr, position, allele, score = line.chomp.split(/\s|:/).values_at 0, 1, 2, 3
      chr.sub! "chr", ""
      next if score and cutoff > 0 and score.to_f >= cutoff
      [chr, position, allele].compact * ":"
    end.compact
  end
  task :genotype => :array 
  export_synchronous :genotype

  desc "Upload pileup"
  input :organism, :string, "Organism code", "Hsa"
  input :file, :text, "Genotype file. Chr:Pos:Mut (e.e. 1:1234:A)"
  input :score, :integer, "Select mutations above this score"
  def self.pileup(organism, genotype, threshold)
    genotype.split(/\n/).collect do |line|
      chr, position, allele, score = line.chomp.split(/\t/).values_at 0, 1, 3, 4
      next if score.to_i < threshold
      chr.sub!(/chr/,'')
      [chr, position, allele, score] * ":"
    end.compact
  end
  task :pileup => :array 
  export_synchronous :pileup

  desc "Attach database to file"
  input :organism, :string, "Organism code", "Hsa"
  input :file, :tsv, "TSV file to extend"
  input :databases, :array, "Database codes"
  def self.attach(organism, file, databases)
    file.identifiers = Organism.identifiers(organism)
    file.type = :double

    databases.each do |database|
      fields = nil
      case database 
      when "PharmaGKB:pathways"
        require 'rbbt/sources/pharmagkb'
        path = PharmaGKB.gene_pathway.find
        fields = ["PhGKB Pathway ID"]
      when "KEGG:pathways"
        require 'rbbt/sources/kegg'
        path = KEGG.gene_pathway.find
      when "Cancer:Types"
        require 'rbbt/sources/cancer'
        path = Cancer.anais_annotations
      else
        next
      end

      file.attach path, :fields =>  fields
    end
    file
  end
  task :attach => :tsv
  export_asynchronous :attach
end
