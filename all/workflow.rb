require 'rbbt/workflow'

Workflow.require_workflow "Translation"
Workflow.require_workflow "Sequence"
Workflow.require_workflow "Structure"
Workflow.require_workflow "Enrichment"
Workflow.require_workflow "GeneList"

WorkflowREST.add_workflows Sequence, Translation, Structure, Enrichment, GeneList
WorkflowREST.setup

