# hammer-cli-csv [![Build Status](https://travis-ci.org/Katello/hammer-cli-csv.svg?branch=master)](https://travis-ci.org/Katello/hammer-cli-csv) [![Coverage Status](https://coveralls.io/repos/github/Katello/hammer-cli-csv/badge.svg?branch=master)](https://coveralls.io/github/Katello/hammer-cli-csv?branch=master)

## Introduction

[Hammer](https://github.com/theforeman/hammer-cli/blob/master/README.md) is a command line interface (CLI) framework which provides a core to which modules may be added. This module, hammer-cli-csv, adds commands to interact with the following products: [Foreman](https://theforeman.org) standalone, [Katello](http://www.katello.org/), Red Hat's Satellite-6, and Red Hat's Subscription Asset Manager (SAM).

The purpose of this module's commands are to allow a convenient mechanism to both export to and import from CSV files (comma separated values). Each of the server's supported resource types, such as organizations and users, is handled.

Some possible uses include

* Import demo or development data easily and consistently
* Export another server's data and then import into elsewhere for testing and debug
* Export for backup and auditing

The following sections will cover installation, usage, and examples. All of the resource types are follow in the order which generally is required for dependency resolution (eg. roles must exist to assign to users so the role section comes first).

## Installation

```bash
gem install hammer_cli_csv
gem install hammer_cli_katello

mkdir -p ~/.hammer/cli.modules.d/

cat <<EOQ > ~/.hammer/cli.modules.d/csv.yml
:csv:
  :enable_module: true
EOQ

# to confirm things work, this should return useful output
hammer csv --help

```

## General Usage

Supported commands and options are available by using the --help option. Additional subcommands and options may be listed here but are considered "tech preview" to indicate the lack of testing and official support.

| Option | Description |
| ---------------:| :--------------|
| --export | If not specified will run import. |
| --file FILE_NAME | File to import from or export to. If not specified reads or writes to/from stdin and stdout. Note: On ruby-1.8.7 this option is required. |
| --prefix PREFIX | Convenience method to add a prefix to all Count substituted values. See examples below. |
| --server SERVER | The server to run against. Overrides any config file value. |
| --username USERNAME | Username for server. Overrides any config file value. |
| --password PASSWORD | Password for user. Overrides any config file value. |
| --verbose | Display verbose progress information during import. |
| --continue-on-error | Continue processing even if individual resource error |

## Count Substitution

Some columns of input data have a special syntax available termed "Count substitution" below.

This hammer module started out as a way to generate large amounts of test data. As such, it was convenient to be able to add a single row to an input CSV file and have it generate multiple records.

Take this Organization CSV as an example:

```
Name, Count, Label, Description
# Start a row with a # to indicate a comment, a row to be skipped
Organization %d, 4, testorg%d, A test organization
```

The single row, with a Count value of four, would generate four organizations ("Organization 0", "Organization 1", "Organization 2", and "Organization 3"). Notice that the Label column, which must be unique, also has the Count column substition.

During export, the Count column will always be one (1).

## Examples

## Organizations

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=organizations&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/organizations_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/organizations.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the organization to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Label | Unique organization label | x |   |
| Description | Organization description |   |

**Examples**

Here is an example of a CSV file to create an organization

```
Name, Count, Label, Description
# Start a row with a # to indicate a comment, a row to be skipped
Mega Corporation, 1, megacorp, The number one mega company in the world!
```

If above is saved to a file such as **megacorp/organizations.csv** the following command will run import to create or update the organization.

```
$ hammer csv organizations --version --csv-file megacorp/organizations.csv
Updating organization 'Mega Corporation'... done

$ hammer csv organizations --csv-export
"Name","Count","Label","Description"
"Mega Corporation","1","megacorp","The number one mega company in the world!"

# Import but prefix all substitution columns with a string
$ hammer csv organizations --verbose --csv-file test/data/organizations.csv --prefix xyz
Creating organization 'xyzMega Corporation'... done

# Export and pipe to import with a new prefix
$ hammer csv organizations --csv-export | hammer csv organizations --verbose --csv-file test/data/organizations.csv --prefix abc
Creating organization 'abcMega Corporation'... done
```

## Locations

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=locations&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/locations_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/locations.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the location to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Parent Location | Parent location |   |

## Puppet Environments

**Overview**
* Due to the implications of removing a puppet environment from an organization or location, this column only adds to what is present already.
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=puppet-environments&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/puppet_environments_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/puppet-environments.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the puppet environments to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organizations | Comma separated list of organizations |   |

## Operating Systems

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=operating-systems&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/operating_systems_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/operating-systems.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the operating systems to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Family | Operating system family |   |
| Description | Operating system description |   |
| Password Hash | MD5, SHA256, SHA512, or Base64 |   |
| Partition Tables | List of partition table names |   |
| Architectures | List of architectures names |   |
| Media | List of media names |   |
| Provisioning Templates | List of provisioning template names |   |
| Parameters | List of parameters |   |

## Domains

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=domains&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/domains_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/domains.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the domains to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Full Name | Full name of the domain |   |
| Organizations | Comma separated list of organizations |   |

## Architectures

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=architectures&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/architectures_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/architectures.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the architectures to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Operating Systems | Comma separated list of operating system names |   |

## Partition Tables

**Overview**
* Import and export of the Organizations and Locations columns does not apply to all versions and will be silently ignored when unsupported.
* Importing Operating Systems column does not apply to all versions and will be silently ignored when unsupported.
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=partition-tables&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/partition_tables_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/partition-tables.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the partition tables to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| OS Family | Operating system family |   |
| Operating Systems | Comma separated list of operating system names |   |
| Layout | Disk layout |   |

## Lifecycle Environments

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=lifecycle-environments&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/lifecycle_environments_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/lifecycle-environments.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the lifecycle environments to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organization | Organization name |   |
| Prior Environment | Previous organization name in path |   |
| Description | Lifecycle environment description |   |

## Host Collections

| Additional arguments | Description |
| ---------------:| :--------------|
| --organization | Only process organization matching this name |

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=host-collections&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/host_collections_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/host-collections.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the host collections to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organization | Organization name |   |
| Limit | Usage limit |   |
| Description | Host collection description |   |

## Products

| Additional arguments | Description |
| ---------------:| :--------------|
| --organization | Only process organization matching this name |
| --[no-]sync | Sync product repositories (default true) |

**Overview**
* Due to the length of time that syncing repositories can take, the --no-sync option may be used to skip this step. To always disable syncing, ':products_sync: false' may be specified in configuration file.
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=products&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/products_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/products.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the host collections to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Label | Unique label  |   |
| Organization | Organization name |   |
| Repository | Repository name |   |
| Repository Url | Repository Url |   |
| Description | Repository description |   |

## Provisioning Templates

| Additional arguments | Description |
| ---------------:| :--------------|
| --organization | Only process organization matching this name |

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=provisioning-templates&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/provisioning_templates_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/provisioning_templates.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the provisioning templates to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organizations  | Comma separated list of organizations |   |
| Locations  | Comma separated list of locations |   |
| Operating Systems  | Comma separated list of associated operating systems |   |
| Host Group / Puppet Environment Combinations  | Comma separated list of host group and puppet environment associations |   |
| Kind  | Kind of template (eg. snippet) |   |
| Template  | Full text of template |   |

## Subscriptions

| Additional arguments | Description |
| ---------------:| :--------------|
| --organization | Only process organization matching this name |

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=subscriptions&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/subscriptions_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/subscriptions.csv)

Import will only process rows with a Name of "Manifest" and trigger a manifest import to run on the specified Manifest File. Subscription rows are not be processed.

Export will output a summary of the subscriptions currently imported into the organizations. These rows will have a description in the Name column as a comment (value starting with a #). For example,
```
Name,Organization,Manifest File,Subscription Name,Quantity,Product SKU,Contract Number,Account Number
# Subscription,Mega Corporation,,"OpenShift Enterprise Premium, 2 Cores",2,MCT2735,10999111,5700573
```

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | "Manifest" to trigger import of manifest file | x |
| Count        | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organization | Organization name |   |
| Manifest File | Path to manifest file |   |
| Subscription Name | Name of subscription |   |
| Quantity     | Subscription quantity |   |
| SKU          | Subscription SKU |   |
| Contract Number | Subscription contract number |   |
| Account Number  | Subscription account number |   |

## Activation Keys

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=activation-keys&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/activation_keys_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/activation-keys.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the activation keys to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organization | Parent organization name |   |
| Description | Activation key description |   |
| Limit | Usage limit |   |
| Environment | Lifecycle environment name |   |
| Content View | Content view name |   |
| Host Collections | Comma separated list of host collections |   |
| Subscriptions | Comma separated list of subscriptions |   |

## Hosts

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=hosts&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/hosts_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/hosts.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the hosts to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organization | Organization name |   |
| Environment | Puppet environment name |   |
| Operating System | Operating system name |   |
| Architecture | Architecture name |   |
| MAC Address | Unique MAC address | x |
| Domain | Domain name |   |
| Partition Table | Partition table name |   |

## Content Hosts

| Additional arguments | Description |
| ---------------:| :--------------|
| --organization | Only process organization matching this name |

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=content-hosts&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/content_hosts_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/content-hosts.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the content hosts to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Organization | Organization name |   |
| Environment | Puppet environment name |   |
| Content View | Content view name |   |
| Host Collections | Comma separate list of host collectoins |   |
| Virtual | Virtual (Yes or No) |   |
| Host | Virtual content host name |   |
| OS | Operating system name |   |
| Arch | Architecture name |   |
| Sockets | Number of sockets |   |
| RAM | Amount of RAM with units |   |
| Cores | Number of cores |   |
| SLA | Service Level Agreement |   |
| Products | Comma separated list of subscriptions |   |
| Subscriptions | Comma separated list of subscriptions |   |

## Reports

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=reports&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/reports_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/reports.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the reports to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Time | Time of report |   |
| Applied |  |   |
| Restarted |  |   |
| Failed |  |   |
| Failed Restarts |  |   |
| Skipped |  |   |
| Pending |  |   |
| Metrics |  |   |

## Roles

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=roles&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/roles_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/roles.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the roles to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Resource | Resource to apply role to |   |
| Search | Search string |   |
| Permissions | Role permission |   |
| Organizations | Comma separated list of organizations |   |
| Locations | Comma separated list of locations |   |

## Users

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=users&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/users_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/users.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Name of the users to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| First Name | First name of user |   |
| Last Name | Last name of user |   |
| email | Email address |   |
| Organizations | Comma separated list of organizations |   |
| Locations | Comma separated list of locations |   |
| Roles | Comma separated list of role names for user |   |

## Settings

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=settings&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/settings_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/settings.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % |
| :----------- | :----------------- | :-: |
| Name         | Setting name to update or create | x |
| Count | Number of times to iterate this CSV row during import, incrementing value for substitution |   |
| Value | Setting value |   |

**Examples**
```
Name,Value
administrator,admin@megacorp.com
idle_timeout,60000
```

## Import

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=users&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/users_test.rb)

**Examples**

```
% hammer csv import -v --dir test/data --settings
Importing settings from 'test/data/settings.csv'
Updating setting 'idle_timeout'...done
```

# Development

## Code style

    rubocop -R <file>

## Tests

To run all tests using recorded data, run:

    rake test mode=none

To run all tests to record data:

    rake test mode=all

To run a single test using recorded data, run:

    rake test mode=none test=resources/settings

or

    rake test mode=none test=./test/resources/settings_test.rb

To run tests against your live Katello without recording a new cassette set record flag to false (does not apply to mode=none):

    record=false

To see RestClient logs while testing:

    logging=true

Test server configuration is taken from 'test/config.yml'. If that file does not exist then https://localhost with admin / changeme is the default.

    % cat test/config.yml

    :csv:
      :enable_module: true

    :foreman:
      :enable_module: true
      :host:          'http://katello:3000'
      :username:      'admin'
      :password:      'changeme'

    :katello:
      :enable_module: true
