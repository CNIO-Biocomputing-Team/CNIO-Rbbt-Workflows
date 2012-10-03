require 'rbbt/util/misc'

module Signature

  def self.setup(hash, options = {})
    hash.extend Signature

    hash
  end

  def self.open(file, field = nil, options = {})
    options = Misc.add_defaults options, :fields => nil, :cast => :to_f, :type => :single

    options[:fields] ||= [field] if field

    tsv = TSV.open(file, options)
    tsv.extend Signature
    tsv
  end

  def values_over(threshold)
    entity_options = self.entity_options
    entity_options[:organism] ||= self.namespace
    Misc.prepare_entity(self.select{|k,v| v >= threshold}.collect{|k,v| k}, self.key_field, entity_options)
  end

  def values_under(threshold)
    entity_options = self.entity_options
    entity_options[:organism] ||= self.namespace
    Misc.prepare_entity(self.select{|k,v| v <= threshold}.collect{|k,v| k}, self.key_field, entity_options)
  end

  def significant_pvalues(threshold)
    entity_options = self.entity_options
    entity_options[:organism] ||= self.namespace
    if threshold > 0
      Misc.prepare_entity(self.select{|k,v| v > 0 and v <= threshold}.collect{|k,v| k}, self.key_field, entity_options)
    else
      Misc.prepare_entity(self.select{|k,v| v < 0 and v >= threshold}.collect{|k,v| k}, self.key_field, entity_options)
    end
  end

  def transform(&block)
    case
    when (block_given? and block.arity == 2)
      self.each do |key, value|
        self[key] = yield key, value
      end
    when (block_given? and block.arity == 1)
      self.each do |key, value|
        self[key] = yield value
      end
    else
      raise "Block not given, or arity not 1 or 2"
    end
    self
  end

  def abs
    transform{|value| value.abs}
  end

  def log
    transform{|value| Math.log(value)}
  end

  def pvalue_score
    transform{|value| value > 0 ? -Math.log(value + 0.00000001) : Math.log(-value + 0.00000001)}
  end

end
