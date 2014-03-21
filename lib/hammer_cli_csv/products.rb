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

    ORGANIZATION = 'Organization'
    REPOSITORY = 'Repository'
    REPOSITORY_TYPE = 'Repository Type'
    REPOSITORY_URL = 'Repository Url'

    def export
      # TODO
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
              @existing_repositories[line[ORGANIZATION]+product['name']] ||= {}
              @existing_repositories[line[ORGANIZATION]+product['name']][repository['label']] = repository['id']
            end
          end
        end
      end

      # Only creating products, not updating
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        product_id = @existing_products[line[ORGANIZATION]][name]
        if !product_id
          print "Creating product '#{name}'..." if option_verbose?
          product_id = @api.resource(:products).call(:create, {
                                               'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                               'name' => name
                                             })['id']
          @existing_products[line[ORGANIZATION]][name] = product_id
        else
          # Nothing to update for products
          print "Updating product '#{name}'..." if option_verbose?
        end
        print "done\n" if option_verbose?
        @existing_repositories[line[ORGANIZATION] + name] ||= {}

        # Only creating repositories, not updating
        repository_name = namify(line[REPOSITORY], number)
        if !@existing_repositories[line[ORGANIZATION] + name][labelize(repository_name)]
          print "Creating repository '#{repository_name}' in product '#{name}'..." if option_verbose?
          @api.resource(:repositories).call(:create, {
                                     'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                     'name' => repository_name,
                                     'label' => labelize(repository_name),
                                     'product_id' => product_id,
                                     'url' => line[REPOSITORY_URL],
                                     'content_type' => line[REPOSITORY_TYPE]
                                   })
          print "done\n" if option_verbose?
        end
      end

    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end
  end

  HammerCLI::MainCommand.subcommand("csv:products", "import/export products and repositories",
                                    HammerCLICsv::ProductsCommand)
end
