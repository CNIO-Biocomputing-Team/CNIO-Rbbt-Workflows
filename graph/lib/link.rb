module Link
  attr_accessor :pairs, :source, :target

  def self.incidence(pairs)
    matrix = {}
    targets = []
    sources = []
    matches = {}

    pairs.each do |p|
      s, sep, t = p.partition "~"
      sources << s
      targets << t
      matches[s] ||= Hash.new{false}
      matches[s][t] = true
    end

    sources.uniq!
    targets = targets.uniq.sort

    matches.each do |s,hash|
      matrix[s] = hash.values_at(*targets)
    end

    defined?(TSV)? TSV.setup(matrix, :fields => targets, :type => :list) : matrix
  end
end
