require 'rbbt/workflow'

Workflow.require_workflow "Translation"
Workflow.require_workflow "Sequence"

WorkflowREST.add_workflows Sequence, Translation
WorkflowREST.setup

