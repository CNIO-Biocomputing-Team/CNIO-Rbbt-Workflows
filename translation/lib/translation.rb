module Translation

  def self.index(organism, target, source = nil)
    key = [organism, target, source]
    @@index ||= {}
    if @@index[key].nil?
      if source.nil?
        @@index[key] = Organism.identifiers(organism).index(:data_grep => "^LRG_", :data_invert_grep => true, :target => target, :persist => true, :order => true, :unnamed => true, :data_persist => true)
      else
        @@index[key] = Organism.identifiers(organism).index(:data_grep => "^LRG_", :data_invert_grep => true, :target => target, :fields => [source], :persist => true, :order => true, :unnamed => true, :data_persist => true)
      end
    end
    @@index[key]
  end

  def self.protein_index(organism, target, source = nil)
    key = [organism, target, source]
    @@protein_index ||= {}
    if @@protein_index[key].nil?
      if source.nil?
        @@protein_index[key] = Organism.protein_identifiers(organism).index(:data_grep => "^LRG_", :data_invert_grep => true, :target => target, :persist => true, :order => true, :unnamed => true, :data_persist => true)
      else                                                                                                          
        @@protein_index[key] = Organism.protein_identifiers(organism).index(:data_grep => "^LRG_", :data_invert_grep => true, :target => target, :fields => [source], :persist => true, :order => true, :unnamed => true, :data_persist => true)
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
        @@probe_index[key] = Organism.probe_transcripts(organism).index(:data_grep => "^LRG_", :data_invert_grep => true, :target => target, :persist => true, :order => true, :unnamed => true, :data_persist => true)
      else                                                                                                      
        @@probe_index[key] = Organism.probe_transcripts(organism).index(:data_grep => "^LRG_", :data_invert_grep => true, :target => target, :fields => [source], :persist => true, :order => true, :unnamed => true, :data_persist => true)
      end
      @@probe_index[key].unnamed = true
    end
    @@probe_index[key]
  end

  def self.transcript_to_protein_index(organism)
    key = [organism]
    @@transcript_to_protein_index ||= {}
    if @@transcript_to_protein_index[key].nil?
      @@transcript_to_protein_index[key] = Organism.transcripts(organism).index(:data_grep => "^LRG_", :data_invert_grep => true, :target => "Ensembl Protein ID", :fields => ["Ensembl Transcript ID"], :persist => false, :unnamed => true, :data_persist => true)
      @@transcript_to_protein_index[key].unnamed = true                                                                 
    end                                                                         
    @@transcript_to_protein_index[key]
  end

end
