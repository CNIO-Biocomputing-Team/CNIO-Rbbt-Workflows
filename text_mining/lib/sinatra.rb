require 'rbbt/entity'
require 'rbbt/entity/document'
require 'rbbt/ner/segment/named_entity'
require 'rbbt/ner/segment/docid'

module Document
  class << self
    attr_accessor :property_cache
    property_cache = Rbbt.var.document_properties.find(:lib)
  end

  property :sentences => :single do
    sentences = nil
    begin
      sentences = OpenNLP.sentence_splitter(text)
    rescue
      Log.warn("Error splitting sentences: #{$!.message}")
      sentences = []
    end
    SegmentWithDocid.setup(sentences, docid).collect{|s| s.mask }
  end

  property :gene_mentions => :single do |*args|
    options = args.first || {}
    options = Misc.add_defaults options, :method => :dictionary, :normalize => true, :organism => "Hsa"

    method, normalize, organism = Misc.process_options options, :method, :normalize, :organism

    job = TextMining.job(:gene_mention_recognition, docid, :method => method, :text => text, :normalize => normalize, :organism => organism)
    mentions = job.run

    SegmentWithDocid.setup(mentions, :docid => docid)
    mentions
  end

  property :sentences_over => :single do |segment|
    return [] if segment.offset.nil?
    sentences.select{|s| s.includes? segment }
  end
end
  

module Document
  persist :sentences, :annotations, :annotation_dir => Document.property_cache
end

corpus = Rbbt.var.document.corpus.find(:lib)
c = Persist.open_tokyocabinet(corpus, false, :annotations, TokyoCabinet::BDB)
c.close
Document.corpus = c
