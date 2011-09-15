$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rbbt/util/open'
require 'cath'

module Uniprot
  UNIPROT_TEXT="http://www.uniprot.org/uniprot/[PROTEIN].txt"

  def self.pdbs(protein)
    url = UNIPROT_TEXT.sub "[PROTEIN]", protein
    text = Open.read(url)

    pdb = {}
    text.split(/\n/).each{|l| 
      next unless l =~ /^DR\s+PDB; (.*)\./
      id, method, resolution, region = $1.split(";").collect{|v| v.strip}
      start, eend = region.match(/=(\d+)-(\d+)/).values_at(1,2)
      pdb[id.downcase] = {:method => method, :resolution => resolution, :region => (start.to_i..eend.to_i)}
    }
    pdb
  end

  def self.variants(protein)
    url = UNIPROT_TEXT.sub "[PROTEIN]", protein
    text = Open.read(url)

    text = text.split(/\n/).select{|line| line =~ /^FT/} * "\n"

    parts = text.split(/^(FT   \w+)/)
    parts.shift

    variants = []

    type = nil
    parts.each do |part|
      if type.nil?
        type = part
      else
        if type !~ /VARIANT/
          type = nil
          next
        end
        type = nil
        
        value = part.gsub("\nFT", '').gsub(/\s+/, ' ')
        # 291 291 K -> E (in sporadic cancers; somatic mutation). /FTId=VAR_045413.
        case
        when value.match(/(\d+) (\d+) ([A-Z])\s*\-\>\s*([A-Z]) (.*)\. \/FTId=(.*)/)
          start, eend, ref, mut, desc, id = $1, $2, $3, $4, $5, $6
        when value.match(/(\d+) (\d+) (.*)\. \/FTId=(.*)/)
          start, eend, ref, mut, desc, id = $1, $2, nil, nil, $3, $4
        else
          Log.debug "Value not understood: #{ value }"
        end
        variants << {
          :start => start, 
          :end => eend, 
          :ref => ref,
          :mut => mut, 
          :desc => desc, 
          :id => id,
        }
      end
    end

    variants
  end


  def self.cath(protein)
    url = UNIPROT_TEXT.sub "[PROTEIN]", protein
    text = Open.read(url)

    cath = {}
    text.split(/\n/).each{|l| 
      next unless l =~ /^DR\s+Gene3D; G3DSA:(.*)\./
      id, description, cuantity = $1.split(";").collect{|v| v.strip}
      cath[id] = {:description => description, :cuantity => cuantity}
    }
    cath
  end

  def self.cath_domains(protein)
    pdbs = pdbs(protein).keys.uniq
    pdbs.collect do |pdb|
      Cath.domains_for_pdb(pdb)
    end.flatten.compact
  end

  def self.pdbs_covering_aa_position(protein, aa_position)
    Uniprot.pdbs(protein).select do |pdb, info|
      info[:region].include? aa_position
    end
  end
end
