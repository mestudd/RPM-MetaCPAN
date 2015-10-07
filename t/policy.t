#!perl -T
use strict;
use Test::More;
use CPAN::Meta;
use MetaCPAN::Walker::Release;
use Role::Tiny;


my %config = (
	'Release-Name' => { build => 'yes' },
);

my $release = MetaCPAN::Walker::Release->new(
	name      => 'Release-Name',
	required  => 0,
	release   => undef,
);

my $release2 = MetaCPAN::Walker::Release->new(
	name      => 'Missing-Release',
	required  => 0,
	release   => undef,
);

sub dep {
	my ($module, $phase, $relationship) = @_;
	return {module => $module, phase => $phase, relationship => $relationship};
}


# DistConfig policy

require_ok 'MetaCPAN::Walker::Policy::DistConfig';
isa_ok my $policy = MetaCPAN::Walker::Policy::DistConfig->new(dist_config => \%config),
	'MetaCPAN::Walker::Policy::DistConfig', 'policy:distconfig is policy:distconfig';
ok Role::Tiny::does_role($policy, 'MetaCPAN::Walker::Policy'),
	'policy:distconfig does MetaCPAN::Walker::Policy';

# Test phases
ok $policy->process_dependency(
	[], $release, dep(qw(Dep::Module runtime requires))
), 'policy:distconfig runtime requires processed';
ok $policy->process_dependency(
	[], $release, dep(qw(Dep::Module configure requires))
), 'policy:distconfig phase configure processed';
ok $policy->process_dependency(
	[], $release, dep(qw(Dep::Module build requires))
), 'policy:distconfig phase build processed';
ok $policy->process_dependency(
	[], $release, dep(qw(Dep::Module test requires))
), 'policy:distconfig phase test processed';
ok !$policy->process_dependency(
	[], $release, dep(qw(Dep::Module develop requires))
), 'policy:distconfig phase develop not processed';

# Test relationships
ok $policy->process_dependency(
	[], $release, dep(qw(Dep::Module runtime recommends))
), 'policy:distconfig relationship recommends processed';
ok $policy->process_dependency(
	[], $release, dep(qw(Dep::Module runtime suggests))
), 'policy:distconfig relationship suggests processed';
ok $policy->process_dependency(
	[qw(path to release)], $release, dep(qw(Dep::Module runtime conflicts))
), 'policy:distconfig relationship conflicts processed';
is $policy->_in_conflict, 1, 'policy:distconfig marked in conflict';
$policy->_in_conflict(0);

# Test core
ok !$policy->process_dependency(
	[], $release, dep(qw(Module::CoreList runtime requires))
), 'policy:distconfig core module not processed by default';
my $core = MetaCPAN::Walker::Policy::DistConfig->new(core => 1, dist_config => \%config);
ok $core->process_dependency(
	[], $release, dep(qw(Module::CoreList runtime requires))
), 'policy:distconfig core module processed with option';

# FIXME: test perl, configured exclusions




# Test release
ok $policy->process_release([], $release),
	'policy:distconfig release processed';
ok !$policy->process_release([], $release),
	'policy:distconfig repeat release not processed';

$policy->_in_conflict(1);
ok !$policy->process_release([qw(path to release)], $release),
	'policy:distconfig conflicting release not processed';
is $policy->_in_conflict, 0,
	'policy:distconfig process conflicting release resolves conflict state';
is_deeply $policy->conflicts, { 'Release-Name' => {
		release => $release,
		paths   => [ [qw(path to release)] ],
	},
}, 'policy:distconfig populates conflicting releases';

ok !$policy->process_release([qw(path to release)], $release2),
	'policy:distconfig missing release not processed';
is_deeply $policy->missing, { 'Missing-Release' => $release2 },
	'policy:distconfig populates missing releases';

my $seen = MetaCPAN::Walker::Policy::DistConfig->new(seen => 1, dist_config => \%config);
$seen->process_release([], $release);
ok $seen->process_release([], $release),
	'policy:distconfig repeat release processed with option';

# FIXME: test in conflict, missing, seen

done_testing;
