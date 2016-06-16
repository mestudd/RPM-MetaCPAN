package MetaCPAN::Walker::Action::WriteSpec;
use v5.10.0;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.0.1';

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

has wait_spec => (
	is      => 'ro',
	default => 0,
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

	my $wrote_spec = 0;
	if ($release->update_requested) {
		warn "$name: Can't update spec files yet";

	} elsif ($release->update_available) {
		warn "$name: Update available";

	} elsif ($release->version_local) {
		say "$name: At latest version";

	} elsif (open(my $fh, '>:encoding(UTF-8)', $self->spec($name))) {
		# Write spec file
		say sprintf '%s: Writing %s', $name, $self->spec($name);
		print $fh $self->generate_spec($release);
		close($fh);
		$wrote_spec = 1;

	} else {
		die "Could not open spec file for writing: $!\n";
	}

	if ($wrote_spec && $self->wait_spec) {
		print "Waiting to continue ";
		my $enter = <STDIN>;
	}
}

# Do nothing?
sub missing_module {}

# Do nothing?
sub circular_dependency {}

1;
__END__

=encoding utf-8

=head1 NAME

MetaCPAN::Walker::Action::WriteSpec - Write rpm spec file

=head1 SYNOPSIS

  use MetaCPAN::Walker;
  use MetaCPAN::Walker::Action::WriteSpec;
  
  my $walker = MetaCPAN::Walker->new(
      action => MetaCPAN::Walker::Action::WriteSpec->new(),
  );
  
  $walker->walk_from_modules(qw(namespace::clean Test::Most));

=head1 DESCRIPTION

MetaCPAN::Walker::Action::WriteSpec writes an RPM spec file in the
C<end_release> method. It keeps track of the order required to build
the RPMs. Optionally, it will wait after writing each file; this allows
you to test/build the spec before continuing.

=head1 Attributes

=head2 build_order

Contains an order to build the RPMs without dependency errors. essentially
a depth-first traversal of the dependency tree.

=head2 wait_spec

Set true to wait for input after each written spec file. Default is false

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Recognia Inc.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
