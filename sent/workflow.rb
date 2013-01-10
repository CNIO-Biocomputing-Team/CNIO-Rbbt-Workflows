require 'rbbt/workflow'
require 'rbbt/entity/gene'
require 'rbbt/entity/pmid'
require 'rbbt/bow/dictionary'
require 'rbbt/util/R'

module SENT
  extend Workflow

  input :genes, :array, "List of genes", []
  input :limit, :integer, "Total number of terms", 500
  input :organism, :string, "Organism code", "Hsa"
  task :dictionary => :tsv do |genes, limit, organism|
    set_info :organism, organism
    dict = Dictionary::TF_IDF.new

    genes = Translation.job(:translate, "SENT", :target => "Ensembl Gene ID", :organism => organism, :genes => genes).exec

    Gene.setup(genes, "Ensembl Gene ID", organism)
    
    all_articles = genes.articles.compact.flatten.uniq
    article_text = Misc.process_to_hash(all_articles){|list| list.text}

    genes.each do |gene|
      articles = gene.articles

      meta_text = article_text.values_at(*articles).compact.collect{|t| 
        begin 
          t.encode("UTF-8") if t.respond_to? :encode;
        rescue 
        end  
        Misc.fixutf8(t)
      } * "\n"
      dict.add Misc.counts(meta_text.words).collect{|t,c| [t, c == 0 ? 0 : c]}
    end

    best = dict.best(:hi => 0.8, :low => 0.01, :limit => limit)
    TSV.setup(best, :key_field => "Term", :fields => ["Weight"], :type => :single, :cast => :to_f)
  end

  dep :dictionary
  input :genes, :array, "List of genes", []
  task :metadocument => :tsv do |genes|
    organism = step(:dictionary).info[:organism]
    set_info :organism, organism
    best = step(:dictionary).load.sort_by("Weight", true).reverse

    genes = Translation.job(:translate, "SENT", :target => "Ensembl Gene ID", :organism => organism, :genes => genes).exec
    Gene.setup(genes, "Ensembl Gene ID", organism)
     
    all_articles = genes.articles.compact.flatten.uniq
    article_text = Misc.process_to_hash(all_articles){|list| list.text}

    metadocument = {}
    genes.each do |gene|
      articles = gene.articles
      meta_text = article_text.values_at(*articles).compact * "\n"
      metadocument[gene] = Misc.counts(meta_text.words).values_at *best
    end

    TSV.setup(metadocument, :key_field => "Ensembl Gene ID", :fields => best, :type => :list, :cast => :to_i)
  end

  dep :metadocument
  input :rank, :integer, "Number of factors"
  task :nmf => :yaml do |rank|
    set_info :organism, step(:metadocument).info[:organism]
    FileUtils.mkdir_p(File.dirname(file('factors')))
    puts R.run(<<-EOF
library(NMF)

dictionary = rbbt.tsv('#{step(:dictionary).path}')
counts = rbbt.tsv('#{step(:metadocument).path}')

matrix = counts * t(dictionary)
matrix = as.matrix(matrix[apply(matrix, 1, sum) > 0,])

n = nmf(matrix, #{rank})

h = n@fit@H
w = n@fit@W

factor.names <- sapply(seq(1, dim(h)[1]), function(x){ paste("Factor", x, sep=" ") })

rownames(h) <- factor.names;
colnames(w) <- factor.names;

rbbt.tsv.write('#{file('factor_profiles')}', h, key.field = "Factor");
rbbt.tsv.write('#{file('gene_profiles')}', w, key.field = "Ensembl Gene ID");
     EOF
).read

    factors = TSV.open file('factor_profiles'), :type => :list, :unnamed => true, :cast => :to_f
    groups  = TSV.open file('gene_profiles'), :type => :list, :unnamed => true, :cast => :to_f

    terms = factors.fields
    factor_names = factors.keys

    factor_terms = {}
    factors.collect{|factor, values|  
      ordered = Misc.zip2hash(terms, values).sort_by{|term, value| value}.collect{|term, value| term}.reverse
      factor_terms[factor] = ordered
    }

    gene_factors = {}
    groups.collect{|gene, values|  
      mean = Misc.mean(values)
      top_factors = Misc.zip2hash(factor_names, values).select{|factor, value| value > mean}.collect{|factor,value| factor}
      gene_factors[gene] = top_factors
    }

    factor_genes = {}
    gene_factors.each do |gene,factors|
      factors.each do |factor|
        factor_genes[factor] ||= []
        factor_genes[factor] << gene
      end
    end
 
    save_file('factor_terms', TSV.setup(factor_terms, :key_field => "Factor", :fields => ["Term"], :type => :flat))
    save_file('factor_genes', TSV.setup(factor_genes, :key_field => "Factor", :fields => ["Ensembl Gene ID"], :type => :flat))
    save_file('gene_factors', TSV.setup(gene_factors, :key_field => "Ensembl Gene ID", :fields => ["Factor"], :type => :flat))

    {:terms => factor_terms, :genes => factor_genes, :gene_factors => gene_factors}
  end

end
