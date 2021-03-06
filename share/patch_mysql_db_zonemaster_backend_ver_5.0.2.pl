use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;

die "The configuration file does not contain the MySQL backend" unless (lc(Zonemaster::Backend::Config->load_config()->BackendDBType()) eq 'mysql');
my $db_user = Zonemaster::Backend::Config->load_config()->DB_user();
my $db_password = Zonemaster::Backend::Config->load_config()->DB_password();
my $db_name = Zonemaster::Backend::Config->load_config()->DB_name();
my $connection_string = Zonemaster::Backend::Config->load_config()->DB_connection_string();

my $dbh = DBI->connect( $connection_string, $db_user, $db_password, { RaiseError => 1, AutoCommit => 1 } );

sub patch_db {
    ############################################################################
    # Convert column "results" to MEDIUMBLOB so that it can hold larger results
    ############################################################################
    $dbh->do( 'ALTER TABLE test_results MODIFY results mediumblob' );
}

patch_db();
