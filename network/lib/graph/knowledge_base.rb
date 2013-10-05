require 'rbbt/association'
require 'rbbt/entity'
class Graph
  class KnowledgeBase
    attr_accessor :dir, :info, :entity_types
    def initialize(dir, &block)
      @dir = dir
      @info = {"All" => {}}

      self.instance_eval &block if block_given?  if File.exists? dir
    end

    def all_databases
      Dir.glob(dir + '/*').collect{|f| File.basename f }.reject{|f| f =~ /\.reverse$/ }
    end

    def database_info
      info = {}
      all_databases.each do |name|
        repo = get_repo name
        target, source, undirected = database_types name
        fields = repo.fields
        info[name] = {:target => target, :source => source, :undirected => undirected, :info => fields}
      end
    end

    def association_sources
      all_databases
    end

    def repo_file(name)
      raise "No repo specified" if name.nil? or name.empty?
      File.join(dir, name.to_s)
    end

    def get_repo(name)
      file = repo_file name
      File.exists?(file) ?
        Persist.open_tokyocabinet(file, false, nil, TokyoCabinet::BDB) :
        nil
    end

    def database_types(name)
      repo = get_repo(name)
      return nil if repo.nil?
      source, target = repo.key_field.split "~"
      source_type = Entity.formats[source]
      target_type = Entity.formats[target]
      [source_type, target_type]
    end

    def init_entity_registry
      @sources = {}
      @targets = {}
      all_databases.each do |repo|
        source_type, target_type = database_types repo
        @sources[source_type] ||= []
        @sources[source_type] << repo
        @targets[target_type] ||= []
        @targets[target_type] << repo
      end
    end

    def sources
      init_entity_registry unless @sources
      @sources
    end

    def targets
      init_entity_registry unless @targets
      @targets
    end

    def entity_types
      (sources.keys + targets.keys).uniq
    end

    def register(database, file, options)
      persistence = repo_file database
      Association.index(file, options, :persist => true, :file => persistence)
    end

    def connections(database, entities)
      repo = get_repo(database)
      return [] if repo.nil?
      Association.connections(repo, entities)
    end

    def neighbours(name, entities)
      repo = get_repo(name)
      return nil if repo.nil?

      source_type, target_type = database_types name

      if (list = entities[source_type.to_s]) and list.any?
        {:type => target_type, :entities => Association.neighbours(repo, list)}
      else
        {:type => source_type, :entities => Association.neighbours(repo, entities[target_type.to_s])}
      end
    end
  end
end
