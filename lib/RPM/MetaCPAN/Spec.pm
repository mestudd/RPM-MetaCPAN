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

has spec_dir => (
	is      => 'ro',
	default => '.',
);

sub spec {
	my ($self, $name) = @_;

	my $rpm_name = 'perl-' . $name;
	if (exists $self->dist_config->{$name}->{rpm_name}) {
		$rpm_name = $self->dist_config->{$name}->{rpm_name};
	}

	return sprintf '%s/%s.spec', $self->spec_dir, $rpm_name;
}

1;
