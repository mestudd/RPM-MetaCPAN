#!perl -T
use strict;
use Test::More;
use CPAN::Meta;
use MetaCPAN::Walker::Release;
use Role::Tiny;


my %config = (
	'Release-Name' => {
		exclude_requires => [ 'runtime::suggests' ],
		exclude_build_requires => [ 'test::recommends', 'build::suggests' ],
	},
);

my %dist = (
	abstract       => 'abstract',
	author         => ['author'],
	dynamic_config => 0,
	generated_by   => 'nothing',
	license        => ['perl_5'],
	'meta-spec'    => { version => 2 },
	release_status => 'stable',
	version        => 'v0.0.1',
	optional_features => {
		option => { prereqs => { runtime => {
			requires   => { 'option::requires'   => '0' },
			recommends => { 'option::recommends' => '0' },
		}}},
	},
);

my $release = MetaCPAN::Walker::Release->new(
	cpan_meta => CPAN::Meta->new({
		%dist,
		name      => 'Release-Name',
		prereqs => {
			runtime => {
				requires   => {
					'runtime::requires' => '0',
					'Module::CoreList' => '0',
				},
				recommends => { 'runtime::recommends' => '0' },
				suggests   => { 'runtime::suggests'   => '0' },
				conflicts  => { 'runtime::conflicts'  => '0' },
			},
			test => {
				requires   => { 'test::requires'   => '0' },
				recommends => { 'test::recommends' => '0' },
				suggests   => { 'test::suggests'   => '0' },
				conflicts  => { 'test::conflicts'  => '0' },
			},
			build => {
				requires   => { 'build::requires'   => '0' },
				recommends => { 'build::recommends' => '0' },
				suggests   => { 'build::suggests'   => '0' },
				conflicts  => { 'build::conflicts'  => '0' },
			},
			configure => {
				requires   => { 'configure::requires'   => '0' },
				recommends => { 'configure::recommends' => '0' },
				suggests   => { 'configure::suggests'   => '0' },
				conflicts  => { 'configure::conflicts'  => '0' },
			},
			develop => {
				requires   => { 'develop::requires'   => '0' },
				recommends => { 'develop::recommends' => '0' },
				suggests   => { 'develop::suggests'   => '0' },
				conflicts  => { 'develop::conflicts'  => '0' },
			},
		},
	}),
);

my $release2 = MetaCPAN::Walker::Release->new(
	cpan_meta => CPAN::Meta->new({
		%dist,
		name      => 'Missing-Release',
	}),
);


# DistConfig policy

require_ok 'MetaCPAN::Walker::Policy::DistConfig';
isa_ok my $policy = MetaCPAN::Walker::Policy::DistConfig->new(dist_config => \%config),
	'MetaCPAN::Walker::Policy::DistConfig', 'policy:distconfig is policy:distconfig';
ok Role::Tiny::does_role($policy, 'MetaCPAN::Walker::Policy'),
	'policy:distconfig does MetaCPAN::Walker::Policy';


# Test release
ok $policy->process_release([], $release),
	'policy:distconfig release processed';
is_deeply [ sort $release->required_modules ],
	[sort qw(runtime::recommends runtime::requires
		configure::recommends configure::requires configure::suggests
		build::recommends build::requires
		test::requires test::suggests)],
	'policy:distconfig pulls most phases and relationships, minus filtered';

ok !$policy->process_release([], $release),
	'policy:distconfig repeat release not processed';

ok !$policy->process_release([qw(path to release)], $release2),
	'policy:distconfig missing release not processed';
is_deeply $policy->missing, { 'Missing-Release' => $release2 },
	'policy:distconfig populates missing releases';


# Test core
my $core = MetaCPAN::Walker::Policy::DistConfig->new(core => 1, dist_config => \%config);
$core->process_release([], $release);
is_deeply [ sort $release->required_modules ],
	[sort qw(runtime::recommends runtime::requires
		configure::recommends configure::requires configure::suggests
		build::recommends build::requires
		test::requires test::suggests
		Module::CoreList)],
	'policy:distconfig core module processed with option';


# Test features
my %feature_config = %config;
$feature_config{'Release-Name'}->{features} = [ 'option' ];
my $features = MetaCPAN::Walker::Policy::DistConfig->new(
	dist_config => \%feature_config,
);
$features->process_release([], $release);
is_deeply [ sort $release->required_modules ],
	[sort qw(runtime::recommends runtime::requires
		configure::recommends configure::requires configure::suggests
		build::recommends build::requires
		test::requires test::suggests
		option::requires option::recommends)],
	'policy:distconfig optional feature processed with config';


my $seen = MetaCPAN::Walker::Policy::DistConfig->new(seen => 1, dist_config => \%config);
$seen->process_release([], $release);
ok $seen->process_release([], $release),
	'policy:distconfig repeat release processed with option';

done_testing;
