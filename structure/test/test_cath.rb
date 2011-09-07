require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require 'cath'

class TestRbbt < Test::Unit::TestCase
  def test_sequence
    ddd Cath.align('1htoU01', "AAAATPDDVFKLAKDEKVEYVDVRFCDLPGIMQHFTIPASAFDKSVFDDGLAFDGSSIRGFQSIHESDMLLLPDPETARIDPFRAAKTLNINFFVHDPFTLEPYSRDAAAAAA")
  end
end
