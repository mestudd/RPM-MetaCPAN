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

	# download source file
	$self->download_release($release);

	if ($release->update_available) {
		warn "$name: Can't update spec files yet";
		return;
	}
	if ($release->version_local) {
		say "$name: At latest version";
		return;
	}
	# Write spec file
	if (open(my $fh, '>', $self->spec($name))) {
		print $fh $self->generate_spec($release);
		say sprintf '%s: Wrote %s', $name, $self->spec($name);
	} else {
		die "Could not open spec file for writing: $!\n";
	}
}

# Do nothing?
sub missing_module {}

# Do nothing?
sub circular_dependency {}

1;
