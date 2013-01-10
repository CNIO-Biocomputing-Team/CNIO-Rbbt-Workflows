require 'rbbt/workflow'

module FileServer
  extend Workflow

  input :file, :string, "File name to download"
  input :resource, :string, "Resource that manages it", "Rbbt"
  input :produce, :boolean, "Produce if missing", false
  task :get_file => :binary do |file, resource, produce|
    resource = "Rbbt" if resource.nil? or resource.empty?
    resource = Kernel.const_get(resource)

    path = resource.root[file]

    puts path

    raise "File does not exist" unless path.exists? or produce
    raise "File does not exist and can not create it" unless path.exists? or path.produce.exists?

    path.read
  end
  
  export_exec :get_file
end
