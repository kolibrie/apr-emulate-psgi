use 5.010000;
use inc::Module::Install;

# Define metadata
name             'APR-Emulate-PSGI';
all_from         'lib/APR/Emulate/PSGI.pm';
readme_pod_from  'lib/APR/Emulate/PSGI.pm';

# Specific dependencies
test_requires  'Test::More'  => '0.88';
auto_set_repository;

WriteAll;
