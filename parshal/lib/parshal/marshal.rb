# frozen_string_literal: true

module Parshal
  # A high-level marshal method that takes an object and tries to marshal the
  # object into a byte array.
  #
  # == Parameters:
  # [obj]   The object to serialize
  #
  # == Returns:
  # A byte array of the marshalled object.
  def self.marshal(obj, prepend_version: true)
    ret = case obj
          when NilClass, TrueClass, FalseClass, Symbol
            marshal_raw(obj)
          when Integer
            ['i'.ord] +
            marshal_raw(obj)
          when String
            ['I'.ord] +
            marshal_raw(obj) +
            marshal_raw(1) +
            marshal_raw(:E) +
            marshal_raw(true)
          else
            raise ArgumentError, "marshal doesn't support objects of class #{obj.class}"
          end
    ret = [4, 8] + ret if prepend_version
    ret.pack('c*')
  end

  # A low-level marshal dump that dumps "raw" types. Intended primarily for
  # #marshal to use but may be useful in other contexts. Main differences are
  # that Integer doesn't include its prefix (as it's used raw in many contexts)
  # and String doesn't turn into an IVAR, it's just the "raw String"
  # representation that's inside the normal IVAR.
  #
  # == Parameters:
  # [obj]   The object to be serialized.
  #
  # == Returns:
  # The raw form of the serialized object.
  def self.marshal_raw(obj)
    case obj
    when NilClass
      ['0'.ord]
    when TrueClass
      ['T'.ord]
    when FalseClass
      ['F'.ord]
    when Integer
      marshal_raw_integer obj
    when Symbol
      [':'.ord] + marshal_raw(obj.size) + obj.to_s.unpack('c*')
    when String
      ['"'.ord] + marshal_raw(obj.size) + obj.unpack('c*')
    else
      raise ArgumentError, "marshal_raw doesn't support objects object of class #{obj.class}"
    end
  end

  def self.marshal_raw_integer(obj)
    raise ArgumentError, 'marshal_raw_integer only accepts Integers' unless obj.is_a? Integer

    case obj
    when (-2**30...-2**24)
      [-4] + [obj].pack('V').unpack('c4')
    when (-2**24...-2**16)
      [-3] + [obj].pack('V').unpack('c3')
    when (-2**16...-2**8)
      [-2] + [obj].pack('V').unpack('c2')
    when (-2**8...-123)
      [-1] + [obj].pack('V').unpack('c1')
    when (-123..-1)
      [obj - 5]
    when 0
      [0]
    when (1...123)
      [obj + 5]
    when (123...2**8)
      [1] + [obj].pack('V').unpack('c1')
    when (2**8...2**16)
      [2] + [obj].pack('V').unpack('c2')
    when (2**16...2**24)
      [3] + [obj].pack('V').unpack('c3')
    when (2**24...2**30)
      [4] + [obj].pack('V').unpack('c4')
    else
      raise ArgumentError, 'marshal_raw_integer can only marshal integers between -2**30...2**30'
    end
  end
end
