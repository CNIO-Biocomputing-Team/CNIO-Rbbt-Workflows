
class Graph
  class KnowledgeBase
    attr_accessor :dir, :info
    def initialize(dir, &block)
      @dir = dir
      @info = {"All" => {}}

      self.instance_eval &block if block_given?  if File.exists? dir
    end

    def association_sources
      all_repos
    end

    def all_repos
      Dir.glob(dir + '/*').collect{|f| File.basename f }
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

    def connections(name, entities)
      repo = get_repo(name)
      return [] if repo.nil?
      source_field, target_field, undirected = repo.key_field.split("~")

      source_type = Entity.formats[source_field].to_s
      target_type = Entity.formats[target_field].to_s

      source_entities = entities[source_type] || entities[source_field]
      target_entities = entities[target_type] || entities[target_field]

      return [] if source_entities.nil? or target_entities.nil?

      source_entities.collect do |entity|
        keys = repo.prefix(entity + "~")
        keys.collect do |key|
          source, target = key.split("~")
          next unless target_entities.include? target
          next if undirected and target > source
          info = Hash[*repo.fields.zip(repo[key]).flatten]

          {:source => source, :target => target, :info => info, :database => name}
        end.compact
      end.flatten
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
  end
end
