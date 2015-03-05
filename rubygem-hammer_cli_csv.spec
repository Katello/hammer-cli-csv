%global gemname hammer_cli_csv
%global confdir hammer

%if 0%{?rhel}
%global gem_dir /usr/lib/ruby/gems/1.8
%endif

%global geminstdir %{gem_dir}/gems/%{gemname}-%{version}

Summary: CSV input/output command plugin for the Hammer CLI
Name: rubygem-%{gemname}
Version: 1.0.0
Release: 1%{?dist}
Group: Development/Languages
License: GPLv3
URL: https://github.com/Katello/hammer-cli-csv
Source0: %{gemname}-%{version}.gem
Source1: csv.yml

%if 0%{?rhel} == 6 || 0%{?fedora} < 19
Requires: ruby(abi)
%else
Requires: ruby(release)
%endif
Requires: ruby(rubygems)
Requires: rubygem(hammer_cli_katello)
BuildRequires: ruby(rubygems)
BuildRequires: rubygems-devel
BuildRequires: ruby
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
CSV input/output command plugin for the Hammer CLI.

%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires: %{name} = %{version}-%{release}
BuildArch: noarch

%description doc
Documentation for %{name}

%prep
%setup -q -c -T
mkdir -p .%{gem_dir}
gem install --local --install-dir .%{gem_dir} \
            --force %{SOURCE0}

%install
mkdir -p %{buildroot}%{_sysconfdir}/%{confdir}/cli.modules.d
install -m 755 %{SOURCE1} %{buildroot}%{_sysconfdir}/%{confdir}/cli.modules.d/csv.yml
mkdir -p %{buildroot}%{gem_dir}
cp -pa .%{gem_dir}/* \
        %{buildroot}%{gem_dir}/

%files
%dir %{geminstdir}
%{geminstdir}/lib
%config(noreplace) %{_sysconfdir}/%{confdir}/cli.modules.d/csv.yml
%exclude %{gem_dir}/cache/%{gemname}-%{version}.gem
%{gem_dir}/specifications/%{gemname}-%{version}.gemspec

%files doc
%doc %{gem_dir}/doc/%{gemname}-%{version}

%changelog
* Wed Mar 04 2015 Adam Price <komidore64@gmail.com> 1.0.0-1
- new package built with tito

* Wed Mar 26 2014 Mike McCune <mmccune@redhat.com> 0.0.1-1
- initial version (mmccune@redhat.com)
