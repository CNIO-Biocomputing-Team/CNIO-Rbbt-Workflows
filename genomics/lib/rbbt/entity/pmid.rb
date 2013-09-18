require 'rbbt/entity'
require 'rbbt/entity/document'
require 'rbbt/sources/pubmed'
require 'rbbt/sources/gscholar'

module PMID
  extend Entity
  include Document

  self.annotation :default_type

  self.format = "PMID"

  property :docid => :single do |*args|
    type = args.first || default_type
    ["PMID", self, type].compact * ":"
  end

  property :article => :array2single do
    PubMed.get_article(self).chunked_values_at(self)
  end

  property :abstract => :array2single do
    article.collect{|a| a.nil? ? nil : a.abstract}
  end

  property :title => :array2single do
    article.collect{|a| a.nil? ? nil : a.title}
  end

  property :journal => :array2single do
    article.collect{|a| a.nil? ? nil : a.journal}
  end

  property :year => :array2single do
    article.collect{|a| a.nil? ? nil : a.year}
  end

  property :cites => :single2array do
    if title
      begin
        GoogleScholar.number_cites(title)
      rescue
        nil
      end
    else
      nil
    end
  end

  property :_get_text => :array2single do |*args|
    type = args.first || default_type
    
    text = case type.to_s
           when "full_text", 'fulltext'
             article.collect{|a| a.nil? ? nil : a.full_text}
           when "abstract"
             article.collect{|a| a.nil? ? nil : a.abstract }
           when "best"
             article.collect{|a| a.nil? ? nil : (a.full_text || a.text) }
           else
             article.collect{|a| a.nil? ? nil : a.text}
           end

    text
  end

  property :pubmed_url => :single2array do
    "<a class='pmid' href='http://www.ncbi.nlm.nih.gov/pubmed/#{self}'>#{ self }</a>"
  end

  property :bibtex => :array2single do
    PubMed.get_article(self).chunked_values_at(self).collect do |article|
      article.bibtex
    end
  end

  property :bibtex do
    keys = [:author] + PubMed::Article::XML_KEYS.collect{|p| p.first } - [:bibentry]
    bibtex = "@article{#{bibentry},\n"

    keys.each do |key|
      next if self.send(key).nil?

      case key

      when :title
        bibtex += "  title = { #{ PubMed::Article.escape_title title } },\n"

      when :issue
        bibtex += "  number = { #{ issue } },\n"

      else
        bibtex += "  #{ key } = { #{ self.send(key) } },\n"
      end

    end

    bibtex += "  fulltext = { #{ pdf_url } },\n" if pdf_url
    bibtex += "  pmid = { #{ pmid } }\n}"


    bibtex
  end

  property :bibentry do
    bibentry = nil
    author = article.author.split(' and ').first.strip
    lastname, forename = author.split(',')
    bibentry ||= [lastname, (year || "NOYEAR"), (title || "NOTITLE").scan(/\w+/)[0]] * ""
    bibentry.downcase
  end

end
