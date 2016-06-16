package RPM::MetaCPAN;
use v5.10.0;
 
use JSON qw(decode_json);
use MetaCPAN::Walker;
use RPM::MetaCPAN::DistConfig;

use Moo;
use strictures 2;
use namespace::clean;

# Keep these in namespace
use MooX::Options protect_argv => 0;

our $VERSION = '0.0.2';

option config_file => (
	is      => 'ro',
	format  => 's',
	default => './etc/config.json',
);

has configuration => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_configuration',
);

option dist_file => (
	is      => 'ro',
	format  => 's',
	default => './etc/dists.json',
);

has dist_config => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_dist_config',
);

option upgrade => (
	is          => 'ro',
	predicate   => 1,
	negativable => 1,
);

option wait_spec => (
	is          => 'ro',
	predicate   => 1,
	negativable => 1,
);

sub _build_configuration {
	my $self = shift;
	my $config = $self->_read_json_file($self->config_file);
	$config->{upgrade} = $self->upgrade if ($self->has_upgrade);
	$config->{wait_spec} = $self->wait_spec if ($self->has_wait_spec);
	return $config;
}

sub _build_dist_config {
	my $self = shift;

	return RPM::MetaCPAN::DistConfig->new(
		config => $self->_read_json_file($self->dist_file),
	);
}

sub _read_json_file {
	my ($self, $file) = @_;

	local $/;
	open( my $fh, '<:encoding(UTF-8)', $file );
	my $json_text = <$fh>;
	close ($fh);
	return decode_json($json_text);
}

1;
__END__

=encoding utf-8

=head1 NAME

RPM::MetaCPAN - Manage RPM specs using MetaCPAN

=head1 SYNOPSIS

  #!/usr/bin/perl
  use MetaCPAN::Walker;
  use MetaCPAN::Walker::Action::WriteSpec;
  use MetaCPAN::Walker::Local::RPMSpec;
  use MetaCPAN::Walker::Policy::DistConfig;
  use RPM::MetaCPAN;

  my $rpm = RPM::MetaCPAN->new_with_options;
  
  my %params = (
      %{ $rpm->configuration },
      dist_config => $rpm->dist_config,
  );
  
  my $walker = MetaCPAN::Walker->new(
      action => MetaCPAN::Walker::Action::WriteSpec->new(%params),
      local  => MetaCPAN::Walker::Local::RPMSpec->new(%params),
      policy => MetaCPAN::Walker::Policy::DistConfig->new(%params),
  );
  
  $walker->walk_from_modules(qw(namespace::clean Test::Most));

=head1 DESCRIPTION

RPM::MetaCPAN is an RPM spec management tool using L<MetaCPAN::Walker>. It
aids in generating and maintaining CPAN dependencies as RPMs.

=head1 Attributes

=head2 config_file

The filename of the RPM::MetaCPAN configuration file.

=head2 configuration

The content of the RPM::MetaCPAN configuration as a raw perl data structure.
It contains parameters passed to the implementing objects.

=head2 dist_file

The filename of the distribution configuration.

=head2 dist_config

The L<RPM::MetaCPAN::DistConfig> object containing the distribution
configuration.

=head2 wait_spec

Set to override the value stored in the configuration.

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Malcolm Studd

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
