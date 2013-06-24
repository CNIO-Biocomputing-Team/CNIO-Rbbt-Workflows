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
        :url =>  Entity::REST.entity_url(e),
        :label => e.respond_to?(:name) ? (e.name || e) : e
      }
    }
  end

  def self.edges(database, entities)
    edges = []
    tsv, field = case database.to_sym
          when :pina
            tsv = Pina.protein_protein.tsv :persist => true, :fields => ["Interactor UniProt/SwissProt Accession"], :type => :flat
            [tsv, "UniProt/SwissProt Accession"]
          when :string
            tsv = STRING.protein_protein.tsv :persist => true, :fields => ["Interactor Ensembl Protein ID"], :type => :flat
            [tsv, "Ensembl Protein ID"]
          when :go_bp
            if entities.respond_to? :organism
              tsv = Organism.gene_go_bp(entities.organism).tsv :persist => true, :fields => ["GO ID"], :type => :flat
              [tsv, "GO ID"]
            else
              return []
            end
          when :nature
            tsv = NCI.nature_pathways.tsv :persist => true, :key_field => "UniProt/SwissProt Accession", :fields => ["NCI Nature Pathway ID"], :type => :flat, :merge => true
            [tsv, "NCI Nature Pathway ID"]
          else
            raise "Database not known: #{ database }"
          end

    format = entities.respond_to?(:format) ? entities.format : entities.annotation_types.last.to_s
    assocs = TSV.setup(entities, :key_field => format, :fields => [], :type => :flat)
    assocs.identifiers = Organism.identifiers(entities.organism).find if entities.respond_to?(:organism) and entities.organism

    begin
      puts tsv
      assocs.attach tsv, :fields => tsv.fields.first
      assocs.fields = [field]

      assocs.through do |entity, associations|
        associations = associations.gene if Protein === associations
        associations = associations.ensembl if associations.respond_to? :ensembl
        associations.each do |association|
          next if association.nil?
          edges << {
            :id => [entity, association] * ":",
            :source => entity,
            :target => association
          }
        end
      end
    rescue
      Log.debug("Database #{ database } could not be attached to #{ format }: #{$!.message}")
    end

    edges
  end

  def self.node_schema
    [
      {:name => :entity_type, :type => :string}, 
      {:name => :label, :type => :string},
      {:name => :url, :type => :string},
      {:name => :opacity, :type => :number}, 
      {:name => :borderWidth, :type => :number}, 
      {:name => :selected, :type => :boolean, :defValue => false}, 
    ]
  end

  def self.edge_schema
    [
      {:name => :opacity, :type => :number}, 
    ]
  end
end
