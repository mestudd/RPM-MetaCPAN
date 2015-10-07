package MetaCPAN::Walker::Policy::DistConfig;
use v5.10.0;

use Module::CoreList;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';

with qw(MetaCPAN::Walker::Policy);

has conflicts => (
	is => 'ro',
	default => sub { {}; },
);

has core  => (
	is      => 'ro',
	default => 0,
);

has dist_config => (
	is       => 'ro',
	required => 1,
);

has _in_conflict => (
	is      => 'rw',
	default => 0,
);

has missing => (
	is => 'ro',
	default => sub { {}; },
);

# Configure the version of perl targetted
has perl => (
	is      => 'ro',
	default => '5.22.0',
);

has seen  => (
	is      => 'ro',
	default => 0,
);

has _seen => (
	is      => 'ro',
	lazy    => 1,
	default => sub { {} },
);


sub _add_conflict {
	my ($self, $release, $path) = @_;

	# //=?
	my $name = $release->name;
	if (!exists $self->conflicts->{$name}) {
		$self->conflicts->{$name} = {
			release => $release,
			paths   => [],
		}
	}
	push @{$self->conflicts->{$name}->{paths}}, $path;
}

# override to get interactive behaviour, etc
sub add_missing {
	my ($self, $path, $release) = @_;

	warn "Missing release: ".$release->name
		if (!exists $self->missing->{$release->name});
	$self->missing->{$release->name} = $release;
}

sub process_dependency {
	my ($self, $path, $release, $dependency) = @_;

	return 0 if ($dependency->{module} eq 'perl');

	# Ignore core & dual-life modules unless so configured
	unless ($self->core) {
		return 0 if (Module::CoreList::is_core(
				$dependency->{module},
				undef,
				$self->perl,
		));
	}

	# Don't follow 'develop' requirements TODO: just follow everything?
	return 0 if ($dependency->{phase} eq 'develop');

	# Keep track of conflicting releases
	if ($dependency->{relationship} eq 'conflicts') {
		$self->_in_conflict(1);
	}

	# Top-level don't have parent release
	if ($release) {
		# Skip configured exclusions
		my $name = $release->name;
		my $config = $self->dist_config->{$name};
		return 0 if ($dependency->{phase} eq 'runtime'
				&& grep(/$name/, @{ $config->{exclude_requires} // [] }));
		return 0 if ($dependency->{phase} ne 'runtime'
				&& grep(/$name/, @{ $config->{exclude_build_requires} // [] }));
	}

	# Generally follow requirements; process_release checks against config
	return 1;
}

sub process_release {
	my ($self, $path, $release) = @_;

	# Keep track of conflicting releases
	if ($self->_in_conflict) {
		$self->_add_conflict($release, [ @$path ]);
		$self->_in_conflict(0);
		return 0;
	}


	if (!exists $self->dist_config->{$release->name}) {
		$self->add_missing([ @$path ], $release);
		return 0;
	}

	my $seen = $self->_seen->{$release->name};
	$self->_seen->{$release->name} = 1;

	return $self->seen || !$seen;
}

1;
