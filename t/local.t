#!perl -T
use strict;
use Test::More;
use CPAN::Meta;
use MetaCPAN::Client::Release;
use Role::Tiny;
use RPM::MetaCPAN::DistConfig;


my $release1 = MetaCPAN::Client::Release->new(
	data => { distribution => 'Release-A', version => 'v1.23.7' },
);
my $release2 = MetaCPAN::Client::Release->new(
	data => { distribution => 'Release-B', version => '20150103.git3fe6c9a2' },
);
my $release3 = MetaCPAN::Client::Release->new(
	data => { distribution => 'Release-C' },
);

# use "require $module" as heuristic
require_ok 'MetaCPAN::Walker::Local::RPMSpec';
isa_ok my $local = MetaCPAN::Walker::Local::RPMSpec->new(
	spec_dir => './t/data',
	dist_config => RPM::MetaCPAN::DistConfig->new(config => {
		'Release-B' => { rpm_name => 'b' },
	}),
), 'MetaCPAN::Walker::Local::RPMSpec', 'local:rpmspec is local:rpmspec';
ok Role::Tiny::does_role($local, 'MetaCPAN::Walker::Local'),
	'local:rpmspec does MetaCPAN::Walker::Local';

is $local->local_version($release1),
	'v1.23.5-rc6', 'local:rpmspec finds default name release';
is $local->local_version($release2),
	'20150102.gitad4f7b43', 'local:rpmspec finds custom name release';
is $local->local_version($release3),
	'v0', 'local:rpmspec does not find non-existent release';

done_testing;
