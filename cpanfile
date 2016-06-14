requires 'perl', 'v5.10.0';
requires 'Archive::Tar';
requires 'CPAN::Meta';
requires 'File::Basename';
requires 'HTTP::Tiny';
requires 'JSON';
requires 'MetaCPAN::Client::Release';
requires 'MetaCPAN::Walker';
requires 'MetaCPAN::Walker::Action::WriteSpec';
requires 'MetaCPAN::Walker::Local::RPMSpec';
requires 'MetaCPAN::Walker::Policy::DistConfig';
requires 'MetaCPAN::Walker::Policy::InteractiveDistConfig';
requires 'MetaCPAN::Walker::Release';
requires 'Module::Build::Tiny', '0.034';
requires 'Module::CoreList';
requires 'Moo';
requires 'Moo::Role';
requires 'MooX::Options';
requires 'namespace::clean';
requires 'POSIX';
requires 'Role::Tiny';
requires 'Scalar::Util';
requires 'strictures', '2';
requires 'Term::ReadKey';
requires 'Test::More';
requires 'Test::Output';


# requires 'Some::Module', 'VERSION';

on test => sub {
    requires 'Test::More', '0.96';
};
