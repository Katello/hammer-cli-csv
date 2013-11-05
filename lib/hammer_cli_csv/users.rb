# Copyright (c) 2013 Red Hat
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
# -= Users CSV =-
#
# Columns
#   Login
#     - Login name of the user.
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "user%d" -> "user1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   First Name
#   Last Name
#   Email
#

require 'hammer_cli'
require 'katello_api'
require 'json'
require 'csv'

module HammerCLICsv
  class UsersCommand < BaseCommand
    def initialize(*args)
      super(args)
      # @users_api = KatelloApi::Resources::Users.new(@init_options)
      @users_api = KatelloApi::Resources::Ping.new(@init_options)
    end

    def execute
      lines_per_thread = csv.length/@threads + 1
      threads = []
      @client = RestCalls.new(build_url(@config))

      @threads.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        lines = csv[start_index...finish_index].clone
        threads << Thread.new do
          lines.each do |line|
            if line.index('#') != 0
              creator.call(line)
            end
          end
        end

      HammerCLI::EX_OK
    end

    def create_users_from_csv(line)
      details = parse_user_csv(line)

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        @users_api.create(:users, {
                            :user => {
                              :name => name,
                              :limit => details[:limit]
                            }
                          })
      end
    end

    def parse_user_csv(line)
      keys = [:name_format, :count, :first_name, :last_name, :email]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:users", "ping the katello server", HammerCLICsv::UsersCommand)
end
