%global gem_name hammer_cli_csv
%global confdir hammer

Summary: CSV input/output command plugin for the Hammer CLI
Name: rubygem-%{gem_name}
Version: 1.0.0
Release: 5%{?dist}
Group: Development/Languages
License: GPLv3
URL: https://github.com/Katello/hammer-cli-csv
Source0: %{gem_name}-%{version}.gem

%if 0%{?rhel} == 6
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
Provides: rubygem(%{gem_name}) = %{version}

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
install -m 755 .%{gem_instdir}/config/csv.yml %{buildroot}%{_sysconfdir}/%{confdir}/cli.modules.d/csv.yml
mkdir -p %{buildroot}%{gem_dir}
cp -pa .%{gem_dir}/* \
        %{buildroot}%{gem_dir}/

%files
%dir %{gem_instdir}
%{gem_instdir}/lib
%config(noreplace) %{_sysconfdir}/%{confdir}/cli.modules.d/csv.yml
%exclude %{gem_dir}/cache/%{gem_name}-%{version}.gem
%{gem_dir}/specifications/%{gem_name}-%{version}.gemspec

%files doc
%doc %{gem_dir}/doc/%{gem_name}-%{version}
%doc %{gem_instdir}/config

%changelog
* Thu Mar 05 2015 Eric D. Helms <ericdhelms@gmail.com> 1.0.0-5
- Remove the Fedora check that evaluates to true on EL7 (ericdhelms@gmail.com)

* Thu Mar 05 2015 Eric D. Helms <ericdhelms@gmail.com> 1.0.0-4
- Remove gem_dir definition. (ericdhelms@gmail.com)

* Thu Mar 05 2015 Eric D. Helms <ericdhelms@gmail.com> 1.0.0-3
- Adding default configuration for tags. (ericdhelms@gmail.com)

* Thu Mar 05 2015 Eric D. Helms <ericdhelms@gmail.com> 1.0.0-2
- Adding basic releasers configuration for Koji. (ericdhelms@gmail.com)
- Switch to ReleaseTagger for tito (ericdhelms@gmail.com)
- Require rubygems-devel in all cases. (ericdhelms@gmail.com)

* Thu Mar 05 2015 Eric D. Helms <ericdhelms@gmail.com>
- Require rubygems-devel in all cases. (ericdhelms@gmail.com)

* Wed Mar 04 2015 Adam Price <komidore64@gmail.com> 1.0.0-1
- new package built with tito

* Wed Mar 26 2014 Mike McCune <mmccune@redhat.com> 0.0.1-1
- initial version (mmccune@redhat.com)
