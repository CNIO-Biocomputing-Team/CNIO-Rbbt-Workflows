require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/sources/organism'
require 'translation'

module Translation
  extend Workflow

  desc "Translate gene ids to a particular format"
  input :organism, :string, "Organism code", "Hsa"
  input :format, :string, "Target identifier format", "Ensembl Gene ID"
  input :genes, :array, "Gene id list"
  def self.translate(organism, format, genes)
    index = index(organism, format)
    index.unnamed = true
    index.values_at(*genes).collect{|list| list.nil? ? nil : list.first}
  end
  task :translate => :array

  desc "Translate gene ids to a particular format given in another format"
  input :organism, :string, "Organism code", "Hsa"
  input :target_format, :string, "Target identifier format", "Ensembl Gene ID"
  input :source_format, :string, "Source identifier format", "Ensembl Gene ID"
  input :genes, :array, "Gene id list"
  def self.translate_from(organism, format, source, genes)
    index = index(organism, format, source)
    index.unnamed = true
    index.values_at(*genes).collect{|list| list.nil? ? nil : list.first}
  end
  task :translate_from => :array

  desc "Translate gene ids to a particular format. Return TSV"
  input :organism, :string, "Organism code", "Hsa"
  input :format, :string, "Target identifier format", "Ensembl Gene ID"
  input :genes, :array, "Gene id list"
  def self.tsv_translate(organism, format, genes)
    index = index(organism, format)
    tsv = TSV.setup({}, :key_field => "Gene", :fields => [format])
    genes.each do |gene|
      tsv[gene] = index[gene]
    end
    tsv
  end
  task :tsv_translate => :tsv

  desc "Translate gene ids to a particular format given in another format. Return TSV"
  input :organism, :string, "Organism code", "Hsa"
  input :target_format, :string, "Target identifier format", "Ensembl Gene ID"
  input :source_format, :string, "Source identifier format", "Ensembl Gene ID"
  input :genes, :array, "Gene id list"
  def self.tsv_translate_from(organism, format, source, genes)
    index = index(organism, format, source)
    tsv = TSV.setup({}, :key_field => source, :fields => [format])
    genes.each do |gene|
      tsv[gene] = index[gene]
    end
    tsv
  end
  task :tsv_translate_from => :tsv
  export_exec :translate, :translate_from, :tsv_translate, :tsv_translate_from

  #{{{ Protein
  
  desc "Translate protein ids to a particular format"
  input :organism, :string, "Organism code", "Hsa"
  input :format, :string, "Target identifier format", "Ensembl Protein ID"
  input :proteins, :array, "Protein id list"
  def self.translate_protein(organism, format, proteins)
    index = protein_index(organism, format)
    index.values_at(*proteins).collect{|list| list.nil? ? nil : list.first}
  end
  task :translate_protein => :array

  desc "Translate protein ids to a particular format given in another format"
  input :organism, :string, "Organism code", "Hsa"
  input :target_format, :string, "Target identifier format", "Ensembl Protein ID"
  input :source_format, :string, "Source identifier format", "Ensembl Protein ID"
  input :proteins, :array, "Protein id list"
  def self.translate_protein_from(organism, format, source, proteins)
    index = protein_index(organism, format, source)
    index.values_at(*proteins).collect{|list| list.nil? ? nil : list.first}
  end
  task :translate_protein_from => :array

  desc "Translate protein ids to a particular format. Return TSV"
  input :organism, :string, "Organism code", "Hsa"
  input :format, :string, "Target identifier format", "Ensembl Protein ID"
  input :proteins, :array, "Protein id list"
  def self.tsv_translate_protein(organism, format, proteins)
    index = protein_index(organism, format)
    tsv = TSV.setup({}, :key_field => "Protein", :fields => [format])
    proteins.each do |protein|
      tsv[protein] = index[protein]
    end
    tsv
  end
  task :tsv_translate_protein => :tsv

  desc "Translate protein ids to a particular format given in another format. Return TSV"
  input :organism, :string, "Organism code", "Hsa"
  input :target_format, :string, "Target identifier format", "Ensembl Gene ID"
  input :source_format, :string, "Source identifier format", "Ensembl Gene ID"
  input :proteins, :array, "Protein id list"
  def self.tsv_translate_protein_from(organism, target, source, proteins)
    index = protein_index(organism, target, source)
    tsv = TSV.setup({}, :key_field => source, :fields => [target])
    proteins.each do |protein|
      tsv[protein] = index[protein]
    end
    tsv
  end
  task :tsv_translate_protein_from => :tsv

  export_exec :translate_protein, :translate_protein_from, :tsv_translate_protein, :tsv_translate_protein_from

end
