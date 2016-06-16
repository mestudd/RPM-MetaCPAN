package MetaCPAN::Walker::Local::RPMSpec;
use v5.10.0;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.0.3';

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
		if (open(my $fh, '<:encoding(UTF-8)', $self->spec($name))) {
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
__END__

=encoding utf-8

=head1 NAME

MetaCPAN::Walker::Local::RPMSpec - Check local release via RPM spec file

=head1 SYNOPSIS

  use MetaCPAN::Walker;
  use MetaCPAN::Walker::Local::RPMSpec;
  
  my $walker = MetaCPAN::Walker->new(
      local => MetaCPAN::Walker::Local::RPMSpec->new(),
  );
  
  $walker->walk_from_modules(qw(namespace::clean Test::Most));

=head1 DESCRIPTION

MetaCPAN::Walker::Local::RPMSpec implements the L<MetaCPAN::Walker::Local>
role by reading the version from an RPM spec file. If the spec is found but
no version can be read, the version is returned as C<v0>.

The class composes the L<RPM::MetaCPAN::Spec> role, which provides mechanisms
for configuring.

=head1 Attributes

=head2 versions

Keeps hash of all seen release versions.

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Recognia Inc.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
