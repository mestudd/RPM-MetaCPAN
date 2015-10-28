package RPM::MetaCPAN::DistConfig;
use v5.10.0;

use Module::CoreList;
use Scalar::Util qw(blessed);

use Moo;#XXX? ::Role;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';


has _releases => (
	is       => 'ro',
	lazy     => 1,
	init_arg => 'config',
	coerce   => sub { _coerce_releases(@_) },
	default  => sub { {} },
);

sub _coerce_releases {
	my $source = shift;

	if (ref $source eq 'HASH') {
		my %releases;
		foreach my $release (keys %$source) {
			if (ref $source->{$release} eq 'HASH') {
				$releases{$release} = RPM::MetaCPAN::DistConfig::Dist->new(
					%{ $source->{$release} },
				);
			} else {
				$releases{$release} = $source->{$release};
			}
		}

		return \%releases;
	}

	return $source;
}

sub config {
	my $self = shift;

	my %config;
	while (my ($name, $release) = (each %{ $self->_releases })) {
		my %dist;
		while (my ($key, $value) = (each %$release)) {
			$key =~ s/^_*//;
			$dist{$key} = $value;
		}
		$config{$name} = \%dist;
	}

	return \%config;
}

sub has_release {
	my ($self, $name) = @_;

	return exists $self->_releases->{$name};
}

sub release {
	my ($self, $name, $new) = @_;

	if (blessed $new && $new->isa('RPM::MetaCPAN::DistConfig::Dist')) {
		$self->_releases->{$name} = $new;
	}
	return $self->_releases->{$name};
}

package RPM::MetaCPAN::DistConfig::Dist;
use Moo;
use strictures 2;
use namespace::clean;

has archive_name => (
	is => 'rw',
);

has download_url => (
	is      => 'rw',
);

has epoch => (
	is      => 'rw',
);

has _exclude_build_requires => (
	is       => 'ro',
	init_arg => 'exclude_build_requires',
);

has _exclude_requires => (
	is       => 'ro',
	init_arg => 'exclude_requires',
);

has _extra_build_requires => (
	is       => 'ro',
	init_arg => 'extra_build_requires',
);

has _extra_requires => (
	is       => 'ro',
	init_arg => 'extra_requires',
);

has _features => (
	is       => 'ro',
	init_arg => 'features',
);

has _patches => (
	is       => 'ro',
	init_arg => 'patches',
);

has _provides => (
	is       => 'ro',
	init_arg => 'provides',
);

has _rpm_build_requires => (
	is       => 'ro',
	init_arg => 'rpm_build_requires',
);

has rpm_name => (
	is      => 'rw',
);

has _rpm_requires => (
	is       => 'ro',
	init_arg => 'rpm_requires',
);

has _with => (
	is       => 'ro',
	init_arg => 'with',
);

has _without => (
	is       => 'ro',
	init_arg => 'without',
);

sub build_requires {
	my ($self, $release, $perl, $core, $rel) = @_;

	$rel = [qw(requires recommends suggests)] if (!$rel);
	return $self->_requires(
		$release,
		$perl,
		$core,
		[qw(configure build test)],
		$rel,
		$self->_exclude_build_requires,
		$self->_extra_build_requires,
	);
}

sub exclude_build_requires {
	my $self = shift;

	return @{ $self->_exclude_build_requires // [] };
}

sub exclude_requires {
	my $self = shift;

	return @{ $self->_exclude_requires // [] };
}

sub features {
	my $self = shift;

	return @{ $self->_features // [] };
}

sub patches {
	my $self = shift;

	return @{ $self->_patches // [] };
}

sub provides {
	my $self = shift;

	return @{ $self->_provides // [] };
}

sub _requires {
	my ($self, $release, $perl, $core, $phases, $rel, $exclude, $extra) = @_;

	my $reqs = $release
		->effective_prereqs($self->_features)
		->merged_requirements($phases, $rel);

	unless ($core) {
		foreach my $module ($reqs->required_modules) {
			if (Module::CoreList::is_core($module, undef, $perl)) {
				$reqs->clear_requirement($module);
			}
		}
	}

	$reqs->clear_requirement($_)
		foreach ('perl', @$exclude);
	while (my ($module, $version) = each %$extra) {
		$reqs->add_string_requirement($module, $version);
	}

	return $reqs;
}

sub requires {
	my ($self, $release, $perl, $core, $rel) = @_;

	$rel = [qw(requires recommends suggests)] if (!$rel);
	return $self->_requires(
		$release,
		$perl,
		$core,
		[qw(runtime)],
		$rel,
		$self->_exclude_requires,
		$self->_extra_requires,
	);
}

sub rpm_build_requires {
	my $self = shift;

	return @{ $self->_rpm_build_requires // [] };
}

sub rpm_requires {
	my $self = shift;

	return @{ $self->_rpm_requires // [] };
}

1;
