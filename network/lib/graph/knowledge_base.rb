
class Graph
  class KnowledgeBase
    attr_accessor :dir, :info
    def initialize(dir, &block)
      @dir = dir
      @info = {"All" => {}}

      self.instance_eval &block if block_given?  if File.exists? dir
    end

    #def fix_tsv(tsv, options)
    #  options = options.clone
    #  source_field = options[:source_type] || tsv.key_field
    #  target_field = options[:target_type] || tsv.fields.first

    #  source_type, source_field = source_field.split(":")
    #  source_field, source_type = source_type, nil if source_field.nil?
    #  source_type ||= Entity.formats[source_field].to_s

    #  target_type, target_field = target_field.split(":")
    #  target_field, target_type = target_type, nil if target_field.nil?
    #  target_type ||= Entity.formats[target_field].to_s

    #  translate_source = info[source_type][:format] if info[source_type] and info[source_type][:format] and info[source_type][:format] != source_field
    #  translate_target = info[target_type][:format] if info[target_type] and info[target_type][:format] and info[target_type][:format] != target_field

    #  tsv.with_unnamed do
    #    if translate_source
    #      index = Organism.identifiers(info["All"].merge(info[source_type])[:organism]).index :target => info[source_type][:format], :persist => true
    #      index.unnamed = true
    #      tsv.with_monitor :desc => "Translate source" do
    #        tsv = tsv.process_key do |key|
    #          index[key]
    #        end
    #      end
    #      tsv.key_field = info[source_type][:format]
    #    end

    #    if translate_target
    #      index = Organism.identifiers(info["All"].merge(info[target_type])[:organism]).index :target => info[target_type][:format], :persist => true
    #      index.unnamed = true
    #      tsv.with_monitor :desc => "Translate target" do
    #        case tsv.type
    #        when :list, :single
    #          tsv.process tsv.fields.first do |key|
    #            index[key]
    #          end
    #        when :double, :flat
    #          tsv.process tsv.fields.first do |values|
    #            index.values_at *values
    #          end
    #        end
    #      end
    #      tsv.fields = [info[target_type][:format]] + tsv.fields[1..-1]
    #    end
    #  end

    #  tsv
    #end

    #def associations(name, source, options = {})
    #  options = options.clone
    #  field, entity_type, persist_dir, undirected = options.values_at :target, :target_type, :persist_dir, :undirected

    #  tsv_fields = TSV === source ? 
    #    source.fields :
    #    TSV.parse_header(source).fields

    #  if field and not tsv_fields[0] == field
    #    tsv_fields.delete field
    #    tsv_fields = [field].concat tsv_fields 
    #  end

    #  field ||= tsv_fields.first

    #  options[:fields] = tsv_fields

    #  @associations[name] = Persist.persist_tsv(source, name, {}, :engine => TokyoCabinet::BDB, :serializer => :clean, :persist => true, :dir => @dir, :file => File.join(dir, name), :update => options[:update]) do |assocs|
    #    tsv = TSV === source ? 
    #      source :
    #      TSV.open(source, options.merge(:persist => false))

    #    tsv = fix_tsv(tsv, options)

    #    key_field = [tsv.key_field, tsv.fields.first.split(":").last, undirected ? "undirected" : nil].compact * "~"

    #    TSV.setup(assocs, :key_field => key_field, :fields => tsv.fields[1..-1], :type => :list, :serializer => :list)

    #    tsv.with_unnamed do
    #      tsv.with_monitor :desc => "Extracting annotations" do
    #        case tsv.type
    #        when :flat
    #          tsv.through do |source, targets|
    #            next if source.nil? or source.empty? or targets.nil? or targets.empty?

    #            targets.each do |target|
    #              next if target.nil? or target.empty?
    #              key = [source, target] * "~"
    #              assocs[key] = nil
    #            end
    #          end

    #        when :double
    #          tsv.through do |source, values|
    #            next if source.nil?
    #            next if values.empty?
    #            targets = values.first
    #            rest = Misc.zip_fields values[1..-1]

    #            annotations = rest.length > 1 ?
    #              targets.zip(rest) :
    #              targets.zip(rest * targets.length) 

    #            annotations.each do |target, info|
    #              next if target.nil?
    #              key = [source, target] * "~"
    #              assocs[key] = info
    #            end
    #          end
    #        else
    #          raise "Type not supported: #{tsv.type}"
    #        end
    #      end
    #    end
    #    assocs.close

    #    assocs
    #  end
    #end
    #

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
