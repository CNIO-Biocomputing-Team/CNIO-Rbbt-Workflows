require 'rbbt'
require 'rbbt/resource'
module Cath
  extend Resource

  Rbbt.claim Rbbt.share.databases.CATH.CathNames, :proc do
    tsv = TSV.setup({}, :key_field => "CATH Code", :type => :list, :fields => ["PDB ID", "CATH Domain", "CATH Description"])
    Open.read("http://release.cathdb.info/v3.4.0/CathNames").split(/\n/).each do |line|
      next if line =~ /^#/
      code, pdb, domain, name = line.match(/([\d\.]+)\s+(\w\w\w\w)(\w\w\w)\s+:(.*)/).values_at 1,2,3,4
      tsv[code] = [pdb.downcase, domain, name]
    end

    tsv.to_s
  end

  Rbbt.claim Rbbt.share.databases.CATH.CathUnclassifiedList , :proc do
    Open.read("http://release.cathdb.info/v3.4.0/CathUnclassifiedList").split(/\n/).collect do |line|
      next if line =~ /^#/
      line.split(/\s/).first
    end * "\n"
  end


  Rbbt.claim Rbbt.share.databases.CATH.CathDomainSeqs, :proc do
    tsv = TSV.setup({}, :key_field => "CATH Domain", :type => :single, :fields => ["Cath Domain Sequence"])

    Open.read("http://release.cathdb.info/v3.4.0/CathDomainSeqs.ATOM").split(/>pdb\|/).each do |chunk|
      next if chunk.empty?
      domain, sequence = chunk.strip.match(/(.*)\n(.*)/).values_at 1, 2
      tsv[domain] = sequence
    end

    tsv.to_s
  end


  Rbbt.claim Rbbt.share.databases.CATH.CathRegions, :proc do
    domains = TSV.setup({}, :key_field => "Cath Domain", :type => :double, :fields => ["Start", "End"])
    Open.read("http://release.cathdb.info/v3.4.0/CathDomall").split(/\n/).each do |line|
      next if line =~ /^#/
      chain, ndomains, nfragments, rest = line.match(/(\w\w\w\w\w)\s+D(\d+)\s+F(\d+)\s+(.*)/).values_at 1,2,3,4
      
      ndomains.to_i.times do |dn|
        nsegments, rest = rest.match(/^\s*(\d+)\s+(.*)/).values_at 1, 2
        segments = []
        nsegments.to_i.times do |sn|
          start, eend, rest = rest.match(/\w\s+(-?\d+)\s+.\s+\w\s+(-?\d+)\s+.(.*)/).values_at 1, 2, 3
          segments << [start, eend]
        end

        domain = chain + "%02d" % dn.to_i
        segments = segments[0].zip(*segments[1..-1])
        domains[domain] = segments
      end
    end

    domains.to_s
  end

  Rbbt.claim Rbbt.share.databases.CATH.CathDomainList, :proc do
    domains = TSV.setup({}, :key_field => "Cath Domain", :type => :double, :fields => ["CATH domain name (seven characters)",
                        "Class number", "Architecture number", "Topology number", "Homologous superfamily number", "S35 sequence cluster number",
                        "S60 sequence cluster number", "S95 sequence cluster number", "S100 sequence cluster number", "S100 sequence count number",
                        "Domain length", "Structure resolution (Angstroms)"], :type => :list)

    Open.read("http://release.cathdb.info/v3.4.0/CathDomainList").split(/\n/).each do |line|
      next if line =~ /^#/
      parts = line.chomp.split /\s+/
      domain = parts.shift
      domains[domain] = parts
    end

    domains.to_s
  end


  def self.cath_index
    @@cath ||= Rbbt.share.databases.CATH.CathNames.tsv :persist => true, :case_insensitive => true
  end

  def self.pdb_index
    if not defined? @@pdb or @@pdb.nil?
      @@pdb = {}
      Rbbt.share.databases.CATH.CathDomainSeqs.read.split("\n").each do |line|
        domain = line.split(/\t/).first
        pdb = domain[0..3]
        @@pdb[pdb] ||= []
        @@pdb[pdb] << domain
      end
    end
    @@pdb
  end

  def self.unclassified
    @@unclassified = {}
    Rbbt.share.databases.CATH.CathUnclassifiedList.read.split("\n").each do |domain|
      pdb = domain[0..3]
      @@unclassified[pdb] ||= []
      @@unclassified[pdb] << domain
    end
    @@unclassified
  end

  def self.domain_sequences
    @@domain_sequences ||= Rbbt.share.databases.CATH.CathDomainSeqs.tsv(:persist => true)
  end

  def self.pdbs(cath_code)
    cath = cath_index
    if cath.include? cath_code
      cath[cath_code]["PDB ID"]
    else
      nil
    end
  end

  def self.domains_for_pdb(pdb)
    pdb2cath = pdb_index
    (pdb2cath[pdb] || []) + (unclassified[pdb] || [])
  end

  def self.align(domain, sequence)
    require 'bio'

    return nil if not domain_sequences.include? domain

    TmpFile.with_file(">target\n" << sequence) do |target|
      TmpFile.with_file(">domain\n" << domain_sequences[domain]) do |domain|

        result = CMD.cmd("fasta35 #{ target } #{ domain }").read

        if result.match(/([\d\.]+)% identity.*overlap \((\d+)-(\d+):/s)
          {:identity => $1.to_f, :range => ($2.to_i..$3.to_i)}
        else
          false
        end
      end
    end
  end
end

