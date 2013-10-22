$LOAD_PATH.push(File.expand_path('./lib'))
require 'cytoscape'
require 'link'
require 'rbbt/workflow'

class Graph
  extend Workflow
end


if __FILE__ == $0

  Graph.task :matrix => :tsv do
    Workflow.require_workflow "Genomics"
    require 'genomics_kb'
    require 'rbbt/entity/study'
    require 'rbbt/entity/study/genotypes'

    STUDY_DIR = "/home/mvazquezg/git/apps/ICGCScout/studies/"

    Study.study_dir = STUDY_DIR

    module Sample
      self.persist :mutations, :annotations
      self.persist :affected_genes, :annotations
    end

    module Study
      self.persist :affected_genes, :annotations
    end

    Study.studies.inject(nil) do |acc,study|
      Log.warn study
      Study.setup(study)
      if study.has_genotypes?

        gene_samples = study.knowledge_base.get_index(:sample_genes2, :source => "Ensembl Gene ID=>Associated Gene Name", :persist => true)
        matches = gene_samples.matches(study.affected_genes.name)

        incidence = Link.incidence(matches)
        incidence.key_field = "Associated Gene Name"
        incidence.namespace = study.organism

        if acc.nil?
          Log.warn "INIT #{ study }"
          acc = incidence
        else
          Log.error "Attach #{ study }"
          length = acc.fields.length
          incidence.keys.each do |gene|
            acc[gene] ||= [nil] * length
          end
          acc = acc.attach incidence, :fields => incidence.fields
        end
      end

      acc

    end
  end
  matrix = Graph.job(:matrix,nil).clean.run
  matrix.with_unnamed do
    matrix.monitor do
      matrix.through do |k,v| 
        v.replace v.collect{|v| v.nil? ? false : v }
      end
    end
  end


  Graph.task :sample_study => :tsv do

    Workflow.require_workflow "Genomics"
    require 'genomics_kb'
    require 'rbbt/entity/study'
    require 'rbbt/entity/study/genotypes'

    STUDY_DIR = "/home/mvazquezg/git/apps/ICGCScout/studies/"

    Study.study_dir = STUDY_DIR

    module Sample
      self.persist :mutations, :annotations
      self.persist :affected_genes, :annotations
    end

    module Study
      self.persist :affected_genes, :annotations
    end

    sample_study = TSV.setup({}, :key_field => "Sample", :fields => ["Study"], :type => :single)
    Study.studies.each do |study|
      Log.warn study
      Study.setup(study)
      study.samples.select_by(:has_genotype?).each do |sample|
        sample_study[sample] = study
      end
      
    end
    sample_study
  end
  sample_study_job = Graph.job(:sample_study ,nil)
  sample_study_job.run

  require 'rbbt/util/R'
  matrix.R_interactive <<-EOR
library(ggplot2)
library(reshape2)

d = t(rbbt.tsv(file=data_file, stringsAsFactors=TRUE));
colnames(d) <- make.names(colnames(d))
d = (d == "true")

sample_study = rbbt.tsv(file='#{ sample_study_job.path.find }');

d.m = melt(d)

names(d.m) = c("Sample", "Gene", "Value")

  EOR
  
end
