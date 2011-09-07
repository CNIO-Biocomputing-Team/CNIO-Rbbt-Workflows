require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/mutation/snps_and_go'
require 'rbbt/mutation/sift'
require 'rbbt/mutation/mutation_assessor'

Workflow.require_workflow "translation"

module Mutation
  extend Workflow

  desc "Severity prediction for mutated protein isoforms"
  input :organism, :string, "Organism code", "Hsa"
  input :mutations, :array, "Amino acid mutations. <Ensembl Protein ID>:<wildtype aminoacid><position><mutant aminoacid>"
  def self.isoform_mutation_severity(organism, mutations)
    tsv = TSV.setup({}, :type => :list, :key_field => "Mutated Isoform", :fields => ["Protein Mutation", "Mutation Type", "Ensembl Protein ID", "UniProt/SwissProt Accession", "RefSeq Protein ID", "UniProt/SwissProt ID"])

    mut_isoform2uniprot = Misc.process_to_hash(mutations) do |mutations| 
      Translation.translate_protein_from(organism, "UniProt/SwissProt Accession", "Ensembl Protein ID", mutations.collect{|m| m.split(":").first})
    end

    mut_isoform2refseq = Misc.process_to_hash(mutations) do |mutations| 
      Translation.translate_protein_from(organism, "RefSeq Protein ID", "Ensembl Protein ID", mutations.collect{|m| m.split(":").first})
    end

    mut_isoform2uni_id = Misc.process_to_hash(mutations) do |mutations| 
      Translation.translate_protein_from(organism, "UniProt/SwissProt ID", "Ensembl Protein ID", mutations.collect{|m| m.split(":").first})
    end

    mutations.each do |mutation|
      ensembl, protein_mutation = mutation.split(":").values_at 0, 1
      mutation_type = case
                      when protein_mutation =~ /UTR/
                        "UTR"
                      when protein_mutation =~ /[A-Z]\d+[^\d]{2,}/
                        "Indel"
                      when protein_mutation[0] == mutation[-1]
                        "Synonymous"
                      when protein_mutation[-1] == "*"
                        "Truncated"
                      else
                        "Non Synonymous"
                      end

      tsv[mutation] = [protein_mutation, mutation_type, ensembl, mut_isoform2uniprot[mutation] || nil, mut_isoform2refseq[mutation] || nil, mut_isoform2uni_id[mutation] || nil]
    end

    #SNPSandGO.add_predictions tsv
    #SIFT.add_predictions tsv
    MutationAssessor.add_predictions tsv

    tsv
  end
  task :isoform_mutation_severity => :tsv
  export_exec :isoform_mutation_severity

  desc "Severity prediction for mutated protein isoforms"
  input :organism, :string, "Organism code", "Hsa"
  input :mutations, :array, "Mutation Chr:Position:Mut (e.g. 19:54646887:A). Separator can be ':', space or tab. Extra fields are ignored"
  def self.mutation_severity_for_genomic_mutations(organism, mutations)
    tsv = Sequence.job(:mutated_isoforms_for_genomic_mutations, "Mutation", :organism => organism, :mutations => mutations).run
    mutated_isoforms = []

    tsv.through "Mutated Isoform", [] do |key, values|
      mutated_isoforms << key
    end

    mutation_severity = isoform_mutation_severity(organism, mutated_isoforms)

    tsv.attach mutation_severity, :one2one => true

    tsv.key_field = "Genomic Position"
    exons = Sequence.job(:exon_junctions_at_genomic_positions, "Mutation", :organism => organism, :positions => mutations).exec
    tsv.attach exons
    tsv.key_field = "Genomic Mutation"

    tsv.add_field "Severity Score" do |key, values|
      score = 0

      # Mutation Type
      case
      when (values["Mutation Type"].include?("Truncated") or values["Mutation Type"].include? "Indel")
        score += 0
      when values["Mutation Type"].include?("Non Synonymous")
        score += 0
      end

      # Exon Junctions
      score += 0 if values["Exon Junction"] and values["Exon Junction"].any?

      # Predictors
      #score += 2 if values["SIFT:Prediction"].select{|v| v =~ /DAMAG/i}.any?
      #score += 2 if values["SNPs&GO:Prediction"].select{|v| v =~ /disea/i}.any?

      ddd values["MutationAssessor:Prediction"]
      case
      when values["MutationAssessor:Prediction"].select{|v| v and v =~ /high/i}.any?
        score += 3  
      when values["MutationAssessor:Prediction"].select{|v| v and v =~ /medium/i}.any?
        score += 2  
      when values["MutationAssessor:Prediction"].select{|v| v and v =~ /low/i}.any?
        score += 1  
      end

      [score]
    end

    tsv
  end
  task :mutation_severity_for_genomic_mutations=> :tsv
  export_asynchronous :mutation_severity_for_genomic_mutations

end
