require 'rbbt/entity/gene'


module Gene

  property :enrichment_in => :array do |*args|
    database,cutoff,fdr = args
    cutoff ||= 0.05
    fdr = true if fdr.nil?
    Enrichment.enrichment(database, self, organism, cutoff, fdr)
  end
end
