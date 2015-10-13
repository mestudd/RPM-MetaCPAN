package RPM::MetaCPAN::DistConfig;
use v5.10.0;

use Module::CoreList;

use Moo;#XXX? ::Role;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';


has config => (
	is       => 'ro',
	required => 1,
);

has _releases => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_releases',
);

sub _build_releases {
	my $self = shift;

	my %releases;
	foreach my $release (sort keys %{ $self->config }) {
		$releases{$release} = RPM::MetaCPAN::DistConfig::Dist->new(
			%{ $self->config->{$release} },
		);
	}

	return \%releases;
}

sub has_release {
	my ($self, $name) = @_;

	return exists $self->_releases->{$name};
}

sub release {
	my ($self, $name) = @_;

	return $self->_releases->{$name};
}

package RPM::MetaCPAN::DistConfig::Dist;
use Moo;
use strictures 2;
use namespace::clean;

has epoch => (
	is      => 'rw',
);

has _exclude_build_requires => (
	is      => 'ro',
	init_arg => 'exclude_build_requires',
	default => sub { []; },
);

has _exclude_requires => (
	is      => 'ro',
	init_arg => 'exclude_requires',
	default => sub { []; },
);

has _extra_build_requires => (
	is      => 'ro',
	init_arg => 'extra_build_requires',
	default => sub { {}; },
);

has _extra_requires => (
	is      => 'ro',
	init_arg => 'extra_requires',
	default => sub { {}; },
);

has _features => (
	is      => 'ro',
	init_arg => 'features',
	default => sub { []; },
);

has _patches => (
	is      => 'ro',
	init_arg => 'patches',
	default => sub { []; },
);

has _provides => (
	is      => 'ro',
	init_arg => 'provides',
	default => sub { []; },
);

has _rpm_build_requires => (
	is      => 'ro',
	init_arg => 'rpm_build_requires',
	default => sub { []; },
);

has rpm_name => (
	is      => 'rw',
);

has _rpm_requires => (
	is      => 'ro',
	init_arg => 'rpm_requires',
	default => sub { []; },
);

sub build_requires {
	my ($self, $release, $perl, $core) = @_;

	return $self->_requires(
		$release,
		$perl,
		$core,
		[qw(configure build test)],
		[qw(requires recommends suggests)],
		$self->_exclude_build_requires,
		$self->_extra_build_requires,
	);
}

sub exclude_build_requires {
	my $self = shift;

	return @{ $self->_exclude_build_requires };
}

sub exclude_requires {
	my $self = shift;

	return @{ $self->_exclude_requires };
}

sub features {
	my $self = shift;

	return @{ $self->_features };
}

sub patches {
	my $self = shift;

	return @{ $self->_patches };
}

sub provides {
	my $self = shift;

	return @{ $self->_provides };
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
	my ($self, $release, $perl, $core) = @_;

	return $self->_requires(
		$release,
		$perl,
		$core,
		[qw(runtime)],
		[qw(requires recommends suggests)],
		$self->_exclude_requires,
		$self->_extra_requires,
	);
}

1;
