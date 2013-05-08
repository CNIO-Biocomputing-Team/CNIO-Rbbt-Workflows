require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/sources/organism'
require 'rbbt/sources/uniprot'
require 'ssw'

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
    alignment != nil and alignment[:identity] > ALIGNMENT_THRESHOLD and alignment[:range].include? position
  end
  task :position_over_domain => :boolean
  export_exec :position_over_domain

  desc "Find if position in sequence overlaps cath domains"
  input :sequence, :text, "Protein sequence"
  input :position, :integer, "Position in the protein sequence"
  input :pdb, :string, "PDB"
  def self.position_over_pdb(sequence, position, domain)
    alignment = Cath.align(domain, sequence)
    alignment != nil and alignment[:identity] > ALIGNMENT_THRESHOLD and alignment[:range].include? position
  end
  task :position_over_pdb => :boolean
  export_exec :position_over_pdb


  desc "Find PDBs for uniprot entry"
  input :uniprot, :string, "UniProt/SwissProt Accession"
  def self.pdbs(uniprot)
    UniProt.pdbs(uniprot).keys
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
      ensembl = Translation.job(:translate, nil, :organism => organism, :format => "Ensembl Protein ID", :genes => [protein]).exec
      ensembl = ensembl.first unless ensembl.nil?
      raise "Could not translate to Ensembl Protein ID" if ensembl.nil?
    end

    sequence = Organism.protein_sequence(organism).tsv(:persist =>  true)[ensembl]
    raise "No sequence for protein: #{ protein }" if sequence.nil?

    uniprots = Translation.job(:translate, nil, :organism => organism, :format => "UniProt/SwissProt Accession", :genes => [protein]).exec
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
      ensembl = Translation.job(:translate, nil, :organism => organism, :format => "Ensembl Protein ID", :genes => [protein]).exec
      ensembl = ensembl.first unless ensembl.nil?
      raise "Could not translate to Ensembl Protein ID" if ensembl.nil?
    end

    sequence = Organism.protein_sequence(organism).tsv(:persist =>  true)[ensembl]
    raise "No sequence for protein: #{ protein }" if sequence.nil?

    uniprots = Translation.job(:translate, nil, :organism => organism, :format => "UniProt/SwissProt Accession", :genes => [protein]).exec
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

  input :protein_ranges, :array, "Protein ranges e.g.: ENSP00001203123:234:344"
  input :organism, :string, "Organism code", "Hsa"
  task :uniprot_variants_over_protein_ranges => :tsv do |protein_ranges, organism|
    uniprot_variants = UniProt.annotated_variants.tsv :key_field => "UniProt/SwissProt Accession", :persist => true, :merge => true, :type => :double
    proteins = {}

    protein_ranges.collect do |line|
      next unless line =~ /:/
      protein, start, eend = line.split(":")

      proteins[protein] ||= []
      proteins[protein] << (start.to_i..eend.to_i)
    end

    all_proteins = proteins.keys

    protein2uniprot = Misc.process_to_hash(all_proteins){|list| Translation.job(:translate_protein, "Structure[uniprot_variants_over_protein_range]", :proteins => all_proteins, :organism => organism, :format => "UniProt/SwissProt Accession").run}

    results = TSV.setup({}, :key_field => "Protein Range", :fields => ["UniProt Variant ID"], :type => :flat)
    aam_pos = uniprot_variants.identify_field "Amino Acid Mutation"
    uniprot_var_pos = uniprot_variants.identify_field "UniProt Variant ID"
    proteins.collect{|protein, ranges|
      uniprot = protein2uniprot[protein]

      ranges.each do |range|
        next unless uniprot_variants.include? uniprot
        results[[protein, range.begin, range.end] * ":"] =  
          uniprot_variants[uniprot].zip_fields.select{|values|  range.include? values[aam_pos].scan(/\d+/)[0].to_i}.collect{|values| values[uniprot_var_pos]}
      end
    }

    results
  end
  export_exec :uniprot_variants_over_protein_ranges

  input :sequence, :text, "Protein sequence"
  input :position, :integer, "Position within protein sequence"
  input :pdb, :string, "Name of pdb to align"
  task :sequence_position_in_pdb => :yaml do |protein_sequence, protein_position, pdb|
    Log.debug "Amino acid in sequence position #{ protein_position }: #{protein_sequence[protein_position - 1].chr}"
    atoms = CMD.cmd('grep "^ATOM"', :in => Open.read("http://www.pdb.org/pdb/files/#{ pdb }.pdb.gz")).read

    chains = {}
    atoms.split("\n").each do |line|
      chain = line[20..21].strip
      aapos = line[22..25].to_i
      aa    = line[17..19]
      
      next if aapos < 0

      chains[chain] ||= Array.new
      chains[chain][aapos] = aa
    end

    alignments = {}
    chains.each do |chain,chain_sequence|
      log "Pdb #{ pdb}, chain #{ chain }."

      chain_sequence = chain_sequence.collect{|aa| aa.nil? ? '?' : Misc::THREE_TO_ONE_AA_CODE[aa.downcase]} * ""

      chain_alignment, protein_alignment = SmithWaterman.align(chain_sequence, protein_sequence)

      ddd chain_alignment
      ddd protein_alignment

      if protein_position > protein_alignment.length
        alignments[chain] = nil
        next
      end
      

      gaps = 0
      chars = 0
      while (chars - gaps) < protein_position do
        gaps +=1 if protein_alignment[chars].chr == '-' 
        chars += 1
      end

      protein_position_in_alignment = protein_position + gaps

      alignments[chain] = if protein_alignment[protein_position_in_alignment-1].chr == '-'
                            nil
                          else
                            chain_position_in_alignment = protein_position_in_alignment - protein_alignment.match(/^(_*)/)[1].length + chain_alignment.match(/^(_*)/)[1].length
                            chain_gaps = chain_alignment[(0..chain_position_in_alignment-1)].chars.select{|c| c == "-"}.length
                            chain_position = chain_position_in_alignment - chain_gaps
                            if protein_sequence[protein_position - 1] != chain_sequence[chain_position - 1]
                              Log.debug "Not equal: #{protein_sequence[protein_position-4..protein_position+2]} => #{chain_sequence[chain_position-4..chain_position+2]}"
                            else
                              Log.debug "Equal: #{protein_sequence[protein_position-4..protein_position+2]} => #{chain_sequence[chain_position-4..chain_position+2]}"
                              chain_position
                            end
                          end
    end

    alignments
  end
  export_exec :sequence_position_in_pdb
end

if defined? Entity and defined? MutatedIsoform and Entity === MutatedIsoform
  module MutatedIsoform
    property :pdbs_and_positions => :single do
      return [] if pdbs.nil?
      pdbs.collect do |pdb, info|
        [pdb, Structure.job(:sequence_position_in_pdb, "Protein: #{ self }", :sequence => protein.sequence, :organism => organism, :position => position, :pdb => pdb).run]
      end
    end
  end
end
