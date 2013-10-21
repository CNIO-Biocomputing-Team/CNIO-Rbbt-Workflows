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
          acc = acc.attach incidence, :fields => incidence.fields
        end
      end

      acc

    end
  end

  Graph.job(:matrix,nil).run
end
