%global gemname hammer_cli_csv
%global confdir hammer

%if 0%{?rhel} < 7
%global gem_dir /usr/lib/ruby/gems/1.8
%endif

%global geminstdir %{gem_dir}/gems/%{gemname}-%{version}

Summary: CSV input/output command plugin for the Hammer CLI
Name: rubygem-%{gemname}
Version: 0.0.6
Release: 1%{?dist}
Group: Development/Languages
License: GPLv3
URL: https://github.com/Katello/hammer-cli-csv
Source0: rubygem-%{gemname}-%{version}.tar.gz
Source1: csv.yml

%if !( 0%{?rhel} > 6 || 0%{?fedora} > 18 )
Requires: ruby(abi)
%endif
Requires: ruby(rubygems)
Requires: rubygem(hammer_cli)
Requires: rubygem(foreman_api)
Requires: rubygem(katello_api)
BuildRequires: ruby(rubygems)
%if 0%{?fedora} || 0%{?rhel} > 6
BuildRequires: rubygems-devel
%endif
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
%setup -q -n rubygem-%{gemname}-%{version}
%{?scl:scl enable %{scl} "}
gem build %{gemname}.gemspec
%{?scl:"}
mkdir -p .%{gem_dir}
gem install --local --install-dir .%{gem_dir} \
            --force %{gemname}-%{version}.gem

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
* Tue Dec 09 2014 Jason Montleon <jmontleo@redhat.com> 0.0.6-1
- set up hammer-cli-csv to use distribution tagger (jmontleo@redhat.com)
- Update to 0.0.6
* Tue Jul 22 2014 Jason Montleon <jmontleo@redhat.com> 0.0.2-1
- fix version in rpm spec (jmontleo@redhat.com)

* Tue Jul 22 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-11
- Merge remote-tracking branch 'upstream/master' into SATELLITE-6.0.4
  (jmontleo@redhat.com)
- First pass at documentation (thomasmckay@redhat.com)
- version-0.2.2 - updated to run on ruby 1.8.7 (thomasmckay@redhat.com)
- corrected syntax for ruby-1.8.7, gitignore .gem file (thomasmckay@redhat.com)
- preparing gemspec for rubygems push (komidore64@gmail.com)
- beginning to add provisioning templates (thomasmckay@redhat.com)

* Tue Jul 15 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-10
- Merge remote-tracking branch 'upstream/master' into SATELLITE-6.0.4
  (jmontleo@redhat.com)
- rubocop - removed all offences (thomasmckay@redhat.com)
- content-views and content-view-filters and myriad more
  (thomasmckay@redhat.com)

* Wed Jul 09 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-9
- myriad changes... all for the better! (thomasmckay@redhat.com)
- corrected threading (thomasmckay@redhat.com)
- updates to csv (thomasmckay@redhat.com)

* Thu May 22 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-8
- Merge remote-tracking branch 'upstream/master' (jmontleo@redhat.com)
- a lot of fixes and updates across many resources to match katello updates
  (thomasmckay@redhat.com)
- update releasers (jmontleo@redhat.com)
- rubocop - fixes (thomasmckay@redhat.com)
- removed commented lines from roles.csv (thomasmckay@redhat.com)
- + updated 'hammer csv import' command + fixed import/export roles
  (thomasmckay@redhat.com)

* Sat May 17 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-7
- Merge remote-tracking branch 'upstream/master' (jmontleo@redhat.com)
- export smart proxies (thomasmckay@redhat.com)

* Tue May 06 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-6
- Merge remote-tracking branch 'upstream/master' (jmontleo@redhat.com)
- fixing limit on activation key (thomasmckay@redhat.com)

* Mon May 05 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-5
- correct macros to work with RHEL 7 (jmontleo@redhat.com)

* Wed Apr 30 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-4
- Merge remote-tracking branch 'upstream/master' (jmontleo@redhat.com)
- removed hammer-it (thomasmckay@redhat.com)
- Rehomed command-classes so that Clamp would work correctly
  (ggainey@redhat.com)

* Thu Apr 17 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-3
- Merge remote-tracking branch 'upstream/master' (jmontleo@redhat.com)
- csv-scope - lots of cleanup (thomasmckay@redhat.com)
- fixes #4926 - systems test and rubocop cleanup (thomasmckay@redhat.com)

* Fri Mar 28 2014 Jason Montleon <jmontleo@redhat.com> 0.0.1-2
- new package built with tito

* Wed Mar 26 2014 Mike McCune <mmccune@redhat.com> 0.0.1-1
- initial version (mmccune@redhat.com)

