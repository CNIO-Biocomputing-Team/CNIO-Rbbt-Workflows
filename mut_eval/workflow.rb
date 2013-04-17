require 'rbbt-util'
require 'rbbt/workflow'
require 'rbbt/persist/tsv'
require 'rbbt/mutation/mutation_assessor'
require 'rbbt/mutation/polyphen'
require 'rbbt/mutation/transFIC'
require 'rbbt/mutation/sift'
require 'rbbt/mutation/snps_and_go'
require 'rbbt/entity/protein'
require 'rbbt/util/R'

module MutEval
  extend Workflow

  CACHE_DIR = Rbbt.var.cache.MutEval.find

  CACHES = {
    :missing_predictions => Persist.open_tokyocabinet(File.join(CACHE_DIR, 'missing_predictions'), false, :string),
    :mutation_assessor => Persist.open_tokyocabinet(File.join(CACHE_DIR, 'mutation_assessor'), false, :string),
    :sift => Persist.open_tokyocabinet(File.join(CACHE_DIR, 'sift'), false, :string),
    :polyphen => Persist.open_tokyocabinet(File.join(CACHE_DIR, 'polyphen'), false, :string),
    :snps_and_go => Persist.open_tokyocabinet(File.join(CACHE_DIR, 'snps_and_go'), false, :string),
    :transFIC => Persist.open_tokyocabinet(File.join(CACHE_DIR, 'transFIC'), false, :string),
  }

  CACHES.values.each{|db| db.close}

  helper :get_cache do |method, mutations|
    tsv = TSV.setup({})

    cache = CACHES[method]
    missing = []

    cache.read_and_close do
      mutations.each do |mutation|
        if cache.include? mutation
          tsv[mutation] = cache[mutation].split("\t") 
        else
          missing << mutation
        end
      end
    end

    Log.debug("Cache for #{ method } found #{tsv.length} out of #{mutations.length}; missing #{missing.length}")
    [tsv, missing]
  end

  helper :add_cache do |method, tsv|
    cache = CACHES[method]
    cache.write_and_close do
      tsv.each do |mutation, values|
        cache[mutation] = values * "\t"
      end
    end
  end

  helper :get_missing do |method, mutations|
    tsv = TSV.setup({})

    cache = CACHES[:missing_predictions]
    missing = []

    cache.read_and_close do
      mutations.each do |mutation|
        if cache.include? mutation and cache[mutation].include? method.to_s
          missing << mutation
        end
      end
    end

    Log.debug("Mutations known to have missing predictions by #{ method }: #{missing.length} out of #{mutations.length}")

    missing
  end


  helper :add_missing do |method, mutations, tsv|
    cache = CACHES[:missing_predictions]
    cache.write_and_close do
      (mutations - tsv.keys).each do |mutation|
        if cache.include? mutation
          cache[mutation] << method.to_s
        else
          cache[mutation] = [method.to_s]
        end
      end
    end
  end

  input :mutations, :array, "Protein Mutations in any supported format, preferably 'UniProt/SwissProt ID'; example ATS2_HUMAN:G872R"
  input :organism, :string, "Organism code", "Hsa"
  task :transFIC => :tsv do |mutations, organism|
    cached, mutations = get_cache(:transFIC, mutations)

    missing = get_missing(:transFIC, mutations)
    mutations = mutations - missing

    proteins = mutations.collect{|mutation| mutation.split(":").first}
    index = Organism.protein_identifiers(organism).index(:target => "Ensembl Protein ID", :persist => true)
    proteins2native_id = Misc.process_to_hash(proteins){|list| index.chunked_values_at(list)}

    all_mutations = []
    mutations.each do |mutation|
      protein, change = mutation.split(":")
      native_id = proteins2native_id[protein]
      all_mutations << [native_id, change] * ":"
    end

    fields = %w( siftTransfic siftTransficLabel pph2Transfic pph2TransficLabel maTransfic maTransficLabel)
    tsv = TSV.setup({}, :key_field => "Protein Mutation", :fields => fields, :type => :list)

    if all_mutations.any?
      server_predictions = TransFIC.chunked_predict(all_mutations, 1000)

      mutations.each do |mutation|
        protein, change = mutation.split(":")
        native_id = proteins2native_id[protein]
        code = [native_id, change] * ":"
        values = server_predictions[code]
        next if values.nil?
        tsv[mutation] = values
      end unless server_predictions.nil?

      add_cache(:transFIC, tsv)
      cached.each do |mutation,values| tsv[mutation] = values end
    else
      cached.each do |mutation,values| tsv[mutation] = values end
    end

    add_missing(:transFIC, mutations, tsv)

    tsv
  end
  export_synchronous :transFIC


  input :mutations, :array, "Protein Mutations in any supported format, preferably 'UniProt/SwissProt ID'; example ATS2_HUMAN:G872R"
  input :organism, :string, "Organism code", "Hsa"
  task :mutation_assessor => :tsv do |mutations, organism|
    cached, mutations = get_cache(:mutation_assessor, mutations)

    missing = get_missing(:mutation_assessor, mutations)
    mutations = mutations - missing

    proteins = mutations.collect{|mutation| mutation.split(":").first}
    index = Organism.protein_identifiers(organism).index(:target => "UniProt/SwissProt ID", :persist => true)
    proteins2native_id = Misc.process_to_hash(proteins){|list| index.chunked_values_at(list)}

    all_mutations = {}
    mutations.each do |mutation|
      protein, change = mutation.split(":")
      native_id = proteins2native_id[protein]
      all_mutations[native_id] ||= []
      all_mutations[native_id] << change
    end

    server_predictions = MutationAssessor.chunked_predict(all_mutations, 1000)

    tsv = TSV.setup({}, :key_field => "Protein Mutation", :fields => ["Mutation Assessor Prediction", "Mutation Assessor Score"], :type => :list)
    mutations.each do |mutation|
      protein, change = mutation.split(":")
      native_id = proteins2native_id[protein]
      code = [native_id, change] * " "
      values = server_predictions[code]
      next if values.nil?
      tsv[mutation] = values.values_at "Func. Impact", "FI score"
    end

    add_cache(:mutation_assessor, tsv)
    cached.each do |mutation,values| tsv[mutation] = values end

    add_missing(:mutation_assessor, mutations, tsv)

    tsv
  end
  export_synchronous :mutation_assessor

  input :mutations, :array, "Protein Mutations in any supported format, preferably 'Ensembl Protein ID'; example ENSP00000251582:G872R"
  input :organism, :string, "Organism code", "Hsa"
  task :sift => :tsv do |mutations, organism|
    cached, mutations = get_cache(:sift, mutations)

    missing = get_missing(:sift, mutations)
    mutations = mutations - missing

    proteins = mutations.collect{|mutation| mutation.split(":").first}
    index = Organism.protein_identifiers(organism).index(:target => "Ensembl Protein ID", :persist => true)
    proteins2native_id = Misc.process_to_hash(proteins){|list| index.chunked_values_at(list)}

    all_mutations = []
    mutations.each do |mutation|
      protein, change = mutation.split(":")
      native_id = proteins2native_id[protein]
      all_mutations << [native_id, change] * ":"
    end

    log(:prediction, "Calling predictor")
    server_predictions = SIFT.chunked_predict(all_mutations)

    tsv = TSV.setup({}, :key_field => "Protein Mutation", :fields => ["SIFT Prediction", "SIFT Score"], :type => :list)
    mutations.each do |mutation|
      protein, change = mutation.split(":")
      native_id = proteins2native_id[protein]
      code = [native_id, change] * ":"
      values = server_predictions[code]
      next if values.nil?
      tsv[mutation] = values.values_at "Prediction", "Score 1"
    end

    log(:cache, "Adding to cache")
    add_cache(:sift, tsv)

    cached.each do |mutation,values| tsv[mutation] = values end

    add_missing(:sift, mutations, tsv)

    tsv
  end
  export_synchronous :sift

  input :mutations, :array, "Protein Mutations in any supported format, preferably 'UniProt/SwissProt Accession'; example O95450:G872R"
  input :organism, :string, "Organism code", "Hsa"
  task :polyphen => :tsv do |mutations, organism|
    cached, mutations = get_cache(:polyphen, mutations)

    missing = get_missing(:polyphen, mutations)
    mutations = mutations - missing

    proteins = mutations.collect{|mutation| mutation.split(":").first}
    index = Organism.protein_identifiers(organism).index(:target => "UniProt/SwissProt Accession", :persist => true)
    proteins2native_id = Misc.process_to_hash(proteins){|list| index.chunked_values_at(list)}

    all_mutations = []
    mutations.each do |mutation|
      protein, change = mutation.split(":")
      native_id = proteins2native_id[protein]
      next unless change.match(/([A-Z*])(\d+)([A-Z*])/)
      wt, pos, mt = change.match(/([A-Z*])(\d+)([A-Z*])/).values_at 1,2,3
      all_mutations << [native_id, pos, wt, mt] * " "
    end

    server_predictions = Polyphen2::Batch.chunked_predict(all_mutations * "\n") 

    tsv = TSV.setup({}, :key_field => "Protein Mutation", :fields => ["Polyphen Prediction", "Polyphen Score"], :type => :list)
    mutations.each do |mutation|
      protein, change = mutation.split(":")
      native_id = proteins2native_id[protein]
      code = [native_id, change] * ":"
      values = server_predictions[code]
      next if values.nil?
      tsv[mutation] = values.values_at "prediction", "pph2_prob"
    end

    add_cache(:polyphen, tsv)
    cached.each do |mutation,values| tsv[mutation] = values end

    add_missing(:polyphen, mutations, tsv)

    tsv
  end
  export_synchronous :polyphen


  input :mutations, :array, "Protein Mutations in any supported format, preferably 'UniProt/SwissProt Accession'; example O95450:G872R"
  input :organism, :string, "Organism code", "Hsa"
  task :snps_and_go => :tsv do |mutations, organism|
    cached, mutations = get_cache(:snps_and_go, mutations)

    missing = get_missing(:snps_and_go, mutations)
    mutations = mutations - missing

    proteins = mutations.collect{|mutation| mutation.split(":").first}
    index = Organism.protein_identifiers(organism).index(:target => "UniProt/SwissProt Accession", :persist => true)
    proteins2native_id = Misc.process_to_hash(proteins){|list| index.chunked_values_at(list)}

    all_mutations = []

    mutations.each do |mutation|
      acc, change = mutation.split(":")
      all_mutations << [acc, change] * ":"
    end
 
    server_predictions = Misc.process_to_hash(all_mutations){|list|
      list.collect{|mut|
        protein, change = mut.split(":")
        acc = proteins2native_id[protein]
        begin
          raise "No translation for #{ protein }" if acc.nil?
          SNPSandGO.predict(acc, change)
        rescue
          Log.debug("Error in SNPs&GO: #{$!.message}")
          nil
        end
      }
    }

    tsv = TSV.setup({}, :key_field => "Protein Mutation", :fields => ["SNPSandGO Prediction", "SNPSandGO Score"], :type => :list)
    mutations.each do |mutation|
      values = server_predictions[mutation]
      next if values.nil?
      tsv[mutation] = values
    end

    add_cache(:snps_and_go, tsv)
    cached.each do |mutation,values| tsv[mutation] = values end
 
    all_mutations = []

    add_missing(:snps_and_go, mutations, tsv)

    tsv
  end
  export_synchronous :snps_and_go


  #{{{ FEATURES
  
  task :training_features => :tsv do
    dataset = clean_name
    filename = File.join(File.dirname(__FILE__), 'data', dataset + '.txt')
    organism = "Hsa/may2012"

    dataset_tsv = TSV.open(filename, :type => :list, :key_field => 1)
    dataset_tsv.fields = ["Pathogenic"]
    dataset_tsv.key_field = "Protein Mutation"

    all_mutations = dataset_tsv.keys

    dataset_tsv = dataset_tsv.attach MutEval.job(:mutation_assessor, clean_name, :mutations => all_mutations, :organism => organism).run
    dataset_tsv = dataset_tsv.attach MutEval.job(:sift, clean_name, :mutations => all_mutations, :organism => organism).run
    dataset_tsv = dataset_tsv.attach MutEval.job(:snps_and_go, clean_name, :mutations => all_mutations, :organism => organism).run
    dataset_tsv = dataset_tsv.attach MutEval.job(:polyphen, clean_name, :mutations => all_mutations, :organism => organism).run


    dataset_tsv.to_s
  end

  input :mutations, :array, "Mutations to evaluate", nil 
  task :features => :tsv do |mutations|
    organism = "Hsa/may2012"

    mutations = Misc.process_to_hash(mutations){|list| list.collect{ [] }}
    dataset_tsv = TSV.setup(mutations, :type => :list)
    dataset_tsv.key_field = "Protein Mutation"
    dataset_tsv.fields = []

    all_mutations = dataset_tsv.keys

    dataset_tsv = dataset_tsv.attach MutEval.job(:mutation_assessor, clean_name, :mutations => all_mutations, :organism => organism).run
    dataset_tsv = dataset_tsv.attach MutEval.job(:sift, clean_name, :mutations => all_mutations, :organism => organism).run
    dataset_tsv = dataset_tsv.attach MutEval.job(:snps_and_go, clean_name, :mutations => all_mutations, :organism => organism).run
    dataset_tsv = dataset_tsv.attach MutEval.job(:polyphen, clean_name, :mutations => all_mutations, :organism => organism).run

    dataset_tsv.to_s
  end
  export_synchronous :features

  dep do |jobname, inputs| MutEval.job(:training_features, jobname) end
  task :rpart_model => :binary do
    feature_file = step(:training_features).path

    R.run <<-EOF

library('rpart');
features = rbbt.tsv('#{feature_file}');
names(features) = make.names(names(features))

#model = rpart(Pathogenic ~ Mutation.Assessor.Score + Polyphen.Score + SIFT.Score, data = features)
#model = rpart(Pathogenic ~ Mutation.Assessor.Score + Polyphen.Score + SIFT.Score + SNPSandGO.Score, data = features, method='class')
#model = rpart(Pathogenic ~ Mutation.Assessor.Score + SIFT.Score + SNPSandGO.Score, data = features, method='class')
model = rpart(Pathogenic ~ Mutation.Assessor.Score + Polyphen.Score + SIFT.Score + SNPSandGO.Score, data = features, method='class',control=rpart.control(cp=.0001))


save(file='#{path}', model)
    EOF
    nil
  end


  dep do |jobname, inputs| MutEval.job(:training_features, jobname) end
  task :svm_model => :binary do
    feature_file = step(:training_features).path

    R.run <<-EOF

library('e1071');
features = rbbt.tsv('#{feature_file}');
names(features) = make.names(names(features))

model = svm(Pathogenic ~ Mutation.Assessor.Score + Polyphen.Score + SIFT.Score, data = features, na.action=na.pass)

save(file='#{path}', model)
    EOF
    nil
  end

  dep :features
  input :dataset, :string
  dep do |jobname, inputs| MutEval.job(:rpart_model, inputs[:dataset]) end
  task :predict => :tsv do |mutation|
    model_file = step(:rpart_model).path
    feature_file = step(:features).path

    R.run <<-EOF

library('e1071');
library('randomForest');
library('rpart');

load(file='#{model_file}');
features = rbbt.tsv('#{feature_file}');
names(features) = make.names(names(features));

features[, "Mutation.Assessor.Score"] = as.numeric(features[,"Mutation.Assessor.Score"])
features[, "Polyphen.Score"]          = as.numeric(features[,"Polyphen.Score"])
features[, "SIFT.Score"]              = as.numeric(features[,"SIFT.Score"])
features[, "SNPSandGO.Score"]         = as.numeric(features[,"SNPSandGO.Score"])

d = as.data.frame(predict(model, features));
names(d) <- c("Neutral", "Pathogenic");

rbbt.tsv.write(file='#{self.path}', d, key.field = "Protein Mutation");
    EOF

    nil
  end
  export_synchronous :predict


end

MutEval.job(:svm_model, 'test', :dataset => 'humdiv').clean.run if __FILE__ == $0


