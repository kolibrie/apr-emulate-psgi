use 5.006000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'APR::Emulate::PSGI',
    VERSION_FROM      => 'lib/APR/Emulate/PSGI.pm', # finds $VERSION
    PREREQ_PM         => {'Test'        =>  0, }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/APR/Emulate/PSGI.pm', # retrieve abstract from module
       AUTHOR         => 'Nathan Gray <kolibrie@>') : ()),
);
