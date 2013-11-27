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
require 'foreman_api'
require 'json'
require 'csv'

module HammerCLICsv
  class BaseCommand < HammerCLI::AbstractCommand

    NAME = 'Name'
    COUNT = 'Count'

    HEADERS = {'Accept' => 'version=2,application/json'}

    option ["-v", "--verbose"], :flag, "be verbose"
    option ['--threads'], 'THREAD_COUNT', 'Number of threads to hammer with', :default => 1
    option ['--csv-export'], :flag, 'Export current data instead of importing'
    option ['--csv-file'], 'FILE_NAME', 'CSV file (default to /dev/stdout with --csv-export, otherwise required)'
    option ['--server'], 'SERVER', 'Server URL'
    option ['-u', '--username'], 'USERNAME', 'Username to access server'
    option ['-p', '--password'], 'PASSWORD', 'Password to access server'

    def execute
      if !csv_file
        csv_file = '/dev/stdout' if csv_export? # TODO: how to get this to actually set value?
        signal_usage_error "--csv-file required" if !csv_file
      end

      @init_options = {
        :base_url => server   || HammerCLI::Settings.get(:host),
        :username => username || HammerCLI::Settings.get(:username),
        :password => password || HammerCLI::Settings.get(:password)
      }

      @k_system_api ||= KatelloApi::Resources::System.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}/katello"}))

      @f_architecture_api ||= ForemanApi::Resources::Architecture.new(@init_options)
      @f_domain_api ||= ForemanApi::Resources::Domain.new(@init_options)
      @f_environment_api ||= ForemanApi::Resources::Environment.new(@init_options)
      @f_host_api ||= ForemanApi::Resources::Host.new(@init_options)
      @f_operatingsystem_api ||= ForemanApi::Resources::OperatingSystem.new(@init_options)
      @f_organization_api ||= ForemanApi::Resources::Organization.new(@init_options)
      @f_partitiontable_api ||= ForemanApi::Resources::Ptable.new(@init_options)
      @f_puppetfacts_api ||= ForemanApi::Resources::FactValue.new(@init_options)
      @f_user_api ||= ForemanApi::Resources::User.new(@init_options)
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

    def thread_import(return_headers=false)
      csv = []
      CSV.foreach(csv_file, {:skip_blanks => true, :headers => :first_row, :return_headers => return_headers}) do |line|
        csv << line
      end
      lines_per_thread = csv.length/threads.to_i + 1
      splits = []

      threads.to_i.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        lines = csv[start_index...finish_index].clone
        splits << Thread.new do
          lines.each do |line|
            if line[NAME][0] != '#'
              yield line
            end
          end
        end
      end

      splits.each do |thread|
        thread.join
      end
    end

    def foreman_organization(options={})
      @organizations ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @organizations[options[:name]]
        if !options[:id]
          organization = @f_organization_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]['results']
          raise RuntimeError.new("Organization '#{options[:name]}' not found") if !organization || organization.empty?
          options[:id] = organization[0]['id']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @organizations.key(options[:id])
        if !options[:name]
          organization = @f_organization_api.show({'id' => options[:id]}, HEADERS)[0]
          raise RuntimeError.new("Organization 'id=#{options[:id]}' not found") if !organization || organization.empty?
          options[:name] = organization['name']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_environment(options={})
      @environments ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @environments[options[:name]]
        if !options[:id]
          environment = @f_environment_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]['results']
          raise RuntimeError.new("Puppet environment '#{options[:name]}' not found") if !environment || environment.empty?
          options[:id] = environment[0]['id']
          @environments[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @environments.key(options[:id])
        if !options[:name]
          environment = @f_environment_api.show({'id' => options[:id]}, HEADERS)[0]
          raise RuntimeError.new("Puppet environment '#{options[:name]}' not found") if !environment || environment.empty?
          options[:name] = environment['name']
          @environments[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_operatingsystem(options={})
      @operatingsystems ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @operatingsystems[options[:name]]
        if !options[:id]
          (osname, major, minor) = split_os_name(options[:name])
          search = "name=\"#{osname}\" and major=\"#{major}\" and minor=\"#{minor}\""
          operatingsystems = @f_operatingsystem_api.index({'search' => search}, HEADERS)[0]['results']
          operatingsystem = operatingsystems[0]
          raise RuntimeError.new("Operating system '#{options[:name]}' not found") if !operatingsystem || operatingsystem.empty?
          options[:id] = operatingsystem['id']
          @operatingsystems[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @operatingsystems.key(options[:id])
        if !options[:name]
          operatingsystem = @f_operatingsystem_api.show({'id' => options[:id]}, HEADERS)[0]
          raise RuntimeError.new("Operating system 'id=#{options[:id]}' not found") if !operatingsystem || operatingsystem.empty?
          options[:name] = build_os_name(operatingsystem['name'],
                                         operatingsystem['major'],
                                         operatingsystem['minor'])
          @operatingsystems[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_architecture(options={})
      @architectures ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @architectures[options[:name]]
        if !options[:id]
          architecture = @f_architecture_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]['results']
          raise RuntimeError.new("Architecture '#{options[:name]}' not found") if !architecture || architecture.empty?
          options[:id] = architecture[0]['id']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @architectures.key(options[:id])
        if !options[:name]
          architecture = @f_architecture_api.show({'id' => options[:id]}, HEADERS)[0]
          raise RuntimeError.new("Architecture 'id=#{options[:id]}' not found") if !architecture || architecture.empty?
          options[:name] = architecture['name']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_domain(options={})
      @domains ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @domains[options[:name]]
        if !options[:id]
          domain = @f_domain_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]['results']
          raise RuntimeError.new("Domain '#{options[:name]}' not found") if !domain || domain.empty?
          options[:id] = domain[0]['id']
          @domains[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @domains.key(options[:id])
        if !options[:name]
          domain = @f_domain_api.show({'id' => options[:id]}, HEADERS)[0]
          raise RuntimeError.new("Domain 'id=#{options[:id]}' not found") if !domain || domain.empty?
          options[:name] = domain['name']
          @domains[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_partitiontable(options={})
      @ptables ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @ptables[options[:name]]
        if !options[:id]
          ptable = @f_partitiontable_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]['results']
          raise RuntimeError.new("Partition table '#{options[:name]}' not found") if !ptable || ptable.empty?
          options[:id] = ptable[0]['id']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:id]
      elsif options[:id]
        return nil if options[:id].nil?
        options[:name] = @ptables.key(options[:id])
        if !options[:name]
          ptable = @f_partitiontable_api.show({'id' => options[:id]}, HEADERS)[0]
          options[:name] = ptable['name']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:name]
      elsif !options[:name] && !options[:id]
        result = ''
      end

      result
    end

    def katello_environment(options={})
      @environments ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @environments[options[:name]]
        if !options[:id]
          environment = @k_environment_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]
          raise RuntimeError.new("Puppet environment '#{options[:name]}' not found") if !environment || environment.empty?
          options[:id] = environment[0]['id']
          @environments[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @environments.key(options[:id])
        if !options[:name]
          environment = @f_environment_api.show({'id' => options[:id]}, HEADERS)[0]
          raise RuntimeError.new("Puppet environment '#{options[:name]}' not found") if !environment || environment.empty?
          options[:name] = environment['name']
          @environments[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def build_os_name(name, major, minor)
      name += " #{major}" if major && major != ""
      name += ".#{minor}" if minor && minor != ""
      name
    end

    def split_os_name(name)
      (name, major, minor) = name.split(' ').collect {|s| s.split('.')}.flatten
      [name, major || "", minor || ""]
    end
  end
end
