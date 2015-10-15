package RPM::MetaCPAN::Spec;
use v5.10.0;

use Archive::Tar;
use File::Basename qw(basename);
use HTTP::Tiny;
use POSIX;

use Moo::Role;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';

has dist_config => (
	is       => 'ro',
	required => 1,
	handles  => [qw(has_release release)],
);

has _http => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_http',
);

has perl => (
	is      => 'ro',
	default => '5.22.0',
);

has source_dir => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_source_dir',
);

has spec_dir => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_spec_dir',
);

has _topdir => (
	is      => 'rw',
	lazy    => 1,
	builder => '_build_topdir',
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

	my $rpm_name;
	if ($self->has_release($name)) {
		$rpm_name = $self->release($name)->rpm_name;
	}
	$rpm_name //= 'perl-' . $name;

	return $rpm_name;
}

sub spec {
	my ($self, $name) = @_;

	return sprintf '%s/%s.spec', $self->spec_dir, $self->name($name);
}

sub _build_http {
	HTTP::Tiny->new(agent => "RPM::MetaCPAN/$VERSION");
}

sub _build_source_dir {
	return shift->_topdir . '/SOURCES';
}

sub _build_spec_dir {
	return shift->_topdir . '/SPECS';
}

sub _build_topdir {
	my $topdir = `/usr/bin/rpm --eval '%_topdir'`;
	chomp $topdir;

	return $topdir || './';
}

sub download_release {
	my ($self, $release) = @_;

	my $url = $release->download_url;
	my $local = $self->source($release);
	my $response = $self->_http->mirror($url, $local);
	die "Could not download $url: $response->{status} $response->{reason}\n"
		if (!$response->{success});
}

sub generate_spec {
	my ($self, $release) = @_;

	my $name = $release->name;
	my $config = $self->release($name);
	my @files = $self->read_source($release);

	# FIXME need to calculate these
	my $noarch = grep /[.](?:[ch]|xs|inl)$/i, @files; # grep source tarball for .c, .h, .xs, .inl files
	my $scripts = grep /^script/, @files; # meta->  script_files or scripts
	my $uses_autoinstall = 0; # not in either cpanspec 1.78 nor rpmcpan
	my $uses_buildpl = grep /^Build\.PL$/, @files; # grep source tarball for Build.PL (near top of hierarchy)
	my $date = strftime("%a %b %d %Y", localtime);
	my $packager = `rpm --eval '%packager'`;
	chomp $packager;

	my $rpm_name = $self->name($release->name);
	my $epoch = $config->epoch;
	my $version = $release->version;
	$version =~ s/^v//; # RPM version must not have the v.
	my $license = $self->license_for($release);
	my $summary = $release->abstract;
	my $description = $release->description || $release->abstract;
	my @patches = $config->patches;
	my $patches = join("\n",
		(map { "Patch$_:         $patches[$_]" } 0..$#patches));
	my $patches_apply = join("\n", map { "\n%patch$_ -p1" } 0..$#patches );
	my $perlv = $self->perl;

	my $build_reqs = $config->build_requires($release);
	my $reqs = $config->requires($release);

	my $build_requires = join("\n",
		map "BuildRequires:  \%{?scl_prefix}perl($_)",
			sort $build_reqs->required_modules);
	my $requires = join("\n",
		map "Requires:       %{?scl_prefix}perl($_)",
			sort $reqs->required_modules);
	my $provides = join("\n",
		map "Provides:       %{?scl_prefix}perl($_)",
			$config->provides);

	my $rpm48_filters = join('', map
		qq{\n%filter_from_requires /^%{?scl_prefix}perl($_)/d},
		$config->exclude_requires);
	my $rpm49_filters = join('', map
		qq{\n%global __requires_exclude %{?__requires_exclude|%__requires_exclude|}^%{?scl_prefix}perl\\\\($_\\\\)},
		$config->exclude_requires);

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
}. ($epoch ? "Epoch:          $epoch" : '') . qq{
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

sub read_source {
	my ($self, $release) = @_;

	my $dir = basename($release->download_url);
	$dir =~ s/\.(?:tgz|tbz|tar\.gz|tar\.bz2)$//;
	my $version = $release->version;
	my @files;
	my $bogus = 0;
	for my $file (Archive::Tar->list_archive($self->source($release))) {
		if ($file !~ /^(?:.\/)?$dir(?:\/|$)/) {
			warn "BOGUS PATH DETECTED: $file\n";
			$bogus++;
			next;
		}

		$file =~ s|^(?:.\/)?$dir/?||;
		next if (!$file);

		push @files, $file;
	}
	if ($bogus) {
		warn "Expecting $dir";
#		die "$name has $bogus bogus path elements\n";
	}

	return @files;
}

sub source {
	my ($self, $release) = @_;

	return $self->source_dir .'/'. basename($release->download_url);
}

1;
