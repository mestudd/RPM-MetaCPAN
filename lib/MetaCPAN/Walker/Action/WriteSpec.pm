package MetaCPAN::Walker::Action::WriteSpec;
use v5.10.0;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';

with qw(MetaCPAN::Walker::Action RPM::MetaCPAN::Spec);

has build_order => (
	is      => 'ro',
	lazy    => 1,
	default => sub { [] },
);

has _seen => (
	is      => 'ro',
	lazy    => 1,
	default => sub { {} },
);


# Nothing to do at begin
sub begin_release {}

sub end_release {
	my ($self, $path, $release) = @_;
	my $name = $release->name;

	return if ($self->_seen->{$name});

	# Mark as seen
	push @{ $self->build_order }, $name;
	$self->_seen->{$name} = 1;

	if ($release->update_available) {
		warn "$name: Can't update spec files yet";
		return;
	}
	if ($release->version_local) {
		say "$name: At latest version";
		return;
	}
	# Write spec file
	say sprintf '%s: Write %s file here', $name, $self->spec($name);
}

# Do nothing?
sub missing_module {}

# Do nothing?
sub circular_dependency {}

1;
