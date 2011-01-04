module Fraggel

  class Responder

    def initialize(&blk)
      @receiver = blk
    end

    def receive_event(name, value)
      @cs ||= lambda {|x|
        @receiver.call(x)
        @cs = nil
      }

      case name
      when :array
        @cs = array!(value, [], &@cs)
      when :value
        @cs.call(value)
      when :error
        @cs.call(StandardError.new(value))
      when :status
        # I'm not sure if this is a good idea.  Symbols are not garbage
        # collected.  If there server sends and arbitrary number of status
        # messages, this could get ugly.  I'm not sure that's a problem yet.
        @cs.call(value.to_sym)
      else
        fail "Unknown Type #{name.inspect}"
      end
    end

    def array!(c, a, &blk)
      lambda {|x|
        a << x
        if c == a.length
          @cs = blk
          blk.call(a)
        else
          array!(c, a, &blk)
        end
      }
    end

  end

end
