%global gemname hammer_cli_csv
%global confdir hammer

%if 0%{?rhel} < 7
%global gem_dir /usr/lib/ruby/gems/1.8
%endif

%global geminstdir %{gem_dir}/gems/%{gemname}-%{gemversion}
%global gemversion 0.0.6

Summary: CSV input/output command plugin for the Hammer CLI
Name: rubygem-%{gemname}
Version: 0.0.6.2
Release: 1%{?dist}
Group: Development/Languages
License: GPLv3
URL: https://github.com/Katello/hammer-cli-csv
Source0: %{gemname}-%{gemversion}.gem
Source1: csv.yml

%if !( 0%{?rhel} > 6 || 0%{?fedora} > 18 )
Requires: ruby(abi)
%endif
Requires: ruby(rubygems)
Requires: rubygem(hammer_cli_katello)
BuildRequires: ruby(rubygems)
%if 0%{?fedora} || 0%{?rhel} > 6
BuildRequires: rubygems-devel
%endif
BuildRequires: ruby
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{gemversion}

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
%setup -n %{gemname}-%{gemversion} -T -c
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
%exclude %{gem_dir}/cache/%{gemname}-%{gemversion}.gem
%{gem_dir}/specifications/%{gemname}-%{gemversion}.gemspec

%files doc
%doc %{gem_dir}/doc/%{gemname}-%{gemversion}

%changelog
* Wed Mar 26 2014 Mike McCune <mmccune@redhat.com> 0.0.1-1
- initial version (mmccune@redhat.com)
