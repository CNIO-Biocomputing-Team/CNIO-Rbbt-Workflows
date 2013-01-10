require 'rbbt/workflow'

Workflow.require_workflow 'StudyExplorer'

puts "Loading function get_resource_file"
get '/resource/:resource/get_file' do
  file, resource, create = params.values_at :file, :resource, :create

  create = true unless create.nil? or create.empty? or %w(no false).include? create.downcase

  resource = "Rbbt" if resource.nil? or resource.empty?
  resource = Kernel.const_get(resource)

  path = resource.root[file]

  puts path

  raise "File does not exist" unless path.exists? or create
  raise "File does not exist and can not create it" unless path.exists? or path.produce.exists?

  send_file path.find, :filename => path
end
