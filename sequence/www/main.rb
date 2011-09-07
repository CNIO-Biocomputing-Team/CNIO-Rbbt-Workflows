require 'rbbt/util/log'
require 'rbbt/workflow'
require 'rbbt/workflow/rest'
require 'sinatra'
require 'compass'
require 'rbbt/sources/kegg'
require 'rbbt/sources/cancer'
require 'rbbt/sources/entrez'

%w(sequence translation structure mutation).each do |workflow_file|
  Workflow.require_workflow workflow_file
end

WorkflowREST.add_workflows Sequence, Structure, Mutation, Translation
WorkflowREST.setup

set :users, {"miki" => "miki", "tirso" => "tirso"}

Entity.define "Gene", *Organism.identifiers("Hsa").all_fields do
  html do |entity, type, locals|
    if entity.nil? or entity.empty?
      ""
    else
      IndiferentHash.setup(locals)

      if locals.include? :tsv and locals.include? :field

        translations = result_cache Translation, "translate", locals[:tsv].filename do
          genes = locals[:tsv].slice(locals[:field]).values.flatten.compact.uniq
          Misc.process_to_hash(genes.sort) do |genes| Translation.job(:translate, "Gene_Entity", :organism => locals[:organism], :format => "Associated Gene Name", :genes => genes).exec end
        end

        name = translations[entity]
      else
        name = Translation.translate(locals[:organism], "Associated Gene Name", [entity]).first
      end
      "<a class='entity #{ type }' href='#{File.join('/entity', type, entity)}?organism=#{locals[:organism]}'>#{ name || entity }</a>"
    end
  end

  filter do |query, type, locals, entity|
    if entity.nil? or entity.empty?
      false
    else
      if locals.include? :inputs and locals[:inputs].include? :organism 
        query_ens = Translation.translate(locals[:inputs][:organism], "Ensembl Gene ID", [query]).first
        entity_ens = Translation.translate(locals[:inputs][:organism], "Ensembl Gene ID", [entity]).first
        query_ens == entity_ens
      else
        query == entity
      end
    end
  end
end

Entity.define "Mutated Isoform" do
  html do |entity, type, locals|
    protein, change = entity.split ":"
    "<a class='entity #{ type }' href='#{File.join('/entity', type, entity)}?organism=#{locals[:organism]}'>#{ entity }</a>"
  end
end

Entity.define "Genomic Position", "Genomic Mutation" do
  tsv_sort do |key, pos|
    pos = pos.first if Array === pos
    chr, loc = pos.split(":").values_at(0, 1).collect{|v| v.to_i}
    ("%02d" % chr) + ":" + ("%020d" % loc)
  end

  html do |entity, type, locals|
    if not entity.nil?
      if genotype = context_job(Sequence, :genotype) and genotype.done? and not genotype.error?
        inputs = genotype.info[:inputs]

        junctions = result_cache "Sequence", "exon_junctions_at_genomic_positions", genotype.name do
          Sequence.job(:exon_junctions_at_genomic_positions, clean_jobname(genotype.name), :organism => inputs[:organism], :positions =>["local:genotype:#{genotype.name}"]).run
        end

        has_junction = ! (junctions[entity].nil? or junctions[entity]["Exon Junction"].nil? or junctions[entity]["Exon Junction"].empty?)

        "<a class='entity #{ type }' href='#{File.join('/entity', type, entity)}?organism=#{locals[:organism]}'>#{ entity } [#{(has_junction ? "E" : "")}]</a>"
      else
        "<a class='entity #{ type }' href='#{File.join('/entity', type, entity)}?organism=#{locals[:organism]}'>#{ entity }</a>"
      end
    end
  end
end

Entity.define "PDB" do
end

Entity.define "Uniprot" do
  html do |entity, type, locals|
    "<a class='#{ type }' href='http://www.uniprot.org/uniprot/#{entity}'>#{ entity }</a>"
  end
end

$kegg_pathways = KEGG.pathways.tsv(:list, :persist => true)
$cancer_interactions = Cancer.anais_interactions.tsv(:double, :persist => true, :merge => true, :key_field => "Term")

Entity.define "KEGG Pathway ID" do
  html do |entity, type, locals|
    name = $kegg_pathways[entity]
    if not name.nil?; then  name = name["Pathway Name"].sub!(/ -.*/, '') end

    cancers = $cancer_interactions[entity]

    if cancers.nil?
      cancers = []
    else
      cancers = cancers["Tumor Type"]
    end

    if not entity.nil?
      "<a class='entity #{ type }#{ cancers.any? ? ' cancer_associated' : ''}' href='#{File.join('/entity', type, entity)}?organism=#{locals[:organism]}'>\
      #{ name || entity }#{cancers.any? ? " <span class='cancer_list'>(" + cancers * ", " + ")</span>" : ""  }\
      </a>"
    end
  end

  sort_by do |entity, type, locals|
    cancers = $cancer_interactions[entity]

    if cancers.nil?
      cancers = []
    else
      cancers = cancers["Tumor Type"]
    end

    - cancers.length
  end

  tsv_sort do |key,keggs|
    if keggs.empty?
      -1
    else
      keggs.reject do |entity|
        $cancer_interactions[entity].nil?
      end.length
    end
  end

end

Entity.define "Tumor Type" do
  html do |entity, type, locals|
    entity || ""
  end

  tsv_sort do |key,cancers|
    cancers.length
  end
end
