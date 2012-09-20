require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require 'rbbt'
require 'test/unit'
require 'circos'
require 'yaml'

class TestCircos < Test::Unit::TestCase
  def test_parse_chunk
    text = Rbbt.share.circos.partials["header.conf"].read
    conf = Circos.parse_conf(text)

    puts Circos.print_conf(conf)

  end

  def test_header
    ddd Circos.header
  end
end
