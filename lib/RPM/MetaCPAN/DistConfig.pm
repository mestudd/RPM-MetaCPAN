package RPM::MetaCPAN::DistConfig;
use v5.10.0;

use RPM::MetaCPAN::DistConfig::Dist;
use Scalar::Util qw(blessed);

use Moo;#XXX? ::Role;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';


has _releases => (
	is       => 'ro',
	lazy     => 1,
	init_arg => 'config',
	coerce   => sub { _coerce_releases(@_) },
	default  => sub { {} },
);

sub _coerce_releases {
	my $source = shift;

	if (ref $source eq 'HASH') {
		my %releases;
		foreach my $release (keys %$source) {
			if (ref $source->{$release} eq 'HASH') {
				$releases{$release} = RPM::MetaCPAN::DistConfig::Dist->new(
					%{ $source->{$release} },
				);
			} else {
				$releases{$release} = $source->{$release};
			}
		}

		return \%releases;
	}

	return $source;
}

sub config {
	my $self = shift;

	my %config;
	while (my ($name, $release) = (each %{ $self->_releases })) {
		my %dist;
		while (my ($key, $value) = (each %$release)) {
			$key =~ s/^_*//;
			$dist{$key} = $value;
		}
		$config{$name} = \%dist;
	}

	return \%config;
}

sub has_release {
	my ($self, $name) = @_;

	return exists $self->_releases->{$name};
}

sub release {
	my ($self, $name, $new) = @_;

	if (blessed $new && $new->isa('RPM::MetaCPAN::DistConfig::Dist')) {
		$self->_releases->{$name} = $new;
	}
	return $self->_releases->{$name};
}

1;
__END__

=encoding utf-8

=head1 NAME

RPM::MetaCPAN - CPAN distribution configuration for RPM::MetaCPAN

=head1 SYNOPSIS

  use RPM::MetaCPAN::DistConfig;
  
  my $config = RPM::MetaCPAN::DistConfig->new(releases => {
      'namespace::clean' => {
	  },
	  'Test::Most' => {

	  },
  });
  
  my $true = $config->has_release('namespace::clean');
  my $dist = $config->release('Test::Most');
  $config->release('Moo', $dist);
  
  my $data = $config->config;

=head1 DESCRIPTION

RPM::MetaCPAN::DistConfig contains a set of distribution configurations.

=head1 METHODS

=head2 new

Constructor taking the standard Moo attributes. There is only one attribute,
C<releases>. This must contain a hash of L<RPM::MetaCPAN::DistConfig::Dist>
objects or hashes to be coerced to the objects.

=head2 config

Returns a raw perl data strucure of the distribution configuration, suitable
for serialising with L<JSON>, L<YAML>, or similar.

=head2 release($name[, $dist])

Access the distribution object for the named release. If the C<$dist> parameter
is passed, sets the value of the release.

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Malcolm Studd

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
