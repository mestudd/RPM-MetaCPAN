# NAME

RPM::MetaCPAN - Manage RPM specs using MetaCPAN

# SYNOPSIS

    #!/usr/bin/perl
    use MetaCPAN::Walker;
    use MetaCPAN::Walker::Action::WriteSpec;
    use MetaCPAN::Walker::Local::RPMSpec;
    use MetaCPAN::Walker::Policy::DistConfig;
    use RPM::MetaCPAN;

    my $rpm = RPM::MetaCPAN->new_with_options;
    
    my %params = (
        %{ $rpm->configuration },
        dist_config => $rpm->dist_config,
    );
    
    my $walker = MetaCPAN::Walker->new(
        action => MetaCPAN::Walker::Action::WriteSpec->new(%params),
        local  => MetaCPAN::Walker::Local::RPMSpec->new(%params),
        policy => MetaCPAN::Walker::Policy::DistConfig->new(%params),
    );
    
    $walker->walk_from_modules(qw(namespace::clean Test::Most));

# DESCRIPTION

RPM::MetaCPAN is an RPM spec management tool using [MetaCPAN::Walker](https://metacpan.org/pod/MetaCPAN::Walker). It
aids in generating and maintaining CPAN dependencies as RPMs.

# Attributes

## config\_file

The filename of the RPM::MetaCPAN configuration file.

## configuration

The content of the RPM::MetaCPAN configuration as a raw perl data structure.
It contains parameters passed to the implementing objects.

## dist\_file

The filename of the distribution configuration.

## dist\_config

The [RPM::MetaCPAN::DistConfig](https://metacpan.org/pod/RPM::MetaCPAN::DistConfig) object containing the distribution
configuration.

## wait\_spec

Set to override the value stored in the configuration.

# AUTHOR

Malcolm Studd &lt;mestudd@gmail.com>

# COPYRIGHT

Copyright 2015- Malcolm Studd

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
