# frozen_string_literal: true

require 'minitest/autorun'
require 'parshal'

class TestParshalMarshal < Minitest::Test
  def assert_marshal(obj)
    assert_equal Marshal.dump(obj), Parshal.marshal(obj)
  end

  def test_nil
    assert_marshal nil
  end

  def test_bool
    assert_marshal true
    assert_marshal false
  end

  def test_integer
    assert_marshal(-2**30)
    assert_marshal(-2**30 + 1)
    assert_marshal(-2**24 - 1)
    assert_marshal(-2**24)
    assert_marshal(-2**24 + 1)
    assert_marshal(-2**16 - 1)
    assert_marshal(-2**16)
    assert_marshal(-2**16 + 1)
    assert_marshal(-2**8 - 1)
    assert_marshal(-2**8)
    assert_marshal(-2**8 + 1)
    assert_marshal(-124)
    assert_marshal(-123)
    assert_marshal(-122)
    assert_marshal(-2)
    assert_marshal(-1)
    assert_marshal(0)
    assert_marshal(1)
    assert_marshal(2)
    assert_marshal(121)
    assert_marshal(122)
    assert_marshal(123)
    assert_marshal(124)
    assert_marshal(2**8 - 1)
    assert_marshal(2**8)
    assert_marshal(2**8 + 1)
    assert_marshal(2**16 - 1)
    assert_marshal(2**16)
    assert_marshal(2**16 + 1)
    assert_marshal(2**24 - 1)
    assert_marshal(2**24)
    assert_marshal(2**24 + 1)
    assert_marshal(2**30 - 1)
  end

  def test_integer_all
    skip 'This takes forever... understandably'
    (-2**30...2**30).each { |i| assert_marshal i }
  end

  def test_symbol
    assert_marshal :a
    assert_marshal :ab
    assert_marshal :abc
    assert_marshal :abcd
    assert_marshal :abcde
  end

  def test_string
    assert_marshal 'It works!'
  end
end
