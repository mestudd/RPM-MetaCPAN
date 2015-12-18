package RPM::MetaCPAN::DistConfig::Dist;
use v5.10.0;

use Module::CoreList;

use Moo;
use strictures 2;
use namespace::clean;

has archive_name => (
	is => 'rw',
);

has download_url => (
	is      => 'rw',
);

has epoch => (
	is      => 'rw',
);

has _exclude_build_requires => (
	is       => 'ro',
	init_arg => 'exclude_build_requires',
);

has _exclude_requires => (
	is       => 'ro',
	init_arg => 'exclude_requires',
);

has _extra_build_requires => (
	is       => 'ro',
	init_arg => 'extra_build_requires',
);

has _extra_requires => (
	is       => 'ro',
	init_arg => 'extra_requires',
);

has _features => (
	is       => 'ro',
	init_arg => 'features',
);

has _patches => (
	is       => 'ro',
	init_arg => 'patches',
);

has _provides => (
	is       => 'ro',
	init_arg => 'provides',
);

has _rpm_build_requires => (
	is       => 'ro',
	init_arg => 'rpm_build_requires',
);

has rpm_name => (
	is      => 'rw',
);

has _rpm_requires => (
	is       => 'ro',
	init_arg => 'rpm_requires',
);

has _with => (
	is       => 'ro',
	init_arg => 'with',
);

has _without => (
	is       => 'ro',
	init_arg => 'without',
);

sub build_requires {
	my ($self, $release, $perl, $core, $rel) = @_;

	$rel = [qw(requires recommends suggests)] if (!$rel);
	return $self->_requires(
		$release,
		$perl,
		$core,
		[qw(configure build test)],
		$rel,
		$self->_exclude_build_requires,
		$self->_extra_build_requires,
	);
}

sub exclude_build_requires {
	my $self = shift;

	return @{ $self->_exclude_build_requires // [] };
}

sub exclude_requires {
	my $self = shift;

	return @{ $self->_exclude_requires // [] };
}

sub features {
	my $self = shift;

	return @{ $self->_features // [] };
}

sub patches {
	my $self = shift;

	return @{ $self->_patches // [] };
}

sub provides {
	my $self = shift;

	return @{ $self->_provides // [] };
}

sub _requires {
	my ($self, $release, $perl, $core, $phases, $rel, $exclude, $extra) = @_;

	my $reqs = $release
		->effective_prereqs($self->_features)
		->merged_requirements($phases, $rel);

	unless ($core) {
		foreach my $module ($reqs->required_modules) {
			if (Module::CoreList::is_core($module, undef, $perl)) {
				$reqs->clear_requirement($module);
			}
		}
	}

	$reqs->clear_requirement($_)
		foreach ('perl', @$exclude);
	while (my ($module, $version) = each %$extra) {
		$reqs->add_string_requirement($module, $version);
	}

	return $reqs;
}

sub requires {
	my ($self, $release, $perl, $core, $rel) = @_;

	$rel = [qw(requires recommends suggests)] if (!$rel);
	return $self->_requires(
		$release,
		$perl,
		$core,
		[qw(runtime)],
		$rel,
		$self->_exclude_requires,
		$self->_extra_requires,
	);
}

sub rpm_build_requires {
	my $self = shift;

	return @{ $self->_rpm_build_requires // [] };
}

sub rpm_requires {
	my $self = shift;

	return @{ $self->_rpm_requires // [] };
}

no Moo;
sub with {
	my $self = shift;

	return @{ $self->_with // [] };
}

sub without {
	my $self = shift;

	return @{ $self->_without // [] };
}

1;
__END__

=encoding utf-8

=head1 NAME

RPM::MetaCPAN - CPAN distribution configuration for RPM::MetaCPAN

=head1 SYNOPSIS

  use RPM::MetaCPAN::DistConfig;
  
  my $config = RPM::MetaCPAN::DistConfig->new(releases => {
      'namespace::clean' => {
	  },
	  'Test::Most' => {

	  },
  });
  
  my $true = $config->has_release('namespace::clean');
  my $dist = $config->release('Test::Most');
  $config->release('Moo', $dist);
  
  my $data = $config->config;

=head1 DESCRIPTION

RPM::MetaCPAN::DistConfig::Dist contains a distribution configuration.

=head1 Attributes

=head2 archive_name

The base name of the archive file distributed. Only needs to be set if it does
not match the release name. Does not include the version or extension.

For example, the Authem-NTLM release requires an C<archive_name> of NTLM.

=head2 download_url

The URL from which the distribution may be downloaded. Only required to
override the MetaCPAN metadata.

=head2 epoch

The RPM epoch to use when writing the spec file.

=head2 exclude_build_requires

Array of build-time CPAN dependencies that should be ignored. These dependencies
will not be walked, and the output spec file will not contain C<BuildRequires>
for them.

=head2 exclude_requires

Array of run-time CPAN dependencies that should be ignored. These dependencies
will not be walked, and the output spec file will not contain C<Requires> for
them and will filter them from the RPM file C<requires>, should the automatic
dependencies pick them up.

=head2 extra_build_requires

Hash of extra build-time CPAN dependencies that should be added. The key is the
package name, and the value is the minimum version required.

These dependencies will be walked and the output spec file will contain
C<BuildRequires> for them.

This is useful for adding dependencies missing from MetaCPAN metadata, or for
requiring optional dependencies.

=head2 extra_requires

Hash of extra run-time CPAN dependencies that should be added. The key is the
package name, and the value is the minimum version required.

These dependencies will be walked and the output spec file will contain
C<Requires> for them.

This is useful for adding dependencies missing from MetaCPAN metadata, or for
requiring optional dependencies.

=head2 features

Array of optional features listed in MetaCPAN metadata that should be added
to the RPM. By default optional features are skipped.

=head2 patches

Array of source patches that should be applied when building the RPM.

=head2 provides

Array of extra RPM C<Provides> values.

=head2 rpm_build_requires

Array of build-time non-perl dependencies.

For example, XML-Parser requires the expat-devel rpm on RedHat-based OSes.

=head2 rpm_name

The name of the output RPM and spec files. Only required if it differs from the
CPAN release name.

=head2 rpm_requires

Array of run-time non-perl dependencies.

For example, XML-Parser requires the expat rpm on RedHat-based OSes.

=head2 with, without

List of C<--with>/C<--without> values to pass to C<rpmbuild>. These are added
to the C<dists.order> file.

For example, the CHI spec file might be customised to split out the drivers
for the various underlying caches, and only build them if requested.

=head1 METHODS

=head2 build_requires($release[, $perl[, $core[, $rel]]])

Generate a L<CPAN::Meta::Requirements> object containing the effective
build-time CPAN dependencies for the release. C<$release> is the
L<MetaCPAN::Walker::Release> object.

This takes the metadata dependencies, filters the excluded requires, and adds
the extra requires.

C<$perl> is the targetted perl version. If not specified, it defaults to the
running perl.

Set C<$core> true to include core packages in the list. By default, anything
L<Module::CoreList> reports as core is filtered.

C<$rel> contains the dependency relation-types to include. Defaults to
requires, recommends, and suggests.

=head2 requires($release[, $perl[, $core[, $rel]]])

Generate a L<CPAN::Meta::Requirements> object containing the effective
run-time CPAN dependencies for the release. C<$release> is the
L<MetaCPAN::Walker::Release> object.

This takes the metadata dependencies, filters the excluded requires, and adds
the extra requires.

C<$perl> is the targetted perl version. If not specified, it defaults to the
running perl.

Set C<$core> true to include core packages in the list. By default, anything
L<Module::CoreList> reports as core is filtered.

C<$rel> contains the dependency relation-types to include. Defaults to
requires, recommends, and suggests.

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Malcolm Studd

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
