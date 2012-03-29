#!/usr/bin/perl -w

package DataGet;

use DBI;

###%%% INSTALLER SET CONSTANTS
$DB_NAME = "earthkam_test";
$DB_HOST = "ssvekdev";
$DB_USER = "ssvekdev";
$DB_PASSWD = "ssvekdev";
###%%%

sub dblookup ($\\@) 
{
    local($sql, *arrayp) = @_;
    undef @arrayp;

    my $dbh = DBI->connect("DBI:Pg:database=$DB_NAME;host=$DB_HOST",
                "$DB_USER","$DB_PASSWD",
         {RaiseError => 1});

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    # collect results
    while ((@row = $sth->fetchrow())) {
  foreach (@row) {
      if (/[+-]?\d+\.\d+e[+-]\d+/i) {
    $_=sprintf("%f",$_);
    s/(\.\d+)0000$/$1/;
      }
  }
  push @arrayp, join("\t",@row);
    }

    # disconnect
    $sth->finish();
    $dbh->disconnect();

    # done
    return 1;
}

1;
