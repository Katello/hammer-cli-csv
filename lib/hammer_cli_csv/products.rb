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
require 'katello_api'
require 'foreman_api'
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class ProductsCommand < BaseCommand

    ORGANIZATION = 'Organization'
    PROVIDER = 'Provider'
    REPOSITORY = 'Repository'
    REPOSITORY_TYPE = 'Repository Type'
    REPOSITORY_URL = 'Repository Url'

    def export
      # TODO
    end

    def import
      @existing_products = {}
      @existing_providers = {}
      @existing_repositories = {}

      thread_import do |line|
        create_products_from_csv(line)
      end
    end

    def create_products_from_csv(line)
      if !@existing_providers[line[ORGANIZATION]]

        @k_provider_api.index({'organization_id' => line[ORGANIZATION], 'page_size' => 999999, 'paged' => true})[0]['results'].each do |provider|
          @existing_providers[line[ORGANIZATION]] ||= {}
          @existing_providers[line[ORGANIZATION]][provider['name']] = provider['id'] if provider
        end

        @k_product_api.index({'organization_id' => line[ORGANIZATION], 'page_size' => 999999, 'paged' => true})[0]['results'].each do |product|
          @existing_products[line[ORGANIZATION]] ||= {}
          @existing_products[line[ORGANIZATION]][product['name']] = product['id'] if product

          if product
            @k_repository_api.index({
                                      'organization_id' => line[ORGANIZATION],
                                      'product_id' => product['id'],
                                      'enabled' => true,
                                      'library' => true,
                                      'page_size' => 999999, 'paged' => true
                                    })[0]['results'].each do |repository|
              @existing_repositories[line[ORGANIZATION]+product['name']] ||= {}
              @existing_repositories[line[ORGANIZATION]+product['name']][repository['label']] = repository['id']
            end
          end
        end
      end

      # Only creating providers, not updating
      if !@existing_providers[line[ORGANIZATION]][line[PROVIDER]]
        print "Creating provider '#{line[PROVIDER]}'..." if verbose?
        id = @k_provider_api.create({
                                      'name' => line[PROVIDER],
                                      'organization_id' => line[ORGANIZATION]
                                    })[0]['id']
        @existing_providers[line[ORGANIZATION]][line[PROVIDER]] = id
        print "done\n" if verbose?
      end
      provider_id = @existing_providers[line[ORGANIZATION]][line[PROVIDER]]

      # Only creating products, not updating
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        product_id = @existing_products[line[ORGANIZATION]][name]
        if !product_id
          print "Creating product '#{name}'..." if verbose?
          product_id = @k_product_api.create({
                                               'name' => name,
                                               'provider_id' => provider_id
                                             })[0]['id']
          @existing_products[line[ORGANIZATION]][name] = product_id
          print "done\n" if verbose?
        end
        @existing_repositories[line[ORGANIZATION] + name] ||= {}

        # Only creating repositories, not updating
        repository_name = namify(line[REPOSITORY], number)
        if !@existing_repositories[line[ORGANIZATION] + name][labelize(repository_name)]
          print "Creating repository '#{repository_name}' in product '#{name}'..." if verbose?
          @k_repository_api.create({
                                     'name' => repository_name,
                                     'label' => labelize(repository_name),
                                     'product_id' => product_id,
                                     'url' => line[REPOSITORY_URL],
                                     'content_type' => line[REPOSITORY_TYPE]
                                   })
          print "done\n" if verbose?
        end
      end

    rescue RuntimeError => e
      raise RuntimeError.new("#{e}\n       #{line}")
    end
  end

  HammerCLI::MainCommand.subcommand("csv:products", "import/export products and repositories", HammerCLICsv::ProductsCommand)
end
