module DCell
  # Servers handle incoming 0MQ traffic
  class Server
    include Celluloid::ZMQ

    finalizer :close

    # Bind to the given 0MQ address (in URL form ala tcp://host:port)
    def initialize
      # The gossip protocol is dependent on the node manager
      link Celluloid::Actor[:node_manager]

      @addr   = DCell.addr
      @socket = PullSocket.new

      begin
        @socket.bind(@addr)
      rescue IOError
        @socket.close
        raise
      end

      async.run
    end

    # Wait for incoming 0MQ messages
    def run
      while true; async.handle_message @socket.read; end
    end

    def close
      @socket.close if @socket
    end

    # Handle incoming messages
    def handle_message(message)
      begin
        message = decode_message message
      rescue InvalidMessageError => ex
        Logger.crash("couldn't decode message", ex)
        return
      end

      begin
        message.dispatch
      rescue => ex
        Logger.crash("DCell::Server: message dispatch failed", ex)
      end
    end

    class InvalidMessageError < StandardError; end # undecodable message

    # Decode incoming messages
    def decode_message(message)
      if message[0..1].unpack("CC") == [Marshal::MAJOR_VERSION, Marshal::MINOR_VERSION]
        begin
          Marshal.load message
        rescue => ex
          raise InvalidMessageError, "invalid message: #{ex}"
        end
      else raise InvalidMessageError, "couldn't determine message format: #{message}"
      end
    end

    # Terminate this server
    def terminate
      @socket.close
      super
    end
  end
end
