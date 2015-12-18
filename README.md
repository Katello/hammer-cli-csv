# hammer-cli-csv ![Travis # Status](https://travis-ci.org/Katello/hammer-cli-csv.svg?branch=master)

## Introduction

[Hammer](https://github.com/theforeman/hammer-cli/blob/master/README.md) is a command line interface (CLI) framework which provides a core to which modules may be added. This module, hammer-cli-csv, adds commands to interact with the following products: [Foreman](https://theforeman.org) standalone, [Katello](http://www.katello.org/), Red Hat's Satellite-6, and Red Hat's Subscription Asset Manager (SAM).

The purpose of this module's commands are to allow a convenient mechanism to both export to and import from CSV files (comma separated values). Each of the server's supported resource types, such as organizations and users, are handled.

Some possible uses include

* Import demo or development data easily and consistently
* Export another server's data and then import into elsewhere for testing and debug
* Export for backup and auditing
* Export from SAM-1.4 to import into Satellite-6

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

## Usage

| Option | Description |
| ---------------:| :--------------|
| --csv-export | If not specified will run import. |
| --csv-file FILE_NAME | File to import from or export to. If not specified reads or writes to/from stdin and stdout. Note: On ruby-1.8.7 this option is required. |
| --prefix PREFIX | Convenience method to add a prefix to all Count substituted values. See examples below. |
| --server SERVER | The server to run against. Overrides any config file value. |
| --username USERNAME | Username for server. Overrides any config file value. |
| --password PASSWORD | Password for user. Overrides any config file value. |
| --verbose | Display verbose progress information during import. |

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

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the organization to update or create | x | x | x | x | x |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x | x |
| Label | Unique organization label | x |   | x | x | x |
| Description | Organization description |   | x | x | x | x |

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

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the location to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Parent Location | Parent location |   | x | x | x |   |

## Puppet Environments

**Overview**
* Due to the implications of removing a puppet environment from an organization or location, this column only adds to what is present already.
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=puppet-environments&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/puppet_environments_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/puppet-environments.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the puppet environments to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organizations | Comma separated list of organizations |   | x | x | x |   |

## Operating Systems

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=operating-systems&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/operating_systems_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/operating-systems.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the operating systems to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Family | Operating system family |   | x | x | x |   |
| Description | Operating system description |   | x | x | x |   |
| Password Hash | MD5, SHA256, SHA512, or Base64 |   | x | x | x |   |
| Partition Tables | List of partition table names |   | x | x | x |   |
| Architectures | List of architectures names |   | x | x | x |   |
| Media | List of media names |   | x | x | x |   |
| Provisioning Templates | List of provisioning template names |   | x | x | x |   |
| Parameters | List of parameters |   | x | x | x |   |

## Domains

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=domains&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/domains_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/domains.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the domains to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Full Name | Full name of the domain |   | x | x | x |   |
| Organizations | Comma separated list of organizations |   | x | x | x |   |

## Architectures

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=architectures&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/architectures_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/architectures.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the architectures to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Operating Systems | Comma separated list of operating system names |   | x | x | x |   |

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

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the partition tables to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| OS Family | Operating system family |   | x | x | x |   |
| Operating Systems | Comma separated list of operating system names |   | x | x | x |   |
| Layout | Disk layout |   | x | x | x |   |

## Lifecycle Environments

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=lifecycle-environments&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/lifecycle_environments_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/lifecycle-environments.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the lifecycle environments to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Prior Environment | Previous organization name in path |   | x | x | x |   |
| Description | Lifecycle environment description |   | x | x | x |   |

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

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the host collections to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Limit | Usage limit |   | x | x | x |   |
| Description | Host collection description |   | x | x | x |   |

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

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the host collections to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Label | Unique label  |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Repository | Repository name |   | x | x | x |   |
| Repository Url | Repository Url |   | x | x | x |   |
| Description | Repository description |   | x | x | x |   |

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

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the provisioning templates to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organizations  | Comma separated list of organizations |   | x | x | x |   |
| Locations  | Comma separated list of locations |   | x | x | x |   |
| Operating Systems  | Comma separated list of associated operating systems |   | x | x | x |   |
| Host Group / Puppet Environment Combinations  | Comma separated list of host group and puppet environment associations |   | x | x | x |   |
| Kind  | Kind of template (eg. snippet) |   | x | x | x |   |
| Template  | Full text of template |   | x | x | x |   |

## Subscriptions

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=subscriptions&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/subscriptions_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/subscriptions.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the subscriptions to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Manifest File | Path to manifest file |   | x | x | x |   |
| Content Set | Repository content set to enable |   | x | x | x |   |
| Arch | Architecture |   | x | x | x |   |
| Release | Release version |   | x | x | x |   |

## Activation Keys

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=activation-keys&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/activation_keys_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/activation-keys.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the activation keys to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Parent organization name |   | x | x | x |   |
| Description | Activation key description |   | x | x | x |   |
| Limit | Usage limit |   | x | x | x |   |
| Environment | Lifecycle environment name |   | x | x | x |   |
| Content View | Content view name |   | x | x | x |   |
| Host Collections | Comma separated list of host collections |   | x | x | x |   |
| Subscriptions | Comma separated list of subscriptions |   | x | x | x |   |

## Hosts

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=hosts&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/hosts_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/hosts.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the hosts to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Environment | Puppet environment name |   | x | x | x |   |
| Operating System | Operating system name |   | x | x | x |   |
| Architecture | Architecture name |   | x | x | x |   |
| MAC Address | Unique MAC address | x | x | x | x |   |
| Domain | Domain name |   | x | x | x |   |
| Partition Table | Partition table name |   | x | x | x |   |

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

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the content hosts to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Environment | Puppet environment name |   | x | x | x |   |
| Content View | Content view name |   | x | x | x |   |
| Host Collections | Comma separate list of host collectoins |   | x | x | x |   |
| Virtual | Virtual (Yes or No) |   | x | x | x |   |
| Host | Virtual content host name |   | x | x | x |   |
| OS | Operating system name |   | x | x | x |   |
| Arch | Architecture name |   | x | x | x |   |
| Sockets | Number of sockets |   | x | x | x |   |
| RAM | Amount of RAM with units |   | x | x | x |   |
| Cores | Number of cores |   | x | x | x |   |
| SLA | Service Level Agreement |   | x | x | x |   |
| Products | Comma separated list of subscriptions |   | x | x | x |   |
| Subscriptions | Comma separated list of subscriptions |   | x | x | x |   |

## Reports

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=reports&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/reports_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/reports.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the reports to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Time | Time of report |   | x | x | x |   |
| Applied |  |   | x | x | x |   |
| Restarted |  |   | x | x | x |   |
| Failed |  |   | x | x | x |   |
| Failed Restarts |  |   | x | x | x |   |
| Skipped |  |   | x | x | x |   |
| Pending |  |   | x | x | x |   |
| Metrics |  |   | x | x | x |   |

## Roles

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=roles&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/roles_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/roles.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the roles to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Resource | Resource to apply role to |   | x | x | x |   |
| Search | Search string |   | x | x | x |   |
| Permissions | Role permission |   | x | x | x |   |
| Organizations | Comma separated list of organizations |   | x | x | x |   |
| Locations | Comma separated list of locations |   | x | x | x |   |

## Users

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=users&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/users_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/users.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the users to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| First Name | First name of user |   | x | x | x |   |
| Last Name | Last name of user |   | x | x | x |   |
| email | Email address |   | x | x | x |   |
| Organizations | Comma separated list of organizations |   | x | x | x |   |
| Locations | Comma separated list of locations |   | x | x | x |   |
| Roles | Comma separated list of role names for user |   | x | x | x |   |

## Settings

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=settings&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/settings_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/settings.csv)

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Katello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Setting name to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Value | Setting value |   | x | x | x |   |

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
% hammer csv import -v --organizations test/data/organizations.csv --locations test/data/locations.csv
Creating organization 'Mega Corporation'... done
Creating organization 'Mega Subsidiary'... done
Creating location 'Asia Pacific'... done
Creating location 'Asia Pacific (Tokyo) Region'... done
Creating location 'Asia Pacific (Singapore) Region'... done
Creating location 'Asia Pacific (Sydney) Region'... done
Creating location 'EU (Ireland) Region'... done
Creating location 'South America (Sao Paulo) Region'... done
Creating location 'US East (Northern Virginia) Region'... done
Creating location 'US West (Northern California) Region'... done
Creating location 'US West (Oregon) Region'... done
```

# Development

## Code style

```rubocop -R <file>```

## Tests

The tests are meant to run against a live server.

