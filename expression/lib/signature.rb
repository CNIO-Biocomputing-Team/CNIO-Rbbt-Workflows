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

  def abs
    self.keys.each do |key|
      self[key] = self[key].abs
    end
    self
  end

  def log
    self.keys.each do |key|
      self[key] = Math.log(self[key])
    end
    self
  end


end
