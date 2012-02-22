#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2011 Seth Chisamore
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module EventMachine
  module WinRM
    class Session

      attr_reader :exit_codes
      ##### Proxy Methods
      def on_output(&blk); @on_output = blk; end
      def on_error(&blk); @on_error = blk; end
      def on_command_complete(&blk); @on_command_complete = blk; end
      def on_finish(&blk); @on_finish = blk; end
      def on_close(&blk); @on_close = blk; end

      def initialize(options={})
        if options[:logger]
          WinRM::Log.logger = options[:logger]
        else
          log_level = options[:log_level] || :info
          WinRM::Log.level(log_level)
        end
        @servers = {}
        @commands = []
        @exit_codes = {}
        WinRM::Log.debug(":session => :init")
      end

      #
      # run command on all servers
      #
      def relay_command(data)
        EM.epoll
        EM.run do
          WinRM::Log.debug(":relay_to_servers => #{data}")
          servers ||= @servers.values.compact
          servers.each do |s|
            operation = proc do
              WinRM::Log.debug(":relayed => #{s.host}")
              @commands << s.run_command(data)
            end
            EM.defer(operation)
          end
        end
      end

      #
      # initialize connections to a server
      #
      def use(host, options)
        @servers[host] = Server.new(self, host, options)
      end

      #
      # return an array of the current servers in the session
      #
      def servers
        @servers.values
      end

      #
      # set the current servers in the session
      #
      def servers=(servers)
        @servers = {}
        servers.each{|s| @servers[s.host] = s}
      end

      #
      # returns a new EventMachine::WinRM::Session instance
      # consisting of a specific sub-set of servers
      #
      # inspired by Net::SSH::Multi::Session.on
      #
      def on(*new_servers)
        subsession = self.clone
        subsession.servers = new_servers & servers
        yield subsession if block_given?
        subsession
      end

      #
      # relay output from backend server to client
      #
      def relay_output_from_backend(host, data)
        WinRM::Log.debug(":relay_output_from_backend => #{[host, data]}")
        data = @on_output.call(host, data) if @on_output
      end

      #
      # relay error output from backend server to client
      #
      def relay_error_from_backend(host, data)
        WinRM::Log.debug(":relay_error_from_backend => #{[host, data]}")
        data = @on_error.call(host, data) if @on_error
      end

      #
      # called by backend server when it completes a command
      #
      def command_complete(host, cid,exit_code)
        WinRM::Log.debug(":command_complete => #{host} with return code #{exit_code}")
        @commands.delete(cid)
        @on_command_complete.call(host) if @on_command_complete
        @exit_codes[host] = exit_code
        if @commands.compact.size.zero?
          @on_command_complete.call(:all) if @on_command_complete
          EM.stop
        end
      end

      def unbind
        WinRM::Log.debug(":unbind => :connection")
        # terminate any unfinished connections
        @servers.values.compact.each do |s|
          s.unbind
        end
      end

      def unbind_backend(host)
        WinRM::Log.debug(":unbind_backend => #{host}")
        @servers[host] = nil
        @on_finish.call(host) if @on_finish
        if @servers.values.compact.size.zero?
          @on_finish.call(:all) if @on_finish
        end
      end

      #
      # clean up servers and stop 
      # the EventMachine event loop
      #
      def close
        unbind
        # try to stop eventmachine loop
        EM.stop rescue
        @on_close.call if @on_close
        WinRM::Log.debug(":session => :close")
      end
    end
  end
end