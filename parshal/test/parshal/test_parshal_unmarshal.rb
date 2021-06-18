# frozen_string_literal: true

require 'minitest/autorun'
require 'parshal'

class TestParshalUnmarshal < Minitest::Test
  def assert_unmarshal(obj)
    if obj.nil?
      assert_nil Parshal.unmarshal(Marshal.dump(obj))
    else
      assert_equal obj, Parshal.unmarshal(Marshal.dump(obj))
    end
  end

  def test_nil
    assert_unmarshal nil
  end

  def test_bool
    assert_unmarshal true
    assert_unmarshal false
  end

  def test_int
    assert_unmarshal(-2**30)
    assert_unmarshal(-2**30 + 1)
    assert_unmarshal(-2**24 - 1)
    assert_unmarshal(-2**24)
    assert_unmarshal(-2**24 + 1)
    assert_unmarshal(-2**16 - 1)
    assert_unmarshal(-2**16)
    assert_unmarshal(-2**16 + 1)
    assert_unmarshal(-2**8 - 1)
    assert_unmarshal(-2**8)
    assert_unmarshal(-2**8 + 1)
    assert_unmarshal(-250)
    assert_unmarshal(-220)
    assert_unmarshal(-200)
    assert_unmarshal(-180)
    assert_unmarshal(-159)
    assert_unmarshal(-124)
    assert_unmarshal(-123)
    assert_unmarshal(-122)
    assert_unmarshal(-2)
    assert_unmarshal(-1)
    assert_unmarshal(0)
    assert_unmarshal(1)
    assert_unmarshal(2)
    assert_unmarshal(121)
    assert_unmarshal(122)
    assert_unmarshal(123)
    assert_unmarshal(124)
    assert_unmarshal(2**8 - 1)
    assert_unmarshal(2**8)
    assert_unmarshal(2**8 + 1)
    assert_unmarshal(2**16 - 1)
    assert_unmarshal(2**16)
    assert_unmarshal(2**16 + 1)
    assert_unmarshal(2**24 - 1)
    assert_unmarshal(2**24)
    assert_unmarshal(2**24 + 1)
    assert_unmarshal(2**30 - 1)
  end

  def test_integer_all
    skip 'This takes forever... understandably'
    (-2**30...2**30).each { |i| assert_unmarshal i }
  end

  def test_symbol
    assert_unmarshal :a
    assert_unmarshal :ab
    assert_unmarshal :abc
    assert_unmarshal :abcd
    assert_unmarshal :abcde
  end

  def test_string
    assert_unmarshal 'It works!'
  end
end
