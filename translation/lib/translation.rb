module Translation

  def self.index(organism, target, source = nil)
    key = [organism, target, source]
    @@index ||= {}
    if @@index[key].nil?
      if source.nil?
        @@index[key] = Organism.identifiers(organism).index(:target => target, :persist => true, :order => true, :unnamed => true)
      else
        @@index[key] = Organism.identifiers(organism).index(:target => target, :fields => [source], :persist => true, :order => true, :unnamed => true)
      end
    end
    @@index[key]
  end

  def self.protein_index(organism, target, source = nil)
    key = [organism, target, source]
    @@protein_index ||= {}
    if @@protein_index[key].nil?
      if source.nil?
        @@protein_index[key] = Organism.protein_identifiers(organism).index(:target => target, :persist => true, :order => true, :unnamed => true)
      else
        @@protein_index[key] = Organism.protein_identifiers(organism).index(:target => target, :fields => [source], :persist => true, :order => true, :unnamed => true)
      end
      @@protein_index[key].unnamed = true
    end
    @@protein_index[key]
  end

  def self.probe_index(organism, target, source = nil)
    key = [organism, target, source]
    @@probe_index ||= {}
    if @@probe_index[key].nil?
      if source.nil?
        @@probe_index[key] = Organism.probe_transcripts(organism).index(:target => target, :persist => true, :order => true, :unnamed => true)
      else
        @@probe_index[key] = Organism.probe_transcripts(organism).index(:target => target, :fields => [source], :persist => true, :order => true, :unnamed => true)
      end
      @@probe_index[key].unnamed = true
    end
    @@probe_index[key]
  end

  def self.transcript_to_protein_index(organism)
    key = [organism]
    @@transcript_to_protein_index ||= {}
    if @@transcript_to_protein_index[key].nil?
      @@transcript_to_protein_index[key] = Organism.transcripts(organism).index(:target => "Ensembl Protein ID", :fields => ["Ensembl Transcript ID"], :persist => false, :unnamed => true)
      @@transcript_to_protein_index[key].unnamed = true
    end
    @@transcript_to_protein_index[key]
  end

end
