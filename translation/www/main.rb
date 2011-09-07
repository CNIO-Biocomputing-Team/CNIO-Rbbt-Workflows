require 'rbbt/util/log'
require 'rbbt/workflow'
require 'rbbt/workflow/rest'
require 'sinatra'
require 'compass'

WorkflowREST.add_workflows *%w(sequence translation EPAR)
WorkflowREST.setup

Entity.define "Gene" do
  html do |entity, type, locals|
    name = Translation.translate(locals[:organism], "Associated Gene Name", [entity]).first
    "<a class='entity #{ type }' href='#{File.join('/entity', type, entity)}?organism=#{locals[:organism]}'>#{ name }</a>"
  end

  sort_by do |entity, type, locals| entity end
end

Entity.define "Isoform Mutation" do
  html do |entity, type, locals|
    protein, change = entity.split ":"
    "<a class='#{ type }' href='http://www.ensembl.org/Homo_sapiens/Transcript/ProteinSummary?db=core;t=#{protein}'>#{ entity }</a>"
  end

  sort_by do |entity, type, locals| 
    protein, change = entity.split ":"
    case
    when change =~ /\*/
      2
    when change =~ /UTR5/
      0
    else
      0
    end
  end
end

Entity.define "Genetic Mutation" do
end
