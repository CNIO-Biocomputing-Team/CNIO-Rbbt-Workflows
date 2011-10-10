require 'rbbt/workflow'

Workflow.require_workflow "Translation"
Workflow.require_workflow "Sequence"
Workflow.require_workflow "Structure"
Workflow.require_workflow "Genotype"

WorkflowREST.add_workflows Sequence, Translation, Structure, Genotype
WorkflowREST.setup

