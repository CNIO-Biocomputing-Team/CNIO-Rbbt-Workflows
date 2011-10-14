require 'rbbt/workflow'

Workflow.require_workflow "Translation"
Workflow.require_workflow "Sequence"
Workflow.require_workflow "Structure"

WorkflowREST.add_workflows Sequence, Translation, Structure
WorkflowREST.setup

