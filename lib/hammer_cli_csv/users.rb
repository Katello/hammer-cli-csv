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

    NAME = 'Login'
    COUNT = 'Count'
    FIRSTNAME = 'First Name'
    LASTNAME = 'Last Name'
    EMAIL = 'Email'

    def execute
      super
      csv_export? ? export : import

      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, FIRSTNAME, LASTNAME, EMAIL]
        if katello?
          @k_user_api.index({}, HEADERS)[0].each do |user|
            csv << [user['username'], 1, '', '', user['email']]
          end
        else
          @f_user_api.index({:per_page => 999999}, HEADERS)[0].each do |user|
            csv << [user['login'], 1, user['firstname'], user['lastname'], user['mail']]
          end
        end
      end
    end

    def import
      @existing = {}
      if katello?
        @k_user_api.index[0].each do |user|
          @existing[user['username']] = user['id']
        end
      else
        @f_user_api.index({:per_page => 999999}, HEADERS)[0].each do |user|
          user = user['user']
          @existing[user['login']] = user['id']
        end
      end

      thread_import do |line|
        create_users_from_csv(line)
      end
    end

    def create_users_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        if !@existing.include? name
          print "Creating user '#{name}'... " if verbose?
          if katello?
            @k_user_api.create({
                                 'user' => {
                                   'username' => name,
                                   'email' => line[EMAIL],
                                   'password' => 'admin'
                                 }
                               }, HEADERS)
          else
            @f_user_api.create({
                                 'user' => {
                                   'login' => name,
                                   'firstname' => line[FIRSTNAME],
                                   'lastname' => line[LASTNAME],
                                   'mail' => line[EMAIL],
                                   'password' => 'admin',
                                   'auth_source_id' => 1,  # INTERNAL auth
                                 }
                               }, HEADERS)
          end
          print "done\n" if verbose?
        else
          print "Updating user '#{name}'... " if verbose?
          if katello?
            @k_user_api.update({
                                 'id' => @existing[name],
                                 'user' => {
                                   'username' => name,
                                   'email' => line[EMAIL],
                                   'password' => 'admin'
                                 }
                               }, HEADERS)
          else
            @f_user_api.update({
                                 'id' => @existing[name],
                                 'user' => {
                                   'login' => name,
                                   'firstname' => line[FIRSTNAME],
                                   'lastname' => line[LASTNAME],
                                   'mail' => line[EMAIL],
                                   'password' => 'admin'
                                 }
                               }, HEADERS)
          end
          print "done\n" if verbose?
        end
      end
    end
  end

  HammerCLI::MainCommand.subcommand("csv:users", "ping the katello server", HammerCLICsv::UsersCommand)
end
