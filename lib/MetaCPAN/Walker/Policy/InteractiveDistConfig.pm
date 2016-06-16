package MetaCPAN::Walker::Policy::InteractiveDistConfig;
use v5.10.0;

use JSON;
use MetaCPAN::Walker::Release;
use Term::ReadKey;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.0.1';
my $JSON = JSON->new->utf8->pretty->canonical;

extends 'MetaCPAN::Walker::Policy::DistConfig';

END {
	ReadMode('restore');
}


sub add_missing {
	my ($self, $path, $release) = @_;

	my $name = $release->name;

	if (exists $self->missing->{$name}) {
		say "Skipping release $name again";
		return 0;
	}

	my $add = 0;
	say "At ", join(' -> ', @$path);
	say "  Release $name is missing.";
	my $dist = $self->_new_dist();
	say '    Runtime dependencies';
	$self->_print_requires($dist, 'requires', $release);
	say '    Build dependencies';
	$self->_print_requires($dist, 'build_requires', $release);
	if (my @features = $release->features) {
		say '    Plus optional features: ',
			join(', ', map $_->identifier, @features);
	}
	my $key = $self->_read_char(
		'  Action: s)kip; a)dd; c)ustomise? ',
		'sac',
	);
	while ($key) {
		if ('s' eq $key) {
			$self->missing->{$release->name} = $release;
			$add = 0;
			last;

		} elsif ('a' eq $key) {
			say "Adding $name with no customisation";
			$self->release($name, $self->_new_dist());
			$add = 1;
			last;

		} elsif ('c' eq $key) {
			$add = $self->_customise_dist($release);
			last;
		}
	}

	if (open(my $fh, '>:encoding(UTF-8)', 'dists.incr.json')) {
		print $fh $JSON->encode($self->dist_config->config);
	}

	return $add;
}

sub _customise_dist {
	my ($self, $release) = @_;

	my %config;
	my $dist = $self->_new_dist();

	while (1) {
		if (my $rpm = $self->_read_string(
				'Set custom RPM name [perl-'. $release->name. ']? ',
		)) {
			$config{rpm_name} = $rpm;
		}

		if (my $url = $self->_read_string(
				'Set custom download URL ['. $release->download_url. ']? ',
		)) {
			$config{download_url} = $url;
		}

		if (my $epoch = $self->_read_string(
				'Set epoch [0]? ',
				qr/\d+/,
		)) {
			$config{epoch} = $epoch;
		}

		# FIXME patches

		if (my @features = $release->features) {
			$config{features} = $self->_read_features(@features);
		}

		say 'Build requirements are:';
		my ($exclude, $extra) = $self->_read_requires(
			$dist, 'build_requires', $release,
		);
		$config{exclude_build_requires} = $exclude if ($exclude);
		$config{extra_build_requires} = $extra if ($extra);

		say 'Runtime requirements are:';
		($exclude, $extra) = $self->_read_requires(
			$dist, 'requires', $release,
		);
		$config{exclude_requires} = $exclude if ($exclude);
		$config{extra_requires} = $extra if ($extra);

		# FIXME provides

		say 'Dist configuration will be:';
		use Data::Dumper; say Dumper(\%config);
		my $key = $self->_read_char(
			"  Action: a)dd; r)estart; d)rop? ",
			'ard',
		);
		last if ($key eq 'a');
		%config = () if ($key eq 'r');
		return 0 if ($key eq 'd');
	}

	$self->release($release->name, $self->_new_dist(%config));

	return 1;
}

sub _print_requires {
	my ($self, $dist, $type, $release) = @_;

	my $has = 0;
	foreach my $rel (qw(requires recommends suggests)) {
		my $reqs = $dist->$type($release, $self->perl, 0, [$rel]);
		if ($reqs->required_modules) {
			say '      ', $rel;
			say '        ', join(',  ', $reqs->required_modules);
			$has = 1;
		}
	}

	return $has;
}

sub _new_dist {
	my $self = shift;

	return RPM::MetaCPAN::DistConfig::Dist->new(@_);
}

sub _read_char {
	my ($self, $question, $allowed) = @_;

	ReadMode('cbreak');
	print $question;
	my $answer;
	while ($answer = ReadKey(0)) {
		last if ($answer =~ /[$allowed]/);
	}
	say $answer;
	ReadMode('restore');

	return $answer;
}

sub _read_features {
	my ($self, @features) = @_;

	say 'Optional features are: ', join(', ', map $_->identifier, @features);
	my $key = $self->_read_char(
		"  Action: i)nfo s)kip; a)dd; c)ustomise? ",
		'isac',
	);
	while ($key) {
		if ('s' eq $key) {
			say "Excluding all features";
			return [];

		} elsif ('i' eq $key) {
			say "print more info";
			$key = $self->_read_char(
				"  Action: s)kip; a)dd; c)ustomise? ",
				'sac',
			);
			next;

		} elsif ('a' eq $key) {
			say "Adding all features";
			return [ map $_->identifier, @features ];

		} elsif ('c' eq $key) {
			my $enabled = $self->_read_string(
				'Enter features to include (space separated): ',
			);
			return [ split /\s+/, $enabled ];
		}
	}
}

sub _read_requires {
	my ($self, $dist, $type, $release) = @_;

	my ($exclude, $extra);

	$self->_print_requires($dist, $type, $release);
	my $answer = $self->_read_string(
		'Enter modules to exclude (space separated) []: ',
	);
	if ($answer) {
		$exclude = [ split /\s+/, $answer ];
	}
	$answer = $self->_read_string(
		'Enter extra modules to include (space separated) []: ',
	);
	if ($answer) {
		$extra = { map +($_ => '0'), split /\s+/, $answer };
	}

	return ($exclude, $extra);
}

sub _read_string {
	my ($self, $question, $re) = @_;

	my $answer;
	ReadMode('normal');
	while (1) {
		print $question;
		$answer = ReadLine(0);
		chomp $answer;
		last if (!$answer);
		last if (!defined($re) || $answer =~ $re);
	}
	ReadMode('restore');

	return $answer;
}

sub release_version {
	my ($self, $release) = @_;

	my $name = $release->name;
	my $latest = $release->version_latest;
	my $local = $release->version_local;
	my $want = $latest;
	if ($local && $latest gt $local) {
		my $key = $self->_read_char(
			"Release $name $local has update to $latest: upgrade? [y/n] ",
			'yn',
		);
		$want = $local if ($key eq 'n');
	}
	return $want;
}

1;
__END__

=encoding utf-8

=head1 NAME

MetaCPAN::Walker::Policy::InteractiveDistConfig - Walk policy from dist config file

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

MetaCPAN::Walker::Policy::InteractiveDistConfig extends the flexible walk
policy configuration of L<MetaCPAN::Walker::Policy::DistConfig> with interactive
prompts for unknown distributions.

head2 core

Set true to walk core modules (those included with perl). Defaults to false.

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
