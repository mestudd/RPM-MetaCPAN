#!perl -T
use strict;
use Test::More;
use CPAN::Meta;
use MetaCPAN::Walker::Release;
use Role::Tiny;
use RPM::MetaCPAN::DistConfig;

{
	package Test::Spec;
	use Moo;
	with qw(RPM::MetaCPAN::Spec);
}

my $dist_config = RPM::MetaCPAN::DistConfig->new(config => {
	'Fake-Release' => {},
	'Release-B' => { rpm_name => 'b', },
});

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
	download_url => 'https://example.org/src/Fake-Release.tar.gz',
	cpan_meta => CPAN::Meta->new({
		%dist,
		name      => 'Fake-Release',
	}),
);
my $release2 = MetaCPAN::Walker::Release->new(
	download_url => 'https://example.org/src/Release-B.tar.gz',
	cpan_meta => CPAN::Meta->new({
		%dist,
		name      => 'Release-B',
	}),
);

my $spec = Test::Spec->new(
	dist_config => $dist_config,
	_topdir     => './t/data',
);
ok Role::Tiny::does_role($spec, 'RPM::MetaCPAN::Spec'),
	'spec does RPM::MetaCPAN::Spec';

SKIP: {
	skip 'No rpm in /bin:/usr/bin', 1 unless -x '/bin/rpm' || -x '/usr/bin/rpm';

	# Fake $HOME to pick up test .rpmmacros file
	local $ENV{HOME} = './t/data';
	local $ENV{PATH} = '/bin:/usr/bin';

	is $spec->_topdir, './t/data', 'spec _topdir evaluated from rpm';
}
# ensure _topdir is set
$spec->_topdir('./t/data');

is $spec->perl, '5.22.0', 'spec defaults to perl 5.22';
is $spec->source_dir, './t/data/SOURCES',
	'spec defaults to SOURCES from %_topdir';
is $spec->spec_dir, './t/data/SPECS',
	'spec defaults to SPECS from %_topdir';

is $spec->name('Fake-Release'), 'perl-Fake-Release',
	'spec generates name for non-customised release';
is $spec->name('Release-B'), 'b',
	'spec uses custom name for customised release';
is $spec->spec('Fake-Release'), './t/data/SPECS/perl-Fake-Release.spec',
	'spec generates spec filename for non-customised release';
is $spec->spec('Release-B'), './t/data/SPECS/b.spec',
	'spec uses custom spec filename for customised release';
is $spec->source($release1), './t/data/SOURCES/Fake-Release.tar.gz',
	'spec uses release source filename';

done_testing;
