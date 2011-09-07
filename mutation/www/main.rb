require 'rbbt/util/log'
require 'rbbt/workflow'
require 'rbbt/workflow/rest'
require 'sinatra'
require 'compass'

Workflow.require_workflow 'pharmacology'
WorkflowREST.add_workflows Pharmacology
WorkflowREST.setup
