# frozen_string_literal: true

require 'timeout'
require 'parshal'
require_relative './drb-rb/stable'

module DRbRb
  # block must accept 4 arguments: [obj_id, obj_id_raw], [method, method_raw], [args, args_raw], and [block, block_raw]
  # block must return 2-3 arguments: success, result, close?
  def self.start_server(sock, &block)
    loop do
      req = begin
        drb_read_request(sock)
      rescue => e
        if 'recvfrom yielded no data' == e.message
          break
        end
        puts "Exception raised in DRbRb handler1: #{e.inspect}\n#{e.backtrace.join("\n")}"
        break
      end
      rep = begin
        block.call(*req)
      rescue => e
        puts "Exception raised in DRbRb handler: #{e.inspect}\n#{e.backtrace.join("\n")}"
        next
      end

      begin
        if not drb_write_reply(sock, *rep)
          break
        end
      rescue => e
        puts "Exception raised in DRbRb handler3: #{e.inspect}\n#{e.backtrace.join("\n")}"
        break
      end
    end
  end

  def self.send_request(sock, obj_id, method, args, block, include_raw: false)
    drb_write_request(sock, obj_id, method, args, block)
    drb_read_reply(sock, include_raw: include_raw)
  end

  def self.drb_read_request(sock)
    id = drb_read_msg_piece(sock, include_raw: true)
    method = drb_read_msg_piece(sock, include_raw: true)
    args_len = drb_read_msg_piece(sock, include_raw: true)
    args = []
    if args_len[0] != nil && args_len[0].instance_of?(Integer) && args_len[0] > 0
      for _ in 0...args_len[0]
        args.push(drb_read_msg_piece(sock, include_raw: true))
      end
    end
    block = drb_read_msg_piece(sock, include_raw: true)
    [id, method, args, block]
  end

  def self.drb_read_reply(sock, include_raw: false)
    [drb_read_msg_piece(sock), # success
     drb_read_msg_piece(sock, include_raw: include_raw)] # result
  end

  def self.drb_write_request(sock, obj_id, method, args, block)
    sock.send(make_request(obj_id, method, args, block), 0)
  end

  def self.drb_write_reply(sock, success, result, close=false)
    sock.send(make_reply(success, result), 0)
    if close
      sock.close
    end
    !close
  end

  def self.drb_read_msg_piece(sock, include_raw: false)
    len = drb_read_msg_piece_length sock

    piece = nil
    begin
      Timeout::timeout(4) {
        piece = sock.recvfrom(len)[0]
        piece << sock.recvfrom(len - piece.size)[0] while piece.size < len
      }
    rescue Timeout::Error
      raise "recvfrom timed out"
    end

    obj = Parshal.unmarshal(piece)

    if include_raw
      [obj, piece]
    else
      obj
    end
  end

  def self.drb_read_msg_piece_length(sock)
    len = 0
    begin
      Timeout::timeout(2) {
        len = sock.recvfrom(4)[0]
      }
    rescue Timeout::Error
      raise "recvfrom timed out"
    end

    if len.empty?
      raise 'recvfrom yielded no data'
    end

    while len.size < 4
      chunk = nil
      begin
        Timeout::timeout(2) {
          chunk = sock.recvfrom(4 - len.size)
        }
      rescue Timeout::Error
        raise "recvfrom timed out"
      end

      if chunk[0].empty?
        raise 'recvfrom yielded no data after partial read'
      end
      len << chunk[0]
    end

    len.unpack1('N')
  end

  def self.make_request(obj_id, method, args, block)
    request = make_msg_piece(obj_id)
    request << make_msg_piece(method)
    request << make_msg_piece(args.size)
    args.each { |arg| request << make_msg_piece(arg) }
    request << make_msg_piece(block)
    request
  end

  def self.make_reply(success, result, raw=[false,false])
    reply = make_msg_piece(success, raw: raw[0])
    reply << make_msg_piece(result, raw: raw[1])
    reply
  end

  def self.make_msg_piece(obj, prepend_size: true, raw: false)
    #piece = Parshal.marshal(obj)
    piece = if raw
      obj
    else
      Marshal.dump(obj)
    end

    piece = [piece.size].pack('N') + piece if prepend_size
    piece
  end
end
