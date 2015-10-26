package MetaCPAN::Walker::Policy::InteractiveDistConfig;
use v5.10.0;

use JSON;
use MetaCPAN::Walker::Release;
use Term::ReadKey;

use Moo;
use strictures 2;
use namespace::clean;

our $VERSION = '0.01';
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
		'  Action: -)nfo s)kip; a)dd; c)ustomise? ',
		'sac',
	);
	while ($key) {
		if ('s' eq $key) {
			$self->missing->{$release->name} = $release;
			$add = 0;
			last;

=cut
		} elsif ('i' eq $key) {
			# FIXME: add other info if possible?
			my $dist = $self->_new_dist();
			say 'Runtime dependencies';
			$self->_print_requires($dist, 'requires', $release);
			say 'Build dependencies';
			$self->_print_requires($dist, 'requires', $release);
			$key = $self->_read_char(
				"  Action: s)kip; a)dd; c)ustomise? ",
				'sac',
			);
			next;
=cut

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

	if (open(my $fh, '>', 'dists.incr.json')) {
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

	$self->_print_requires($dist, 'build_requires', $release);
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
$DB::single = 1;
		last if (!$answer);
		last if (!defined($re) || $answer =~ $re);
	}
	ReadMode('restore');

	return $answer;
}

1;
