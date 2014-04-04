# Copyright 2013-2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

#
# -= Systems CSV =-
#
# Columns
#   Name
#     - System name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file

require 'hammer_cli'
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class ProductsCommand < BaseCommand
    LABEL = 'Label'
    ORGANIZATION = 'Organization'
    REPOSITORY = 'Repository'
    REPOSITORY_TYPE = 'Repository Type'
    REPOSITORY_URL = 'Repository Url'
    DESCRIPTION = 'Description'

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
        csv << [NAME, COUNT, LABEL, ORGANIZATION, REPOSITORY, REPOSITORY_TYPE, REPOSITORY_URL]
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          @api.resource(:products).call(:index, {
                                          'per_page' => 999999,
                                          'enabled' => true,
                                          'organization_id' => katello_organization(:name => organization['name'])
                                        })['results'].each do |product|
            # product = @api.resource(:products).call(:show, {
            #                                           'id' => product['id'],
            #                                           'fields' => 'full'
            #                                         })
            product['library_repositories'].each do |repository|
              if repository['sync_state'] != 'not_synced'
                repository_type = "#{repository['product_type'] == 'custom' ? 'Custom' : 'Red Hat'} #{repository['content_type'].capitalize}"
                csv << [namify(product['name'], 1), 1, product['label'], organization['name'], repository['name'],
                        repository_type, repository['feed']]
                #puts "  HTTPS:                     #{repository['unprotected'] ? 'No' : 'Yes'}"
              end
            end

          end
        end
      end
    end

    def import
      @existing_products = {}
      @existing_repositories = {}

      thread_import do |line|
        create_products_from_csv(line)
      end
    end

    def create_products_from_csv(line)
      if !@existing_products[line[ORGANIZATION]]
        @existing_products[line[ORGANIZATION]] = {}
        @api.resource(:products).call(:index, {
                               'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                               'page_size' => 999999,
                               'paged' => true
                             })['results'].each do |product|
          @existing_products[line[ORGANIZATION]][product['name']] = product['id'] if product

          if product
            @api.resource(:repositories).call(:index, {
                                      'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                      'product_id' => product['id'],
                                      'enabled' => true,
                                      'library' => true,
                                      'page_size' => 999999, 'paged' => true
                                    })['results'].each do |repository|
              @existing_repositories[line[ORGANIZATION] + product['name']] ||= {}
              @existing_repositories[line[ORGANIZATION] + product['name']][repository['label']] = repository['id']
            end
          end
        end
      end

      # Only creating products, not updating
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        puts @existing_products
        product_id = @existing_products[line[ORGANIZATION]][name]
        if !product_id
          print "Creating product '#{name}'..." if option_verbose?
          if line[REPOSITORY_TYPE] =~ /Red Hat/
            raise "Red Hat product '#{name}' does not exist in '#{line[ORGANIZATION]}'"
          end

          product_id = @api.resource(:products).call(:create, {
                                               'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                               'name' => name
                                             })['id']
          @existing_products[line[ORGANIZATION]][name] = product_id
        else
          # Nothing to update for products
          print "Updating product '#{name}'..." if option_verbose?
        end
        @existing_repositories[line[ORGANIZATION] + name] = {}
        print "done\n" if option_verbose?

        repository_name = namify(line[REPOSITORY], number)

        # Hash the existing repositories for the product
        if !@existing_repositories[line[ORGANIZATION] + name][repository_name]
          @api.resource(:repositories).call(:index, {
                                              'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                              'library' => true,
                                              'all' => false,
                                              'product_id' => product_id
                                            })['results'].each do |repository|
            @existing_repositories[line[ORGANIZATION] + name][repository['name']] = repository
          end
        end

        if !@existing_repositories[line[ORGANIZATION] + name][repository_name]
          print "Creating repository '#{repository_name}' in product '#{name}'..." if option_verbose?
          if line[REPOSITORY_TYPE] =~ /Red Hat/
            # TMP
            puts "TMP"
            @api.resource(:repositories).call(:index, {
                                                'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                                'library' => true,
                                                'all' => true,
                                                'product_id' => product_id
                                              })['results'].each do |repository|
              puts repository if repository['name'] == repository_name
            end
            puts "END TMP"
            #repository_id = redhat_create_repository(product_id, repository_name)

          else
            repository_id = @api.resource(:repositories).call(:create, {
                                       'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                       'name' => repository_name,
                                       'label' => labelize(repository_name),
                                       'product_id' => product_id,
                                       'url' => line[REPOSITORY_URL],
                                       'content_type' => content_type(line[REPOSITORY_TYPE])
                                     })['id']
          end
          @existing_repositories[line[ORGANIZATION] + name][line[LABEL]] = repository_id

          puts "TODO: skipping sync"
          # task_id = @api.resource(:repositories).call(:sync, {
          #                                               'organization_id' => katello_organization(:name => line[ORGANIZATION]),
          #                                               'id' => repository_id
          #                                             })['id']
          # TODO: wait for sync task
          print "done\n" if option_verbose?
        end
      end

    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end

    private

    def redhat_create_repository(product_id, repository_name)
      @api.resource(:repository_sets).call(:index, {
                                             'product_id' => product_id
                                           })['results'].each do |repository|
        puts repository
        puts @api.resource(:repository_sets).call(:show, {
                                                    'product_id' => product_id,
                                                    'id' => repository['id']})
        return
        if repository['name'] == repository_name
          puts repository
          @api.resource(:repository_sets).call(:enable, {
                                                 'product_id' => product_id,
                                                 'repository_id' => repository['id']
                                               })
          return
        end
        raise "Repository '#{repository_name}' does not exist"
      end
    end

    def content_type(repository_type)
      case repository_type
        when /Yum/
          'yum'
        when /Puppet/
          'puppet'
        else
        raise "Unrecognized repository type '#{repository_type}'"
      end
    end
  end

  HammerCLICsv::CsvCommand.subcommand('products',
                                      'import or export products',
                                      HammerCLICsv::ProductsCommand)
end
