#!perl -T
use strict;
use Test::More;
use Test::Output;
use MetaCPAN::Walker::Release;
use Role::Tiny;


my $release1 = MetaCPAN::Walker::Release->new(
	name      => 'Release-Name',
	required  => 0,
	release   => undef,
);
my $release2 = MetaCPAN::Walker::Release->new(
	name      => 'Release-Two',
	required  => 2,
	release   => undef,
);

# Print build order
require_ok 'MetaCPAN::Walker::Action::PrintOrder';
isa_ok my $action = MetaCPAN::Walker::Action::PrintOrder->new(),
	'MetaCPAN::Walker::Action::PrintOrder', 'action:order is action:order';
ok Role::Tiny::does_role($action, 'MetaCPAN::Walker::Action'),
	'action:order does MetaCPAN::Walker::Action';

stdout_is sub { $action->begin_release(); },
	'', 'action:order nothing at begin';
stdout_is sub { $action->missing_module(); },
	'', 'action:order nothing for missing';
stdout_is sub { $action->circular_dependency(); },
	'', 'action:order nothing for circular dependency';

stdout_is sub { $action->end_release(['Release-Name'], $release1); },
	"Release-Name\n", 'action:order top-level release';
stdout_is sub { $action->end_release([1, 2, 3, 4, 'Release-Two'], $release2); },
	"Release-Two\n", 'action:order recursed release';
stdout_is sub { $action->end_release([1, 2, 3, 'Release-Name'], $release1); },
	'', 'action:order release not repeated';


# Print dependency tree
require_ok 'MetaCPAN::Walker::Action::PrintTree';
isa_ok $action = MetaCPAN::Walker::Action::PrintTree->new(),
	'MetaCPAN::Walker::Action::PrintTree', 'action:tree is action:tree';
ok Role::Tiny::does_role($action, 'MetaCPAN::Walker::Action'),
	'action:tree does MetaCPAN::Walker::Action';

stdout_is sub { $action->end_release(); },
	'', 'action:tree nothing at begin';
stderr_like sub { $action->missing_module(['Release-Name'], 'Missing::Module'); },
	qr/No release for module: Missing::Module/, 'action:tree warning for missing';
stdout_is sub { $action->circular_dependency(); },
	'', 'action:tree nothing for circular dependency';

stdout_is sub { $action->begin_release(['Release-Name'], $release1); },
	"Release-Name\n", 'action:tree top-level release';
stdout_is sub { $action->begin_release([1, 2, 3, 4, 'Release-Two'], $release2); },
	"        Release-Two\n", 'action:tree recursed release';
stdout_is sub { $action->begin_release(['Release-Name'], $release1); },
	"Release-Name\n", 'action:tree release repeated';

done_testing;
