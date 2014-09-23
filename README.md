# hammer-cli-csv ![Travis # Status](https://travis-ci.org/Katello/hammer-cli-csv.svg?branch=master)

## Introduction

[Hammer](https://github.com/theforeman/hammer-cli/blob/master/README.md) is a command line interface (CLI) framework which provides a core to which plugins may be added. This plugin, hammer-cli-csv, adds commands to interact with the following products: [Foreman](https://theforeman.org) standalone, [Foreman](https://theforeman.org) with [Katello](http://www.katello.org/) (Foretello), Red Hat's Satellite-6, and Red Hat's Subscription Asset Manager (SAM).

The purpose of this plugin's commands are to allow a convenient mechanism to both export to and import from CSV files (comma separated values). Each of the server's supported resource types, such as organizations and users, are handled.

Some possible uses include

* Import demo or development data easily and consistently
* Export another server's data and then import into elsewhere for testing and debug
* Export for backup and auditing
* Export from SAM-1.3 to import into Satellite-6

The following sections will cover installation, usage, and examples. All of the resource types are follow in the order which generally is required for dependency resolution (eg. roles must exist to assign to users so the role section comes first).

## Installation

## Usage

## Examples

## Organizations

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=organizations&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/organizations_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/organizations.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the organization to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Label | Unique organization label | x |   | x | x |   |
| Description | Organization description |   | x | x | x |   |

## Locations

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=locations&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/locations_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/locations.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the location to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Parent Location | Parent location |   | x | x | x |   |

## Puppet Environments

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=puppet-environments&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/puppet_environments_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/puppet-environments.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the operating systems to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Family | Operating system family |   | x | x | x |   |

## Domains

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=domains&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/domains_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/domains.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the architectures to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Operating Systems | Comma separated list of operating system names |   | x | x | x |   |

## Partition Tables

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=partition-tables&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/partition_tables_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/partition-tables.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the lifecycle environments to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Prior Environment | Previous organization name in path |   | x | x | x |   |
| Description | Lifecycle environment description |   | x | x | x |   |

## Host Collections

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=host-collections&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/host_collections_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/host-collections.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the host collections to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| Organization | Organization name |   | x | x | x |   |
| Limit | Usage limit |   | x | x | x |   |
| Description | Host collection description |   | x | x | x |   |

## Provisioning Templates

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=provisionings&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/provisionings_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/provisionings.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the provisioning templates to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |

## Subscriptions

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=subscriptions&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/subscriptions_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/subscriptions.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=content-hosts&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/content_hosts_test.rb)
* Sample data
  * [Mega Corporation](https://github.com/Katello/hammer-cli-csv/blob/master/test/data/content-hosts.csv)
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.6, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
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
* Supported products and version
  * Foreman-1.5, Foreman-nightly
  * Foreman-nightly w/ Katello-nightly
  * Satellite-6.0.3
  * SAM-1.3, SAM-1.4

**CSV Columns**

*Note: % column indicates Count substituion*

| Column Title | Column Description | % | Foreman | Foretello | Satellite | SAM |
| :----------- | :----------------- | :-: | :-: | :-: | :-: | :-: |
| Name         | Name of the users to update or create | x | x | x | x |   |
| Count | Number of times to iterate this CSV row, incrementing value for substitution |   | x | x | x |   |
| First Name | First name of user |   | x | x | x |   |
| Last Name | Last name of user |   | x | x | x |   |
| email | Email address |   | x | x | x |   |
| Organizations | Comma separated list of organizations |   | x | x | x |   |
| Locations | Comma separated list of locations |   | x | x | x |   |
| Roles | Comma separated list of role names for user |   | x | x | x |   |

## Import

**Overview**
* [Open Issues](https://github.com/Katello/hammer-cli-csv/issues?labels=users&state=open)
* [Tests](https://github.com/Katello/hammer-cli-csv/blob/master/test/users_test.rb)

**Examples**

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

# Development

## Code style

rubocop -R <file>

## Tests

The tests are meant to run against a live server.

