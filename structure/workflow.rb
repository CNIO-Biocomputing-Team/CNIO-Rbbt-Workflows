require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/sources/organism'
require 'cath'
require 'uniprot'

Workflow.require_workflow 'Translation'
module Structure
  extend Workflow

  ALIGNMENT_THRESHOLD = 80

  desc "Find Cath domains for protein"
  input :uniprot, :string, "UniProt/SwissProt Accession"
  def self.cath_domains(uniprot)
    Uniprot.cath_domains(uniprot)
  end
  task :cath_domains => :array
  export_exec :cath_domains

  desc "Find if position in sequence overlaps cath domains"
  input :sequence, :text, "Protein sequence"
  input :position, :integer, "Position in the protein sequence"
  input :domain, :string, "Cath domain"
  def self.position_over_domain(sequence, position, domain)
    alignment = Cath.align(domain, sequence)
    alignment and alignment[:identity] > ALIGNMENT_THRESHOLD and alignment[:range].include? position
  end
  task :position_over_domain => :boolean
  export_exec :position_over_domain

  desc "Find if position in sequence overlaps cath domains"
  input :sequence, :text, "Protein sequence"
  input :position, :integer, "Position in the protein sequence"
  input :pdb, :string, "PDB"
  def self.position_over_pdb(sequence, position, domain)
    alignment = Cath.align(domain, sequence)
    alignment and alignment[:identity] > ALIGNMENT_THRESHOLD and alignment[:range].include? position
  end
  task :position_over_domain => :boolean
  export_exec :position_over_domain


  desc "Find PDBs for uniprot entry"
  input :uniprot, :string, "UniProt/SwissProt Accession"
  def self.pdbs(uniprot)
    Uniprot.pdbs(uniprot).keys
  end
  task :pdbs => :array
  export_exec :pdbs

  desc "Find cath domains for protein"
  input :organism, :string, "Organism code", "Hsa"
  input :protein, :string, "Protein ID, preferably Ensembl Protein ID"
  def self.protein_cath_domains(organism, protein)
    if protein =~ /^ENSP/
      ensembl = protein
    else
      ensembl = Translation.translate(organism, "Ensembl Protein ID", protein)
      ensembl = ensembl.first unless ensembl.nil?
      raise "Could not translate to Ensembl Protein ID" if ensembl.nil?
    end

    sequence = Organism.protein_sequence(organism).tsv(:persist =>  true)[ensembl]
    raise "No sequence for protein: #{ protein }" if sequence.nil?

    uniprots = Translation.translate(organism, "UniProt/SwissProt Accession", [protein]).first
    uniprots.collect{|uniprot| Uniprot.cath_domains(uniprot).collect{|dom| [uniprot, dom] * ":"}}.flatten
  end
  task :protein_cath_domains => :array
  export_synchronous :protein_cath_domains

  desc "Protein variant descriptions and structural info"
  input :organism, :string, "Organism code", "Hsa"
  input :protein, :string, "Protein ID, preferably Ensembl Protein ID"
  def self.protein_variant_analysis(organism, protein)
    tsv = TSV.setup({}, :key_field => "Uniprot Variant ID", :fields => ["Uniprot/SwissProt Accession", "Start", "End", "Reference", "Mutation", "Description", "Cath Domains", "Cath Codes"], :type => :double)

    if protein =~ /^ENSP/
      ensembl = protein
    else
      ensembl = Translation.translate(organism, "Ensembl Protein ID", protein)
      ensembl = ensembl.first unless ensembl.nil?
      raise "Could not translate to Ensembl Protein ID" if ensembl.nil?
    end

    sequence = Organism.protein_sequence(organism).tsv(:persist =>  true)[ensembl]
    raise "No sequence for protein: #{ protein }" if sequence.nil?

    uniprots = Translation.translate(organism, "UniProt/SwissProt Accession", [protein]).first
    domain_codes = Rbbt.share.databases.CATH.CathDomainList.tsv :persist => true

    uniprots.each do |uniprot|
      variants = Uniprot.variants(uniprot)

      domains = Misc.process_to_hash(Uniprot.cath_domains(uniprot)) do |domains|
        domains.collect do |domain|
          Cath.align(domain, sequence)
        end
      end

      variants.each do |variant|
        start = variant[:start]
        if start.nil?
          matching_domains = []
        else
          matching_domains = domains.select{|domain, info| info and info[:identity] > ALIGNMENT_THRESHOLD and info[:range].include? start.to_i }.collect{|domain, info| domain}
        end

        cath_codes = matching_domains.collect{|domain| 
          values = domain_codes[domain]
          values[0..3] * "."
        }

        tsv[variant[:id]] = [uniprot, variant[:start], variant[:end], variant[:ref], variant[:mut], variant[:desc], matching_domains, cath_codes]
      end
    end

    tsv
  end
  task :protein_variant_analysis => :tsv
  export_synchronous :protein_variant_analysis
end
