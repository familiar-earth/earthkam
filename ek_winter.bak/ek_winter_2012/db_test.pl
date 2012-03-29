#!/usr/bin/perl -w

use DBI;

###%%% INSTALLER SET CONSTANTS
$DB_NAME = "earthkam_test";
$DB_HOST = "ssvekdev";
$DB_USER = "ssvekdev";
$DB_PASSWD = "ssvekdev";
###%%%

my $dbh = DBI->connect("DBI:Pg:database=$DB_NAME;host=$DB_HOST","$DB_USER","$DB_PASSWD", {RaiseError => 1});

my $sth = $dbh->prepare('SELECT * FROM test;');
$sth->execute();
    
# print results
while ((@row = $sth->fetchrow())) {
	foreach (@row) {

			print($row[0]);

      	}
}
    

    # disconnect
    $sth->finish();
    $dbh->disconnect();



