package RPM::MetaCPAN::Spec;
use v5.10.0;

use Moo::Role;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';

has dist_config => (
	is      => 'ro',
	lazy    => 1,
	default => sub { {} },
);

has perl => (
	is => 'ro',
	default => '5.22.0',
);

has spec_dir => (
	is      => 'ro',
	default => '.',
);

my %label_for = (
    # The following list of license strings are valid:
    agpl_3          => 'Affero General Public License 3.0',
    apache_1_1      => 'Apache Software License 1.1',
    apache_2_0      => 'Apache Software License 2.0',
    artistic_1      => 'Artistic',
    artistic_2      => 'Artistic 2.0',
    bsd             => 'BSD License (three-clause)',
    freebsd         => 'FreeBSD License (two-clause)',
    gfdl_1_2        => 'GNU Free Documentation License 1.2',
    gfdl_1_3        => 'GNU Free Documentation License 1.3',
    gpl_1           => 'GPLv1',
    gpl_2           => 'GPLv2',
    gpl_3           => 'GPLv3',
    lgpl_2_1        => 'LGPLv2',
    lgpl_3_0        => 'LGPLv3',
    mit             => 'MIT',
    mozilla_1_0     => 'MPLv1.0',
    mozilla_1_1     => 'MPLv1.1',
    openssl         => 'OpenSSL',
    perl_5          => 'GPL+ or Artistic',
    qpl_1_0         => 'QPL',
    ssleay          => 'Original SSLeay License',
    sun             => 'SISSL',
    zlib            => 'zlib',

    # The following license strings are also valid and indicate other
    # licensing not described above:
    open_source     => 'OSI-Approved',
    restricted      => 'Non-distributable',
    unrestricted    => 'Distributable',
#   unknown         => 'CHECK(Distributable)', # XXX Warn?
);

sub license_for {
    my ($self, $release) = @_;

	my @licenses = $release->licenses;

    return $label_for{perl_5}
        unless @licenses;
    return join ' or ' => map {
        $label_for{$_} || $label_for{perl_5}
    } @licenses;
}

sub name {
	my ($self, $name) = @_;

	my $rpm_name = 'perl-' . $name;
	if (exists $self->dist_config->{$name}->{rpm_name}) {
		$rpm_name = $self->dist_config->{$name}->{rpm_name};
	}

	return $rpm_name;
}

sub spec {
	my ($self, $name) = @_;

	return sprintf '%s/%s.spec', $self->spec_dir, $self->name($name);
}

sub _filter_core {
	my ($self, $reqs) = @_;

#	unless ($self->core) {
		foreach my $module ($reqs->required_modules) {
			if (Module::CoreList::is_core($module, undef, $self->perl)) {
				$reqs->clear_requirement($module);
			}
		}
#	}
}

sub generate_spec {
	my ($self, $release) = @_;

	my $config = $self->dist_config->{$release->name};

	# FIXME need to calculate these
	my $noarch = 1;
	my $scripts = 1;
	my $uses_autoinstall = 1;
	my $uses_buildpl = 0;
	my $date = 'Fri Oct 09 2015';
	my $packager = 'Malcolm Studd <mstudd@recognia.com>';

	my $name = $release->name;
	my $rpm_name = $self->name($release->name);
	my $version = $release->version;
	my $license = $self->license_for($release);
	my $summary = $release->abstract;
	my $description = $release->description || $release->abstract;
	my @patches = @{ $config->{patches} // [] };
	my $patches = join("\n",
		(map { "Patch$_:         $patches[$_]" } 0..$#patches));
	my $patches_apply = join("\n", map { "\n%patch$_ -p1" } 0..$#patches );
	my $perlv = $self->perl;

	# TODO: want to refactor this into shared location
	my $features = $config->{features} // [];
	my $prereqs = $release->effective_prereqs($features);

	my @phases = qw(configure build test);
	my @relationships = qw(requires recommends suggests);

	my $build_reqs = $prereqs->merged_requirements(\@phases, \@relationships);
	$build_reqs->clear_requirement($_)
		foreach ('perl', @{ $config->{exclude_build_requires} // [] });
	$self->_filter_core($build_reqs);

	my $reqs = $prereqs->merged_requirements(['runtime'], \@relationships);
	$reqs->clear_requirement($_)
		foreach ('perl', @{ $config->{exclude_requires} // [] });
	$self->_filter_core($reqs);

	my $build_requires = join("\n", map
		"BuildRequires:  $_", sort $build_reqs->required_modules);
	my $requires = join("\n", map
		"Requires:       $_", sort $reqs->required_modules);
	my $provides = join("\n", map
		"Provides:       $_", @{ $config->{provides} // [] });

	my $rpm48_filters = join('', map
		qq{\n%filter_from_requires /^%{?scl_prefix}perl($_)/d},
		@{ $config->{exclude_requires} // [] });
	my $rpm49_filters = join('', map
		qq{\n%global __requires_exclude %{?__requires_exclude|%__requires_exclude|}^%{?scl_prefix}perl\\\\($_\\\\)},
		@{ $config->{exclude_requires} // [] });

	my $autoinstall_nodeps = '';
	if ($uses_autoinstall) {
		$autoinstall_nodeps = qq{export PERL_AUTOINSTALL="--skipdeps"\n};
	}
	my $configure = '';
	my $install = '';
	my $remove = '';
	my $check = '';
	if ($uses_buildpl) {
		$configure = 'perl Build.PL --installdirs=vendor';
		$configure .= ' --optimize="%{optflags}"' unless ($noarch);
		$install = './Build install --destdir=%{buildroot} --create_packlist=0';
		$check = './Build test';
	} else {
		$configure = 'perl Makefile.PL INSTALLDIRS=vendor';
		$configure .= ' OPTIMIZE="%{optflags}"' unless ($noarch);
		$install = 'make pure_install DESTDIR=%{buildroot}';
		$remove .= "\nfind %{buildroot} -type f -name .packlist -exec rm -f {} \\;";
		$check = 'make test';
	}
	unless ($noarch) {
		$remove .= "\nfind %{buildroot} -type f -name '*.bs' -exec rm -f {} \\;";
	}

	my $files = '';
	if ($scripts) {
		$files .= "\%{_bindir}/*\n\%{_mandir}/man1/*\n";
	}
	$files .= "%{perl_vendorlib}/*\n";
	unless ($noarch) {
		$files .= "%{perl_vendorarch}/*\n";
	}


	my $spec = qq{%{?scl:%scl_package $rpm_name}
%{!?scl:%global pkg_name %{name}}

Name:           %{?scl_prefix}$rpm_name
Version:        $version
Release:        1%{dist}
}. ($config->{epoch} ? "Epoch:          $config->{epoch}" : '') . qq{
Summary:        $summary
License:        $license
Group:          Development/Libraries
URL:            https://metacpan.org/release/$name
Source0:        $name-%{version}.tar.gz
$patches
BuildRoot:      %{_tmppath}/%{pkg_name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:  %{?scl_prefix}perl >= $perlv
$build_requires
$requires
Requires:       %{?scl_prefix}perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo \$version))

$provides


# Filter unwanted dependencies
# RPM 4.8 style
%{?filter_setup:$rpm48_filters
%?perl_default_filter
}
# RPM 4.9 style
%{?perl_default_filter}$rpm49_filters

%description
$description

%prep
%setup -q -n $name->%{version}
$patches_apply

%build
%{?scl:scl enable %{scl} '}$configure && make %{?_smp_mflags}%{?scl:'}

%install
%{?scl:scl enable %{scl} '}$install%{?scl:'}
$remove
find %{buildroot} -depth -type d -exec rmdir {} 2>/dev/null \\;
%{_fixperms} %{buildroot}

%check
%{?scl:scl enable %{scl} '}$check%{?scl:'}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc \@doc FIXME
$files%{_mandir}/man/3/*

%changelog
* $date $packager $version-1
- Specfile autogenerated by RPM::MetaCPAN $VERSION.
}
;
}

1;
