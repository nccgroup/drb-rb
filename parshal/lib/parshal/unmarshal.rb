module Parshal
  def self.remove_version_prefix(obj)
    major, minor = obj[0..1].unpack('cc')

    unless major == 4 && minor == 8
      warn "WARNING: Reply specifies unsupported version of marshal format: #{major}.#{minor}"
    end

    obj[2..]
  end

  def self.unmarshal(raw_obj, remove_version: true, return_rem: false)
    raise ArgumentError, "raw_obj must be a String type, got #{raw_obj.inspect}" unless raw_obj.is_a? String

    obj = if remove_version
            remove_version_prefix raw_obj
          else
            raw_obj
          end

    raise ArgumentError, 'Empty object passed to unmarshal' if obj.empty?

    case obj[0]
    when '0'
      if return_rem
        [nil, obj[1..]]
      else
        nil
      end
    when 'T'
      if return_rem
        [true, obj[1..]]
      else
        true
      end
    when 'F'
      if return_rem
        [false, obj[1..]]
      else
        false
      end
    when 'i'
      # Integer
      i, _, rem = unmarshal_raw_integer(obj[1..])

      raise "Remaining data following Integer: #{rem.inspect}" if !return_rem && !rem.empty?

      if return_rem
        [i, rem]
      else
        i
      end
    when ':'
      # Symbol
      sym, _, rem = unmarshal_raw_string_symbol(obj)

      warn "Remaining data following Symbol: #{rem.inspect}" if !return_rem && !rem.empty?

      if return_rem
        [sym, rem]
      else
        sym
      end
    when 'I'
      # String wrapped in IVAR
      # we only parse for strings and verify the rest of the basic IVAR parts at
      # the end
      # {I, {", marshal(len), raw str}, marshal(1), marshal(:E), marshal(true)}
      if obj.length < (Marshal.dump('').length - 2) # -2 to strip the version number
        raise "unexpected IVAR: #{raw_obj.inspect}, smaller than minimum length"
      end

      str, _, rem = unmarshal_raw_string_symbol(obj[1..])

      raise 'Unexpected end of IVAR' if rem.empty?

      ivar_count, _, rem = unmarshal_raw_integer(rem)


      raise "IVAR with more than one instance variable unsupported: #{ivar_count.inspect}" if ivar_count > 1

      raise 'Unexpected end of IVAR' if rem.empty?

      if ivar_count == 0
        if return_rem
          return [str, rem]
        else
          return str
        end
      end

      e, _, rem = unmarshal_raw_string_symbol(rem)

      # :E=true for UTF-8 and :E=false for ASCII, :encoding=whatever for everything else
      # we are not going to support custom encodings
      raise "IVAR with unexpected instance variable: #{e.inspect}" unless e == :E

      raise 'Unexpected end of IVAR' if rem.empty?
      b, _, rem = unmarshal_raw_bool(rem)

      if not b
        str.force_encoding('ascii')
      end

      raise "Unexpected data at the end of IVAR: #{rem.inspect}" if !return_rem && !rem.empty?

      if return_rem
        [str, rem]
      else
        str
      end
    when '['
      len, _, rem = unmarshal_raw_integer(obj[1..])
      arr = []
      for _ in 0...len
        obj, rem = unmarshal(rem, remove_version: false, return_rem: true)
        arr.push(obj)
      end

      raise "Unexpected data after the end of Array: #{rem.inspect}" if !return_rem && !rem.empty?

      if return_rem
        [arr, rem]
      else
        arr
      end
    when 'u'
      # we pull out the symbol and attempt to decode the payload as a basic value
      sym, _, rem = unmarshal_raw_string_symbol(obj[1..])

      len, _, rem = unmarshal_raw_integer(rem)

      raise "User-defined payload length mismatch, got #{len}, actual: #{rem.length}" if len != rem.length

      payload = rem

      payload_decoded = begin
        unmarshal(payload)
      rescue => e
        puts e.inspect
        nil
      end

      if return_rem
        [[sym, [payload_decoded, payload]], rem]
      else
        [sym, [payload_decoded, payload]]
      end
    else
      unmarshal_type_error obj
    end
  end

  def self.unmarshal_type_error(obj)
    case obj[0]
    when ';'
      raise 'Symbol links/references not supported'
    when '@'
      raise 'Object links/references not supported'
    when 'e'
      raise "'extended' not supported"
    when 'l'
      raise 'Bignum not supported'
    when 'c'
      raise 'Class not supported'
    when 'm'
      raise 'Module not supported'
    when 'M'
      raise 'Class/Module not supported'
    when 'd'
      raise 'Data objects not supported'
    when 'f'
      raise 'Float not supported'
    when '{', '}'
      raise 'Hash not supported'
    when 'o'
      raise "Object not supported: #{obj.inspect}"
    when '/'
      raise 'regular expressions not supported'
    when 'S'
      raise 'Struct not supported'
    when 'C'
      raise 'user-defined sublass not supported'
    when 'U'
      raise "User Marshal serialization not supported: #{obj.inspect}"
    end
  end

  def self.unmarshal_raw(obj)
    raise ArgumentError, 'unmarshal_raw passed Nil' if obj.nil?

    raise ArgumentError, 'unmarshal_raw passed empty String' if obj.empty?

    case obj[0]
    when '0'
      [nil, 1, obj[1..]]
    when 'T', 'F'
      unmarshal_raw_bool obj
    when '"', ':'
      unmarshal_raw_string_symbol obj
    else
      raise 'unmarshal_raw passed unknown argument'
    end
  end

  def self.unmarshal_raw_bool(obj)
    raise ArgumentError, 'unmarshal_raw_bool passed nil or empty string' if obj.nil? || obj.empty?

    case obj[0]
    when 'T'
      [true, 1, obj[1..]]
    when 'F'
      [false, 1, obj[1..]]
    else
      raise "unmarshal_raw_bool not passed a bool to unmarshal: #{obj.inspect}"
    end
  end

  def self.unmarshal_raw_string_symbol(obj)
    raise 'unmarshal_raw_string_symbol passed nil or empty String' if obj.nil? || obj.empty?

    raise 'unmarshal_raw_string_symbol not passed marshaled String or Symbol' unless obj[0] == '"' || obj[0] == ':'

    sz, sz_sz, rem = unmarshal_raw_integer(obj[1..])

    raise 'String or Symbol has negative size' if sz.negative?

    str = rem[...sz]

    raise 'Not enough data supplied to satisfy String or Symbol size' unless sz == str.size

    consumed = 1 + sz_sz + sz

    if obj[0] == '"'
      [str, consumed, obj[consumed..]]
    else
      [str.to_sym, consumed, obj[consumed..]]
    end
  end

  def self.unmarshal_raw_integer(obj)
    raise ArgumentError, 'unmarshal_raw_integer passed invalid input' if obj.nil? || obj.empty?

    case obj[0].unpack1('c')
    when 0
      # "0 -> Integer: 0"
      [0, 1, obj[1..]]
    when 1
      # "1 -> Integer: (123...2**8)"
      [obj[1].unpack1('C'), 2, obj[2..]]
    when 2
      # "2 -> Integer: (2**8...2**16)"
      [obj[1..2].unpack1('S<'), 3, obj[3..]]
    when 3
      # "3 -> Integer: (2**16...2**24)"
      ["#{obj[1..3]}\x00".unpack1('L<'), 4, obj[4..]]
    when 4
      # "4 -> Integer: (2**24...2**30)"
      [obj[1..4].unpack1('L<'), 5, obj[5..]]
    when -1
      # "-1 -> Integer: (-2**8...-123)"
      [obj[1].unpack1('C') + (-2**8), 2, obj[2..]]
    when -2
      # "-2 -> Integer: (-2**16...-2**8)"
      [obj[1..2].unpack1('S<') + (-2**16), 3, obj[3..]]
    when -3
      # "-3 -> Integer: (-2**24...-2**16)"
      ["#{obj[1..3]}\x00".unpack1('L<') + (-2**24), 4, obj[4..]]
    when -4
      # "-4 -> Integer: (-2**30...-2**24)"
      [obj[1..4].unpack1('L<') + (-2**32), 5, obj[5..]]
    when 6..127
      # "1...123 -> Integer: i+5"
      [obj[0].unpack1('c') - 5, 1, obj[1..]]
    when -128..-6
      # "-123...-1 -> Integer: i-5"
      [obj[0].unpack1('c') + 5, 1, obj[1..]]
    else # 5 and -5 are undefined
      # "unknown: " + obj[0].ord
      raise ArgumentError, '5 and -5 are undefined when marshaling integers'
    end
  end
end
