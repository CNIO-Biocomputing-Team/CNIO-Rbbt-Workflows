$LOAD_PATH.unshift('./lib')
require 'rbbt-util'
require 'graph/cytoscape'
require 'graph/knowledge_base'

class Graph

  attr_accessor :knowledge_base, :entities, :databases, :aesthetics
  def initialize(knowledge_base, databases = nil)
    @knowledge_base = knowledge_base
    @entities = {}
    @databases = databases || []
    @aesthetics = {:nodes => {}, :edges => {}}
  end

  def association_sources
    Array === @knowledge_base ? 
      @knowledge_base.collect{|k| k.association_sources}.flatten.uniq :
      @knowledge_base.association_sources
  end

  def add(entities)
    entity_type = entities.annotation_types.select{|t| Entity === t}.last
    @entities[entity_type] ||= []
    @entities[entity_type].concat entities
  end

  def entity_options(type = nil)
    return {} if @knowledge_base.nil?
    if type.nil?
      Array === @knowledge_base ? 
        @knowledge_base.collect{|kb| kb.info.values}.flatten.inject({}){|acc,e| acc.merge(e)} :
        @knowledge_base.info.values.inject({}){|acc,e| acc.merge(e)}
    else
      Array === @knowledge_base ? 
        @knowledge_base.collect{|kb| kb.info.values_at("All", type).compact}.flatten.inject({}){|acc,e| acc.merge(e)} :
        @knowledge_base.info.values_at("All", type).compact.inject({}){|acc,e| acc.merge(e)}
    end
  end

  def edges
    return [] if knowledge_base.nil?
    if Array === knowledge_base
      databases.collect do |database|
        knowledge_base.collect do |kb|
          Graph::Cytoscape.edges(kb.connections(database, entities))
        end
      end.flatten
    else
      databases.collect do |database|
        Graph::Cytoscape.edges(knowledge_base.connections(database, entities))
      end.flatten
    end
  end

  def nodes
    entities.collect do |type, list|
      info = entity_options(type)
      Graph::Cytoscape.nodes(type, list, info)
    end.flatten
  end

  def network
    {:data => {:nodes => nodes, :edges => edges}, :dataSchema => {:nodes => Graph::Cytoscape.node_schema, :edges => Graph::Cytoscape.edge_schema}}
  end

  def add_aesthetic(elem, aesthetic, feature, map = nil)
    @aesthetics[elem][aesthetic] = {:feature => feature, :map => map}
  end
end
