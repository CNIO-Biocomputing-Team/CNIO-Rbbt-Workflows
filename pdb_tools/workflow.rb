require 'rbbt-util'
require 'rbbt/workflow'

module PdbTools
  extend Workflow

  Rbbt.claim Rbbt.software.opt["pdb-tools"], :install, Rbbt.share.install.software["pdb-tools"].find

  input :pdb, :text, "PDB file"
  input :distance, :float, "Distance"
  task :pdb_close_contacts => :text do |pdb, distance|
    TmpFile.with_file(pdb, nil, :extension => 'pdb') do |pdbfile|
      CMD.cmd("python '#{Rbbt.software.opt["pdb-tools"].produce["pdb_close-contacts.py"].find}' --distance=#{distance} '#{pdbfile}'").read
      Open.read(pdbfile + '.close_contacts')
    end
  end
  export_asynchronous :pdb_close_contacts

  dep :pdb_close_contacts
  task :pdb_close_positions => :tsv do |pdb, distance|
    result = TSV.setup({}, :key_field => "Amino Acid", :fields => ["Neighbour"], :type => :flat)
    step(:pdb_close_contacts).load.split("\n").each do |line|
      next if line =~ /#|atom1/
      atom1, atom2 = line.match(/"(.*)" "(.*)"/).values_at(1,2)

      aa1 = atom1.split(" ").values_at(2,3) * ":"
      aa2 = atom2.split(" ").values_at(2,3) * ":"

      result[aa1] ||= []
      result[aa2] ||= []
      result[aa1] << aa2
      result[aa2] << aa1
    end
    result.process "Neighbour" do |values|
      values.uniq
    end
    result
  end
  export_asynchronous :pdb_close_positions
end

