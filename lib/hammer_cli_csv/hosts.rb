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
# -= Hosts CSV =-
#
# Columns
#   Name
#     - Host name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   MAC Address
#     - MAC address
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "FF:FF:FF:FF:FF:%02x" -> "FF:FF:FF:FF:FF:0A"
#     - Warning: be sure to keep count below 255 or MAC hex will exceed limit
#

require 'hammer_cli'
require 'katello_api'
require 'foreman_api'
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class HostsCommand < BaseCommand

    def initialize(*args)
      super(args)
      @host_api = ForemanApi::Resources::Host.new(@init_options[:foreman])
      @organization_api = ForemanApi::Resources::Organization.new(@init_options[:foreman])
      @environment_api = ForemanApi::Resources::Environment.new(@init_options[:foreman])
      @operatingsystem_api = ForemanApi::Resources::OperatingSystem.new(@init_options[:foreman])
      @architecture_api = ForemanApi::Resources::Architecture.new(@init_options[:foreman])
      @domain_api = ForemanApi::Resources::Domain.new(@init_options[:foreman])
      @ptable_api = ForemanApi::Resources::Ptable.new(@init_options[:foreman])
    end

    def execute
      super

      csv_export? ? export : import

      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file || '/dev/stdout', 'wb') do |csv|
        csv << ['Name', 'Count', 'Org Label', 'Environment Label', 'OS', 'Arch', 'MAC Address', 'Domain', 'Partition Table']
        @host_api.index({:per_page => 999999}, HEADERS)[0].each do |host|
          host = @host_api.show({'id' => host['host']['id']}, HEADERS)[0]
          host = host['host']
          name = host['name']
          count = 1
          organization = foreman_organization(:id => host['organization_id'])
          environment = foreman_environment(:id => host['environment_id'])
          operatingsystem = foreman_operatingsystem(:id => host['operatingsystem_id'])
          architecture = foreman_architecture(:id => host['architecture_id'])
          mac = host['mac']
          domain = foreman_architecture(:id => host['domain_id'])
          ptable = foreman_ptable(:id => host['ptable_id'])

          csv << [name, count, organization, environment, operatingsystem, architecture, mac, domain, ptable]

          return # TODO
        end
      end
    end

    def import
      @existing = {}
      @host_api.index({:per_page => 999999}, HEADERS)[0].each do |host|
        host = host['host']
        @existing[host['name']] = host['id']
      end

      @environments = {}
      @operatingsystems = {}
      @architectures = {}
      @macs = {}
      @domains = {}
      @ptables = {}

      thread_import do |line|
        create_hosts_from_csv(line)
      end
    end

    def create_hosts_from_csv(line)
      details = parse_host_csv(line)

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing.include? name
          print "Creating host '#{name}'..." if verbose?

          organization_id = @organizations[details[:organization]]
          if !organization_id
            organization = @organization_api.index({:search => "name=\"#{details[:organization]}\""}, HEADERS)[0]
            organization_id = organization[0]['organization']['id']
            @organizations[details[:organization]] = organization_id
          end

          environment_id = @environments[details[:environment]]
          if !environment_id
            environment = @environment_api.index({:search => "name=\"#{details[:environment]}\""}, HEADERS)[0]
            environment_id = environment[0]['environment']['id']
            @environments[details[:environment]] = environment_id
          end

          operatingsystem_id = @operatingsystems[details[:operatingsystem]]
          if !operatingsystem_id
            (os, major, minor) = details[:operatingsystem].split(' ').collect {|s| s.split('.')}.flatten
            operatingsystem = @operatingsystem_api.index({:search => "name=\"#{os}\" and major=#{major} and minor=#{minor}"}, HEADERS)[0]
            operatingsystem_id = operatingsystem[0]['operatingsystem']['id']
            @operatingsystems[details[:operatingsystem]] = operatingsystem_id
          end

          architecture_id = @architectures[details[:architecture]]
          if !architecture_id
            architecture = @architecture_api.index({:search => "name=\"#{details[:architecture]}\""}, HEADERS)[0]
            architecture_id = architecture[0]['architecture']['id']
            @architectures[details[:architecture]] = architecture_id
          end

          domain_id = @domains[details[:domain]]
          if !domain_id
            domain = @domain_api.index({:search => "name=\"#{details[:domain]}\""}, HEADERS)[0]
            domain_id = domain[0]['domain']['id']
            @domains[details[:domain]] = domain_id
          end

          ptable_id = @ptables[details[:ptable]]
          if !ptable_id
            ptable = @ptable_api.index({:search => "name=\"#{details[:ptable]}\""}, HEADERS)[0]
            ptable_id = ptable[0]['ptable']['id']
            @ptables[details[:ptable]] = ptable_id
          end

          @host_api.create({
                             'host' => {
                               'name' => name,
                               'mac' => namify(details[:mac_format], number),
                               'organization_id' => foreman_organization(details[:organization]),
                               'environment_id' => environment_id,
                               'operatingsystem_id' => operatingsystem_id,
                               'environment_id' => environment_id,
                               'operatingsystem_id' => operatingsystem_id,
                               'architecture_id' => architecture_id,
                               'domain_id' => domain_id,
                               'ptable_id' => ptable_id
                             }
                           }, HEADERS)
          print "done\n" if verbose?
        else
          print "Updating host '#{name}'..." if verbose?
          print "  TODO  " if verbose?
          #@host_api.update({
          #                   'id' => @existing["#{name}-#{details[:major]}-#{details[:minor]}"],
          #                   'host' => {
          #                     'name' => name
          #                   }
          #                 }, HEADERS)
          print "done\n" if verbose?
        end
      end
    end

    def parse_host_csv(line)
      keys = [:name_format, :count, :organization, :environment, :operatingsystem, :architecture, :mac_format, :domain, :ptable]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end

    def foreman_organization(options={})
      @organizations ||= {}

      if options[:name]
        options[:id] = @organizations[options[:name]]
        if !options[:id]
          organization = @organization_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]
          options[:id] = organization[0]['organization']['id']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        options[:name] = @organizations.key(options[:id])
        if !options[:name]
          organization = @organization_api.show({'id' => options[:id]}, HEADERS)[0]
          options[:name] = organization['organization']['name']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_environment(options={})
      @environments ||= {}

      if options[:name]
        options[:id] = @environments[options[:name]]
        if !options[:id]
          environment = @environment_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]
          options[:id] = environment[0]['environment']['id']
          @environments[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        options[:name] = @environments.key(options[:id])
        if !options[:name]
          environment = @environment_api.show({'id' => options[:id]}, HEADERS)[0]
          options[:name] = environment['environment']['name']
          @environments[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_operatingsystem(options={})
      @operatingsystems ||= {}

      if options[:name]
        options[:id] = @operatingsystems[options[:name]]
        if !options[:id]
          operatingsystem = @operatingsystem_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]
          options[:id] = operatingsystem[0]['operatingsystem']['id']
          @operatingsystems[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        options[:name] = @operatingsystems.key(options[:id])
        if !options[:name]
          operatingsystem = @operatingsystem_api.show({'id' => options[:id]}, HEADERS)[0]
          options[:name] = "%{name} %{major}.%{minor}" % {:name => operatingsystem['operatingsystem']['name'],
                                                          :major => operatingsystem['operatingsystem']['major'],
                                                          :minor => operatingsystem['operatingsystem']['minor']}
          @operatingsystems[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_architecture(options={})
      @architectures ||= {}

      if options[:name]
        options[:id] = @architectures[options[:name]]
        if !options[:id]
          architecture = @architecture_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]
          options[:id] = architecture[0]['architecture']['id']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        options[:name] = @architectures.key(options[:id])
        if !options[:name]
          architecture = @architecture_api.show({'id' => options[:id]}, HEADERS)[0]
          options[:name] = architecture['architecture']['name']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_domain(options={})
      @domains ||= {}

      if options[:name]
        options[:id] = @domains[options[:name]]
        if !options[:id]
          domain = @domain_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]
          options[:id] = domain[0]['domain']['id']
          @domains[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        options[:name] = @domains.key(options[:id])
        if !options[:name]
          domain = @domain_api.show({'id' => options[:id]}, HEADERS)[0]
          options[:name] = domain['domain']['name']
          @domains[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_ptable(options={})
      @ptables ||= {}

      if options[:name]
        options[:id] = @ptables[options[:name]]
        if !options[:id]
          ptable = @ptable_api.index({'search' => "name=\"#{options[:name]}\""}, HEADERS)[0]
          options[:id] = ptable[0]['ptable']['id']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        options[:name] = @ptables.key(options[:id])
        if !options[:name]
          ptable = @ptable_api.show({'id' => options[:id]}, HEADERS)[0]
          options[:name] = ptable['ptable']['name']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end
  end

  HammerCLI::MainCommand.subcommand("csv:hosts", "ping the katello server", HammerCLICsv::HostsCommand)
end
