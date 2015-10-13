package MetaCPAN::Walker::Policy::DistConfig;
use v5.10.0;

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
	handles  => [qw(has_release release)],
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

}

sub process_release {
	my ($self, $path, $release) = @_;

	if (!$self->has_release($release->name)) {
		$self->add_missing([ @$path ], $release);
		return 0;
	}

	my $seen = $self->_seen->{$release->name};
	$self->_seen->{$release->name} = 1;

	if (!$seen) {
		my $config = $self->release($release->name);
		my $reqs = CPAN::Meta::Requirements->new();

		$reqs->add_requirements(
			$config->build_requires($release, $self->perl, $self->core),
		);
		$reqs->add_requirements(
			$config->requires($release, $self->perl, $self->core),
		);
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
