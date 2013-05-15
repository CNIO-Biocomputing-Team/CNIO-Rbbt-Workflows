
module Sinatra
  module RbbtToolHelper
    def tool(toolname, options = {})
      partial_render("tools/#{toolname}", options)
    end
  end
end
