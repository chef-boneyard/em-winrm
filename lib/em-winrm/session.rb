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

      ##### Proxy Methods
      def on_output(&blk); @on_output = blk; end
      def on_error(&blk); @on_error = blk; end
      def on_finish(&blk); @on_finish = blk; end

      def initialize(options={})
        if options[:logger]
          WinRM::Log.logger = options[:logger]
        else
          log_level = options[:log_level] || :info
          WinRM::Log.level(log_level)
        end
        @servers = {}
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
              s.run_command(data)
            end
            EM.defer(operation)
          end
        end
      end

      #
      # initialize connections to a server
      #
      def use(host, options)
        srv = Server.new(self, host, options)
        @servers[host] = srv
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
          @on_finish.call(:done) if @on_finish
          close 
        end
      end

      #
      # clean up servers and stop 
      # the EventMachine event loop
      #
      def close
        unbind
        EM.stop
      end
    end
  end
end