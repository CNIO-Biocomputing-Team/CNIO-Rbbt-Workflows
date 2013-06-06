require 'rbbt/util/misc'
require 'rbbt/sources/pina'
require 'rbbt/sources/string'

module Graph

  def self.nodes(type, entities, options)
    Misc.prepare_entity(entities, type, options)
    entities.collect{|e|
      {
        :id =>  e,
        :entity_type =>  type,
        :label => e.name
      }
    }
  end

  def self.edges(database, entities)
    edges = []
    tsv = case database.to_sym
          when :pina
            Pina.protein_protein.tsv :persist => true, :fields => ["Interactor UniProt/SwissProt Accession"], :type => :flat
          when :string
            STRING.protein_protein.tsv :persist => true, :fields => ["Interactor Ensembl Protein ID"], :type => :flat
          else
            raise "Database not known: #{ database }"
          end

    assocs = TSV.setup(entities, :key_field => entities.format, :fields => [], :type => :flat)
    assocs.identifiers = Organism.identifiers(entities.organism).find

    assocs.attach tsv, :fields => tsv.fields.first
    assocs.fields = [tsv.key_field]

    assocs.through do |entity, associations|
      associations = associations.gene if Protein === associations
      associations.ensembl.each do |association|
        next if association.nil?
        edges << {
          :id => [entity, association] * ":",
          :source => entity,
          :target => association
        }
      end
    end

    edges
  end


  def self.node_schema
    [
      {:name => :entity_type, :type => :string}, 
      {:name => :label, :type => :string},
      {:name => :opacity, :type => :number}, 
      {:name => :borderWidth, :type => :number}, 
      {:name => :selected, :type => :boolean, :defValue => false}, 
    ]
  end

  def self.edge_schema
    []
  end
end
