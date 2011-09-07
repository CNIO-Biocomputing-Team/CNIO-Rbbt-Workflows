module Translation

  def self.index(organism, target, source = nil)
    key = [organism, target, source]
    @@index ||= {}
    if @@index[key].nil?
      if source.nil?
        @@index[key] = Organism.identifiers(organism).index(:target => target, :persist => true, :order => true)
      else
        @@index[key] = Organism.identifiers(organism).index(:target => target, :fields => [source], :persist => true, :order => true)
      end
      @@index[key].unnamed = true
    end
    @@index[key]
  end

  def self.protein_index(organism, target, source = nil)
    key = [organism, target, source]
    @@protein_index ||= {}
    if @@protein_index[key].nil?
      if source.nil?
        @@protein_index[key] = Organism.protein_identifiers(organism).index(:target => target, :persist => true, :order => true)
      else
        @@protein_index[key] = Organism.protein_identifiers(organism).index(:target => target, :fields => [source], :persist => true, :order => true)
      end
      @@protein_index[key].unnamed = true
    end
    @@protein_index[key]
  end

end
