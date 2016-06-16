package MetaCPAN::Walker::Policy::DistConfig;
use v5.10.0;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.0.1';

with qw(MetaCPAN::Walker::Policy);

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

has upgrade  => (
	is      => 'ro',
	default => 0,
);

# override to get interactive behaviour, etc
sub add_missing {
	my ($self, $path, $release) = @_;

	warn "Missing release: ".$release->name
		if (!exists $self->missing->{$release->name});
	$self->missing->{$release->name} = $release;

	return 0;
}

sub _filter_core {
	my ($self, $reqs) = @_;

}

sub process_release {
	my ($self, $path, $release) = @_;

	if (!$self->has_release($release->name)) {
		my $add = $self->add_missing([ @$path ], $release);
		return 0 unless ($add);
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

		if ($config->download_url) {
			$release->download_url($config->download_url);
		}
	}

	return $self->seen || !$seen;
}

sub release_version {
	my ($self, $release) = @_;

	if (!$self->upgrade && $release->version_local) {
		return $release->version_local;
	}
	return $release->version_latest;
}

1;
__END__

=encoding utf-8

=head1 NAME

MetaCPAN::Walker::Policy::DistConfig - Walk policy from dist config file

=head1 SYNOPSIS

  use MetaCPAN::Walker;
  use MetaCPAN::Walker::Policy::DistConfig;
  use RPM::MetaCPAN;

  my $rpm = RPM::MetaCPAN->new(config_file => 'dist.json');
  my $policy = MetaCPAN::Walker::Policy::InteractiveDistConfig->new(
      core => 0,
      dist_config => $rpm->dist_config,
	  perl => '5.22.0',
	  seen => 0,
  );
  
  my $walker = MetaCPAN::Walker->new(
      policy => $policy,
  );
  
  $walker->walk_from_modules(qw(namespace::clean Test::Most));

=head1 DESCRIPTION

MetaCPAN::Walker::Policy::DistConfig defines a flexible policy for walks,
based on a distribution configuration file.

=head1 Attributes

head2 core

Set true to walk core modules (those included with perl). Defaults to false.

=head2 dist_config

L<RPM::MetaCPAN::DistConfig> object defining the distribution configuration.

=head2 missing

Tracks the list of missing distributions.

=head2 seen

Set true to walk each release every time it appears. Set false to only walk
each release the first time it appears. Defaults to false

=head2 perl

Set the version of perl targetted. Defaults to 5.22.0.

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Recognia Inc.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
