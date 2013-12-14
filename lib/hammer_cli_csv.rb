require 'hammer_cli'
require 'hammer_cli/exit_codes'

module HammerCLICsv

  def self.exception_handler_class
    HammerCLICsv::ExceptionHandler
  end

  require 'hammer_cli_csv/base'
  require 'hammer_cli_csv/exception_handler'

  require 'hammer_cli_csv/activation_keys'
  require 'hammer_cli_csv/architectures'
  require 'hammer_cli_csv/domains'
  require 'hammer_cli_csv/puppet_environments'
  require 'hammer_cli_csv/hosts'
  require 'hammer_cli_csv/operating_systems'
  require 'hammer_cli_csv/organizations'
  require 'hammer_cli_csv/permissions'
  require 'hammer_cli_csv/partition_tables'
  require 'hammer_cli_csv/roles'
  require 'hammer_cli_csv/system_groups'
  require 'hammer_cli_csv/users'
  require 'hammer_cli_csv/puppet_facts'

  require 'hammer_cli_csv/content_views'
  require 'hammer_cli_csv/subscriptions'
  require 'hammer_cli_csv/systems'
  require 'hammer_cli_csv/system_groups'
  require 'hammer_cli_csv/products'
end
