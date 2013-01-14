require 'rbbt/workflow'

module FileServer
  extend Workflow

  input :file, :string, "File name to download"
  input :resource, :string, "Resource that manages it", "Rbbt"
  input :produce, :boolean, "Produce if missing", false
  task :get_file => :binary do |file, resource, produce|
    raise "Please select a valid resource" if resource.nil? or resource.empty? or resource == "Rbbt"
    resource = Kernel.const_get(resource)

    path = resource.root[file]

    puts path

    raise "File does not exist" unless path.exists? or produce
    raise "File does not exist and can not create it" unless path.exists? or path.produce.exists?

    path.read
  end
  export_exec :get_file
 
  input :directory, :string, "Directory name to download"
  input :resource, :string, "Resource that manages it", "Rbbt"
  task :get_directory => :binary do |directory, resource|
    raise "Please select a valid resource" if resource.nil? or resource.empty? or resource == "Rbbt"
    resource = Kernel.const_get(resource)

    path = resource.root[directory]

    puts path

    raise "Directory does not exist" unless path.exists?

    CMD.cmd(" cd #{path.find}; tar cvfz - *", :pipe => true).read 
  end
  
  export_synchronous :get_directory
end
