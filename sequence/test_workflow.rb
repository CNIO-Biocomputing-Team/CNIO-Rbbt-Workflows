require 'rbbt/workflow'

Workflow.require_workflow 'sequence'

puts Sequence.transcript_offsets_for_genomic_positions("Hsa/nov2010", Sequence["test/data/CLL-1.tsv"].read.split("\n"))
exit
puts Sequence.mutated_isoforms_for_genomic_mutations("Hsa/feb2011", Sequence["test/data/CLL-1.tsv"].read.split("\n"))

