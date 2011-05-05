require 'fraggle/response'

module Fraggle

  module Connection

    Disconnected = Response.new
    Disconnected.disconnected = true

    # Base class for all Connection errors
    class Error < StandardError
      attr_accessor :req

      def initialize(req, msg=nil)
        @req = req
        super(msg)
      end
    end

    # Raised when a request is invalid
    class SendError < Error
    end


    attr_reader :addr

    def initialize(addr)
      @addr, @cb = addr, {}
    end

    def receive_data(data)
      (@buf ||= "") << data

      while @buf.length > 0
        if @len && @buf.length >= @len
          bytes = @buf.slice!(0, @len)
          @len = nil
          res = Response.decode(bytes)
          receive_response(res)
        elsif @buf.length >= 4
          bytes = @buf.slice!(0, 4)
          @len = bytes.unpack("N")[0]
        else
          break
        end
      end
    end

    # The default receive_response
    def receive_response(res)
      return if err?
      req, blk = @cb.delete(res.tag)
      return if ! blk
      blk.call(res)
    end

    def send_request(req, blk)
      if req.tag
        raise SendError, "Already sent #{req.inspect}"
      end

      if err?
        next_tick { blk.call(Disconnected) }
        return req
      end

      req.tag = 0
      while @cb.has_key?(req.tag)
        req.tag += 1

        req.tag %= 2**31
      end

      # TODO: remove this!
      @cb[req.tag] = [req, blk]

      data = req.encode
      head = [data.length].pack("N")

      send_data("#{head}#{data}")

      req
    end

    def unbind
      @err = true
      @cb.values.each do |_, blk|
        blk.call(Disconnected)
      end
    end

    def err?
      !!@err
    end

    def timer(n, &blk)
      EM.add_timer(n, &blk)
    end

    def next_tick(&blk)
      EM.next_tick(&blk)
    end

  end

end
