require 'socket'
require 'fileutils'

require_relative 'string'
require_relative 'communication'

module Nil
  class IPCCommunication < SerialisedCommunication
    def initialize(socket)
      super(socket, TypeError)
    end

    def serialiseData(input)
      return Marshal.dump(input)
    end

    def deserialiseData(input)
      return Marshal.load(input)
    end
  end

  class IPCServer
    class InvalidCall < RuntimeError
    end

    def initialize(path)
      if File.exists?(path)
        FileUtils.rm(path)
      end
      @path = path
      @methods = [:getMethods]

      Thread.abort_on_exception = true
    end

    def socketHook
      File.chmod(0600, @path)
    end

    def run
      server = UNIXServer.new(@path)
      socketHook
      while true
        client = server.accept
        Thread.new do
          processClient(client)
        end
      end
    end

    def processClient(client)
      puts "New IPC client: #{client.inspect}"
      communication = IPCCommunication.new(client)
      while true
        begin
          result = communication.receiveData
          if result.connectionClosed
            puts "IPC client closed the connection: #{client.inspect}"
            return
          end
          processData(result.value, communication)
        rescue IPCCommunication::CommunicationError => exception
          puts "An IPC error occurred: #{exception.message}"
          return
        rescue InvalidCall => exception
          puts exception.message
          return
        rescue Errno::EPIPE
          puts 'Broken pipe'
          return
        end
      end
    end

    def processData(call, communication)
      if call.class != IPCCall
        communication.socket.close
        raise InvalidCall.new("Invalid IPC call object: #{call.class}")
      end
      if @methods.include?(call.symbol)
        output = nil
        begin
          function = method(call.symbol)
          output = function.call(*(call.arguments))
        rescue ArgumentError
          output = IPCError.new("Invalid argument count for method \"#{call.symbol}\"")
        end
      else
        output = IPCError.new("Unknown method \"#{call.symbol}\"")
      end
      communication.sendData(output)
    end

    def getMethods
      return @methods
    end
  end

  class IPCCall
    attr_reader :symbol, :arguments

    def initialize(symbol, arguments)
      @symbol = symbol
      @arguments = arguments
    end
  end

  class IPCError < RuntimeError
  end

  class IPCClient < IPCCommunication
    def initialize(path)
      begin
        super(UNIXSocket.new(path))
      rescue SystemCallError => exception
        #raise IPCError.new("Connection refused on socket #{path}")
        raise IPCError.new(exception.message)
      end
      receiveMethods
    end

    def performCall(method, arguments)
      call = IPCCall.new(method, arguments)
      sendData(call)
      result = receiveData
      raise IPCError.new('The server closed the connection') if result.connectionClosed
      output = result.value
      raise output if output.class == IPCError
      return output
    end

    def receiveMethods
      methods = performCall(:getMethods, [])
      methods.each do |method|
        extend(
               Module.new do
                 define_method(method) do |*arguments|
                   return performCall(method, arguments)
                 end
               end
               )
      end
    end
  end
end
