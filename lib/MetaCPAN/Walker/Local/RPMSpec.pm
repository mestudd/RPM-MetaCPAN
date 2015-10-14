package MetaCPAN::Walker::Local::RPMSpec;
use v5.10.0;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';

with qw(MetaCPAN::Walker::Local RPM::MetaCPAN::Spec);

has versions => (
	is      => 'ro',
	lazy    => 1,
	default => sub { {} },
);

sub local_version {
	my ($self, $release) = @_;

	my $name = $release->distribution;
	if (!exists $self->versions->{$name}) {
		if (open(my $fh, '<', $self->spec($name))) {
			my $prefix = $release->version =~ /^v/ ? 'v' : '';
			while (<$fh>) {
				if (/^version:\W*(\S+)/i) {
					$self->versions->{$name} = $prefix.$1;
					last;
				}
			}
		} else {
			$self->versions->{$name} = 'v0';
		}
	}

	return $self->versions->{$name};
}

1;
