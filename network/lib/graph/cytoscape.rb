class Graph
  module Cytoscape
    def self.node_schema
      [
        {:name => :entity_type, :type => :string}, 
        {:name => :label, :type => :string},
        {:name => :url, :type => :string},

        {:name => :opacity, :type => :number}, 
        {:name => :borderWidth, :type => :number}, 
        {:name => :size, :type => :number}, 
        {:name => :selected, :type => :boolean, :defValue => false}, 
        {:name => :color, :type => :string}, 
        {:name => :shape, :type => :string}, 
      ]
    end

    def self.edge_schema
      [
        {:name => :database, :type => :string},
        {:name => :info, :type => :string}, 

        {:name => :opacity, :type => :number}, 
        {:name => :color, :type => :string},
        {:name => :width, :type => :number},
        {:name => :weight, :type => :number},
      ]
    end

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

    def self.edges(associations)
      associations.collect{|info|
        {:database => info[:database], :target => info[:target], :source => info[:source], :info => info[:info].to_json}
      }
    end
  end
end
