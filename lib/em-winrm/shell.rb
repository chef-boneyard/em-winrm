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
    class Shell
      include EM::Deferrable

      attr_accessor :client, :server, :remote_id

      def initialize(client, server)
        @client = client
        @server = server
        @remote_id = client.open_shell
        WinRM::Log.debug("#{server.host}[#{@remote_id}] => :shell_open")
        @out_channel = EM::Channel.new
        @err_channel = EM::Channel.new
      end

      #
      # called whenever the shell has output
      #
      def on_output(&block)
        @out_channel.subscribe block
      end

      #
      # called whenever the shell has error output
      #
      def on_error(&block)
        @err_channel.subscribe block
      end

      #
      # called whenever the shell is closed
      #
      def on_close(&block)
        @on_close = block
      end

      #
      # Open a shell and run a comamnd
      #
      def run_command(command)
        command_id = client.run_command(@remote_id, command)
        WinRM::Log.debug("#{server.host}[#{@remote_id}] => :run_command[#{command}]")
        output=client.get_command_output(@remote_id, command_id) do |out,error|
          @out_channel.push(out) if out
          @err_channel.push(error) if error
        end
        client.cleanup_command(@remote_id, command_id)
        WinRM::Log.debug("#{server.host}[#{@remote_id}] => :command_cleanup[#{command}]")
        @last_exit_code = output[:exitcode]
        close
        output[:exitcode]
      end

      #
      # Close and cleanup a shell
      #
      def close
        r = client.close_shell(@remote_id)
        WinRM::Log.debug("#{server.host}[#{@remote_id}] => :shell_close")
        @on_close.call(r,@last_exit_code) if @on_close
      end
    end
  end
end
