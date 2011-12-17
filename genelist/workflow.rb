require 'rbbt'
require 'rbbt/util/misc'
require 'rbbt/workflow'
require 'rbbt/workflow/rest/entity'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/entity'
require 'rbbt/entity/gene'
require 'rbbt/sources/go'
require 'rbbt/sources/kegg'
require 'rbbt/sources/organism'
require 'rbbt/sources/NCI'
require 'rbbt/sources/pfam'

[Gene, GOTerm, KeggPathway, NCINaturePathway, NCIBioCartaPathway, NCIReactomePathway, PfamDomain].each do |mod|
  mod.module_eval do
    include Entity::REST
  end
end

Workflow.require_workflow 'Translation'
Workflow.require_workflow 'Enrichment'

module GeneList
  extend Workflow



  input :tsv, :tsv, "Gene list in the appropriate format"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  def self.tsv_annotate_gene_list(tsv, organism)
    tsv.identifiers = Organism.identifiers(organism).find

    tsv = tsv.attach Organism.gene_go_bp(organism).find, :fields => ["GO ID"], :persist_input => true
    tsv = tsv.attach Organism.gene_pfam(organism).find, :fields => ["Pfam Domain"], :persist_input => true

    if organism =~ /^Hsa/
      tsv = tsv.attach KEGG.gene_pathway.find, :fields => ["KEGG Pathway ID"], :persist_input => true
      tsv.identifiers = Organism.identifiers(organism).find
      tsv = tsv.attach NCI.nature_pathways.find, :fields => ["NCI Nature Pathway ID"], :persist_input => true
      tsv = tsv.attach NCI.biocarta_pathways.find, :fields => ["NCI BioCarta Pathway ID"], :persist_input => true
      tsv = tsv.attach NCI.reactome_pathways.find, :fields => ["NCI Reactome Pathway ID"], :persist_input => true
    else
      remove_ensmbl = false
      case
      when tsv.key_field == "Ensembl Gene ID"
        ensembl = tsv.keys
      when tsv.fields.include?("Ensembl Gene ID")
        ensembl = tsv.slice("Ensembl Gene ID").flatten
      else
        ensembl = tsv.attach(Organism.identifiers(organism), :fields => "Ensembl Gene ID").slice("Ensembl Gene ID").values.flatten
        remove_ensmbl = true
      end

      ensembl = Gene.setup(ensembl, "Ensembl Gene ID", organism)

      human_ensembl = ensembl.ortholog("Hsa")
      human_tsv = annotate_gene_list(human_ensembl.flatten.compact.uniq, "Hsa")

      annotations = human_tsv.fields - tsv.fields - ["Ensembl Gene ID"]
      new = TSV.setup(Misc.process_to_hash(ensembl){ensembl.collect{[]}}, :key_field => "Ensembl Gene ID", :type => :double, :fields => [])
      new.fields.concat annotations
      ensembl.zip(human_ensembl).each do |orig, orthologs|
        next if orthologs.nil?
        values = orthologs.collect{|ortholog|
          human_tsv[ortholog].values_at *annotations
        }
        values.each do |list|
          list.each_with_index do |list, i|
            next if list.nil?
            new[orig][annotations[i]] ||= []
            new[orig][annotations[i]].concat (list - new[orig][annotations[i]])
          end
        end
      end
      tsv.attach new, :fields => annotations
      tsv = tsv.slice tsv.fields - ["Ensembl Gene ID"] if remove_ensmbl
    end

    tsv.namespace = organism
    tsv
  end
  task :tsv_annotate_gene_list => :tsv
  export_synchronous :tsv_annotate_gene_list




  input :list, :array, "Gene list in the appropriate format"
  input :organism, :string, "Organism code (not used for kegg)", "Hsa"
  def self.annotate_gene_list(list, organism)
    ensembl = Gene.setup(Translation.job(:translate, nil, :format => "Ensembl Gene ID", :genes => list, :organism => organism).run.compact,"Ensembl Gene ID", organism)
    tsv = TSV.setup(Misc.process_to_hash(ensembl){ensembl.collect{[]}}, :key_field => "Ensembl Gene ID", :type => :double, :fields => [])

    tsv_annotate_gene_list(tsv,organism)
  end
  task :annotate_gene_list => :tsv
  export_exec :annotate_gene_list


end
