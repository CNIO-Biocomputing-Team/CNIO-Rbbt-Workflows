class Cytoscape      
  NODE_SCHEMA = [                        
    {:name => :entity_type, :type => :string},      
    {:name => :label, :type => :string},          
    {:name => :url, :type => :string},     
    {:name => :opacity, :type => :number},   
    {:name => :borderWidth, :type => :number},    
    {:name => :size, :type => :number},                     
    {:name => :selected, :type => :boolean, :defValue => false},   
    {:name => :color, :type => :string},                 
    {:name => :shape, :type => :string},                      
    {:name => :info, :type => :object},                                     
  ]      

  EDGE_SCHEMA = [                       
    {:name => :database, :type => :string},                                
    {:name => :info, :type => :object},                   
    {:name => :opacity, :type => :number},           
    {:name => :color, :type => :string},                 
    {:name => :width, :type => :number},                         
    {:name => :weight, :type => :number},                     
  ]                        

  attr_accessor :knowledge_base, :namespace, :entities                
  def initialize(knowledge_base, namespace = nil)                
    if namespace and namespace != knowledge_base.namespace                        
      @knowledge_base = knowledge_base.version(namespace)                    
    else                                        
      @knowledge_base = knowledge_base                                
    end                                                       
    @entities = IndiferentHash.setup({})                                         
    @namespace = namespace                                  
  end                                 

  def add_entities(entities, type = nil)                                                   
    type = entities.base_entity.to_s if type.nil? and AnnotatedArray === entities
    raise "No type specified and entities are not Entity, so could not guess" if type.nil? 
    good_entities = knowledge_base.translate(entities, type).compact.uniq  
    @namespace ||= entities.organism if entities.respond_to? :organism       
    @entities[type] ||= []              
    @entities[type].concat good_entities                  
  end                        

  #{{{ Network                         

  def self.nodes(knowledge_base, entities)             
    nodes = []                             
    entities.collect{|type, list|                 
      knowledge_base.annotate list, type                     
      list.each do |elem|                                   
        text = elem.respond_to?(:name) ? elem.name || elem : elem              
        nodes << {:id => elem, :label => text, :entity_type => type, :info => knowledge_base.entity_options_for(type), :url =>  Entity::REST.entity_url(elem)}
      end                                

    }                        
    nodes                           
  end                      

  def self.edges(matches)
    matches.collect{|match|
      {:database => match.database, :info => match.info, :source => match.source, :target => match.target}
    }
  end

  def self.network(knowledge_base, entities, subset)
    edges = []
    subset.each do |database, matches| edges.concat self.edges(matches) end
    {:dataSchema => {:nodes => NODE_SCHEMA, :edges => EDGE_SCHEMA}, :data => {:nodes => nodes(knowledge_base, entities), :edges => edges }}
  end
                    

  def network
    subset = {}
    knowledge_base.all_databases.each do |database|
      subset[database] = knowledge_base.subset(database, entities)
    end
    Cytoscape.network(knowledge_base, entities, subset)
  end



end


