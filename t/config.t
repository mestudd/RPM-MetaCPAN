#!perl -T
use strict;
use Test::More;
use CPAN::Meta;
use MetaCPAN::Walker::Release;


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

require_ok 'RPM::MetaCPAN::DistConfig';

isa_ok my $dist_default = RPM::MetaCPAN::DistConfig::Dist->new(),
	'RPM::MetaCPAN::DistConfig::Dist', 'dist is distconfig:dist';

is $dist_default->epoch, undef, 'dist default epoch undef';
$dist_default->epoch(3);
is $dist_default->epoch, 3, 'set epoch';
is $dist_default->rpm_name, undef, 'dist default rpm_name undef';
$dist_default->rpm_name('rpm-name');
is $dist_default->rpm_name, 'rpm-name', 'set rpm name';

is_deeply $dist_default->_exclude_build_requires, [],
	'dist default exclude build requires';
is_deeply $dist_default->_exclude_requires, [],
	'dist default exclude requires';
is_deeply $dist_default->_extra_build_requires, {},
	'dist default extra build requires';
is_deeply $dist_default->_extra_requires, {},
	'dist default extra requires';
is_deeply $dist_default->_features, [], # FIXME: need to distinguish between configured none and not configured?
	'dist default features';
is_deeply $dist_default->_patches, [],
	'dist default patches';
is_deeply $dist_default->_provides, [],
	'dist default provides';
is_deeply $dist_default->_rpm_build_requires, [],
	'dist default exclude build requires';
is_deeply $dist_default->_rpm_build_requires, [],
	'dist default exclude build requires';

my $dist = RPM::MetaCPAN::DistConfig::Dist->new(
	epoch => 2,
	rpm_name => 'rpm-name',
	exclude_build_requires => [ 'build::suggests' ],
	exclude_requires => [ 'runtime::suggests' ],
	extra_build_requires => { 'Build::Required' => '0' },
	extra_requires => { 'Install::Required' => 'v1.0.3' },
	features => [ 'option' ],
	patches => [ 'dist.patch' ],
	provides => [ 'provide' ],
	rpm_build_requires => [ 'rpm-package' ],
	rpm_requires => [ 'rpm-package2' ],
);

is $dist->epoch, 2, 'dist configured epoch';
is $dist->rpm_name, 'rpm-name', 'dist configured rpm_name';
is_deeply $dist->_exclude_build_requires, [ 'build::suggests' ],
	'dist configured exclude build requires';
is_deeply $dist->_exclude_requires, [ 'runtime::suggests' ],
	'dist configured exclude requires';
is_deeply $dist->_extra_build_requires, { 'Build::Required' => '0' },
	'dist configured extra build requires';
is_deeply $dist->_extra_requires, { 'Install::Required' => 'v1.0.3' },
	'dist configured extra requires';
is_deeply $dist->_features, [ 'option' ],
	'dist configured features';
is_deeply $dist->_patches, [ 'dist.patch' ],
	'dist configured patches';
is_deeply $dist->_provides, [ 'provide' ],
	'dist configured provides';
is_deeply $dist->_rpm_build_requires, [ 'rpm-package' ],
	'dist configured rpm build requires';
is_deeply $dist->_rpm_requires, [ 'rpm-package2' ],
	'dist configured rpm requires';

is_deeply [ $dist->exclude_build_requires ], [ 'build::suggests' ],
	'dist exclude build requires getter';
is_deeply [ $dist->exclude_requires ], [ 'runtime::suggests' ],
	'dist exclude requires getter';
is_deeply [ $dist->features ], [ 'option' ],
	'dist features getter';
is_deeply [ $dist->patches ], [ 'dist.patch' ],
	'dist patches getter';
is_deeply [ $dist->provides ], [ 'provide' ],
	'dist provides getter';


isa_ok my $reqs = $dist->build_requires($release),
	'CPAN::Meta::Requirements';
is_deeply [ sort $reqs->required_modules ],
	[sort qw(Build::Required
		configure::recommends configure::requires configure::suggests
		build::recommends build::requires
		test::recommends test::requires test::suggests)],
	'dist pulls build dependencies modified by configuration';
isa_ok $reqs = $dist->requires($release),
	'CPAN::Meta::Requirements';
is_deeply [ sort $reqs->required_modules ],
	[sort qw(runtime::recommends runtime::requires
		option::recommends option::requires
		Module::CoreList Install::Required)],
	'dist pulls build dependencies modified by configuration';

done_testing;
