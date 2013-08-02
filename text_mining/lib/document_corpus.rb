require 'rbbt/entity'
require 'rbbt/entity/document'
require 'rbbt/ner/segment/named_entity'
require 'rbbt/ner/segment/docid'

module Document
  property :sentences => :single do
    begin
      sentences = nil
      begin
        sentences = OpenNLP.sentence_splitter(text)
      rescue
        Log.warn("Error splitting sentences: #{$!.message}")
        sentences = []
      end
      SegmentWithDocid.setup(sentences, docid).collect{|s| s.mask }
    end
  end

  property :gene_mentions => :single do |*args|
    options = args.first || {}
    options = Misc.add_defaults options, :method => :dictionary, :normalize => true, :organism => "Hsa"

    method, normalize, organism, full_text = Misc.process_options options, :method, :normalize, :organism, :full_text

    job = TextMining.job(:gene_mention_recognition, docid, :method => method, :text => text, :normalize => normalize, :organism => organism)
    mentions = job.run

    SegmentWithDocid.setup(mentions, :docid => docid)
    mentions
  end

  property :sentences_over => :single do |segment|
    return [] unless Array === segment or segment.offset
    sentences = self.sentences
    if Array === segment
      segment.collect do |seg|
        if seg.offset.nil?
          []
        else
          sentences.select{|s| s.includes? seg }
        end
      end
    else
      sentences.select{|s| s.includes? segment }
    end
  end
end
