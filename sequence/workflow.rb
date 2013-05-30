require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/sources/organism'
require 'sequence'
require 'bio'

module Sequence

  extend Workflow

  desc "Process an VCF file and return the list of genomic mutations"
  input :vcf, :text, "VCF file"
  input :expanded, :boolean, "Add additional information", false
  input :unique, :boolean, "Remove repeated mutations", false
  returns "Genomic Mutation"
  task :process_vcf => :array do |vcf, expanded, unique|
    raise "No VCF specified" if vcf.nil?
    mutations = []
    vcf.split("\n").each do |line|
      line = line.strip
      next if line.empty? or line =~ /^#/
      chr, pos, id, ref, mut_str, qual, filter, *rest = line.split(/\s+/)
      
      chr.sub!(/chr/,'')
      pos = pos.to_i

      pos, muts = Misc.correct_vcf_mutation(pos, ref, mut_str)

      if expanded
        mutations << [chr, pos, muts * ",", qual, filter, rest.join(":").gsub(/[\/?\|]/,'-'), id] * ":"
      else
        mutations << [chr, pos, muts * ","] * ":"
      end
    end

    if unique
      m = {}
      mutations.each do |mut|
        c,p,a,q = mut.split(":").values_at 0,1,2,3
        key = [c,p,a] * ":"
        if m[key]
          prev_q = m[key].last
          if q.to_f > prev_q.to_f
            m[key] = [mut, q]
          end
        else
            m[key] = [mut, q]
        end
      end
      mutations = m.collect{|k,v| v.first}
    end

    mutations
  end

  export_synchronous :process_vcf
end
