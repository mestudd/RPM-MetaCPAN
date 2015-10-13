#!perl -T
use strict;
use Test::More;
use CPAN::Meta;
use MetaCPAN::Walker::Release;
use Role::Tiny;


my %dist = (
	abstract       => 'abstract',
	author         => ['author'],
	dynamic_config => 0,
	generated_by   => 'nothing',
	license        => ['perl_5'],
	'meta-spec'    => { version => 2 },
	release_status => 'stable',
	version        => 'v0.0.1',
);

my $release1 = MetaCPAN::Walker::Release->new(
	cpan_meta => CPAN::Meta->new({
		%dist,
		name      => 'Release-A',
	}),
);
my $release2 = MetaCPAN::Walker::Release->new(
	cpan_meta => CPAN::Meta->new({
		%dist,
		name      => 'Release-B',
	}),
);
my $release3 = MetaCPAN::Walker::Release->new(
	cpan_meta => CPAN::Meta->new({
		%dist,
		name      => 'Release-C',
	}),
);

# use "require $module" as heuristic
require_ok 'MetaCPAN::Walker::Local::RPMSpec';
isa_ok my $local = MetaCPAN::Walker::Local::RPMSpec->new(
	spec_dir => './t/data',
	dist_config => {
		'Release-B' => { rpm_name => 'b' },
	},
), 'MetaCPAN::Walker::Local::RPMSpec', 'local:rpmspec is local:rpmspec';
ok Role::Tiny::does_role($local, 'MetaCPAN::Walker::Local'),
	'local:rpmspec does MetaCPAN::Walker::Local';

is $local->local_version($release1),
	'v1.23.5-rc6', 'local:rpmspec finds default name release';
is $local->local_version($release2),
	'v20150102.gitad4f7b43', 'local:rpmspec finds custom name release';
is $local->local_version($release3),
	'v0', 'local:rpmspec does not find non-existent release';

done_testing;
