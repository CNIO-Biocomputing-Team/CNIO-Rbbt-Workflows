
class Graph
  class KnowledgeBase
    attr_accessor :dir, :info, :associations
    def initialize(dir)
      @dir = dir
      @info = {"All" => {}}
      @associations = {}
    end

    def fix_tsv(tsv, options)
      source_field = options[:source_type] || tsv.key_field
      target_field = options[:target_type] || tsv.fields.first

      source_type, source_field = source_field.split(":")
      source_field, source_type = source_type, nil if source_field.nil?
      source_type ||= Entity.formats[source_field].to_s

      target_type, target_field = target_field.split(":")
      target_field, target_type = target_type, nil if target_field.nil?
      target_type ||= Entity.formats[target_field].to_s

      translate_source = info[source_type][:format] if info[source_type] and info[source_type][:format] and info[source_type][:format] != source_field
      translate_target = info[target_type][:format] if info[target_type] and info[target_type][:format] and info[target_type][:format] != target_field

      tsv.with_unnamed do
        if translate_source
          index = Organism.identifiers(info[source_type][:organism]).index :target => info[source_type][:format], :persist => true
          index.unnamed = true
          tsv.with_monitor :desc => "Translate source" do
            tsv = tsv.process_key do |key|
              index[key]
            end
          end
          tsv.key_field = info[source_type][:format]
        end

        if translate_target
          index = Organism.identifiers(info[target_type][:organism]).index :target => info[target_type][:format], :persist => true
          index.unnamed = true
          tsv.with_monitor :desc => "Translate target" do
            case tsv.type
            when :list, :single
              tsv.process tsv.fields.first do |key|
                index[key]
              end
            when :double, :flat
              tsv.process tsv.fields.first do |values|
                index.values_at *values
              end
            end
          end
          tsv.fields = [info[target_type][:format]] + tsv.fields[1..-1]
        end
      end

      tsv
    end

    def association_sources
      @associations.keys
    end

    def associations(name, source, options)
      field, entity_type, persist_dir = options.values_at :target, :target_type, :source_type, :persist_dir

      tsv_fields = TSV === source ? 
        source.fields :
        TSV.parse_header(source).fields

      tsv_fields.delete field
      tsv_fields = [field].concat tsv_fields 

      options[:fields] = tsv_fields

      filename = source.respond_to?(:filename) ? source.filename : source
      @associations[name] = Persist.persist_tsv(source, "Associations [#{filename}]", options, :engine => TokyoCabinet::BDB, :serializer => :clean, :persist => true, :dir => @dir) do |assocs|
        tsv = TSV === source ? 
          source :
          TSV.open(source, options.merge(:persist => false))

        tsv = fix_tsv(tsv, options)

        key_field = [tsv.key_field, tsv.fields.first] * "~"

        TSV.setup(assocs, :key_field => key_field, :fields => tsv.fields[1..-1], :type => :list, :serializer => :list)

        tsv.with_unnamed do
          tsv.with_monitor :desc => "Extracting annotations" do
            case tsv.type
            when :flat
              tsv.through do |source, targets|
                next if source.nil? or targets.nil? or targets.empty?

                targets.each do |target|
                  next if target.nil?
                  key = [source, target] * "~"
                  assocs[key] = nil
                end
              end

            when :double
              tsv.through do |source, values|
                next if source.nil?
                targets = values.first
                rest = Misc.zip_fields values[1..-1]

                annotations = rest.length > 1 ?
                  targets.zip(rest) :
                  targets.zip(rest * targets.length) 

                annotations.each do |target, info|
                  next if target.nil?
                  key = [source, target] * "~"
                  assocs[key] = info
                end
              end
            else
              raise "Type not supported: #{tsv.type}"
            end
          end
        end

        assocs.close
        assocs
      end

    end

    def connections(name, entities)
      repo = @associations[name]
      source_field, target_field = repo.key_field.split("~")
      source_type = Entity.formats[source_field].to_s
      target_type = Entity.formats[target_field].to_s

      source_entities = entities[source_type]
      target_entities = entities[target_type]

      return [] if source_entities.nil? or target_entities.nil?

      source_entities.collect do |entity|
        keys = repo.prefix(entity + "~")
        keys.collect do |key|
          source, target = key.split("~")
          next unless target_entities.include? target
          info = Hash[*repo.fields.zip(repo[key]).flatten]

          {:source => source, :target => target, :info => info}
        end.compact
      end.flatten
    end
  end
end
