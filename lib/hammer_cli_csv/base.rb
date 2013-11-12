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

require 'hammer_cli'
require 'katello_api'
require 'json'
require 'csv'

module HammerCLICsv
  class BaseCommand < HammerCLI::AbstractCommand

    HEADERS = {'Accept' => 'version=2,application/json'}

    option ["-v", "--verbose"], :flag, "be verbose"
    option ['--threads'], 'THREAD_COUNT', 'Number of threads to hammer with', :default => 1
    option ['--csv-file'], 'FILE_NAME', 'CSV file to name'
    option ['--csv-export'], :flag, 'Export current data instead of importing'

    def initialize(*args)
      @init_options = { :base_url => HammerCLI::Settings.get(:katello, :host),
                        :username => HammerCLI::Settings.get(:katello, :username),
                        :password => HammerCLI::Settings.get(:katello, :password) }
    end

    def get_lines(filename)
      file = File.open(filename ,'r')
      contents = file.readlines
      file.close
      contents
    end

    def namify(name_format, number)
      if name_format.index('%')
        name_format % number
      else
        name_format
      end
    end

    def thread_import
      csv = get_lines(csv_file)[1..-1]
      lines_per_thread = csv.length/threads.to_i + 1
      splits = []

      threads.to_i.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        lines = csv[start_index...finish_index].clone
        splits << Thread.new do
          lines.each do |line|
            if line.index('#') != 0
              yield line
            end
          end
        end
      end

      splits.each do |thread|
        thread.join
      end

    end
  end
end
