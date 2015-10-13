package MetaCPAN::Walker::Policy::DistConfig;
use v5.10.0;

use Module::CoreList;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';

with qw(MetaCPAN::Walker::Policy);

=cut
has conflicts => (
	is => 'ro',
	default => sub { {}; },
);
=cut

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

=cut

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
=cut

# override to get interactive behaviour, etc
sub add_missing {
	my ($self, $path, $release) = @_;

	warn "Missing release: ".$release->name
		if (!exists $self->missing->{$release->name});
	$self->missing->{$release->name} = $release;
}

sub _filter_core {
	my ($self, $reqs) = @_;

	unless ($self->core) {
		foreach my $module ($reqs->required_modules) {
			if (Module::CoreList::is_core($module, undef, $self->perl)) {
				$reqs->clear_requirement($module);
			}
		}
	}
}

sub process_release {
	my ($self, $path, $release) = @_;

	if (!exists $self->dist_config->{$release->name}) {
		$self->add_missing([ @$path ], $release);
		return 0;
	}

	my $seen = $self->_seen->{$release->name};
	$self->_seen->{$release->name} = 1;

	if (!$seen) {
		# TODO: want to refactor this into shared location
		my $config = $self->dist_config->{$release->name};
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

		$reqs->add_requirements($build_reqs);

		$release->requirements($reqs);
	}

	return $self->seen || !$seen;













=cut
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
=cut
}

1;
