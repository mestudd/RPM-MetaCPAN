package RPM::MetaCPAN;
use v5.10.0;
 
use JSON::XS qw(decode_json);
use MetaCPAN::Walker;
use RPM::MetaCPAN::DistConfig;

use Moo;
use strictures 2;
use namespace::clean;

# Keep these in namespace
use MooX::Options protect_argv => 0;

our $VERSION = '0.01';

has config_file => (
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

has dists => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_dists',
);

sub _build_configuration {
	my $self = shift;
	return $self->_read_json_file($self->config_file);
}

sub _build_dist_config {
	my $self = shift;

	return RPM::MetaCPAN::DistConfig->new(
		config => $self->dists,
	);
}

sub _build_dists {
	my $self = shift;
	return $self->_read_json_file($self->dist_file);
}

sub _read_json_file {
	my ($self, $file) = @_;

	local $/;
	open( my $fh, '<', $file );
	my $json_text = <$fh>;
	close ($fh);
	return decode_json($json_text);
}

1;
__END__

=encoding utf-8

=head1 NAME

RPM::MetaCPAN - Blah blah blah

=head1 SYNOPSIS

  use RPM::MetaCPAN;

=head1 DESCRIPTION

RPM::MetaCPAN is

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Malcolm Studd

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
