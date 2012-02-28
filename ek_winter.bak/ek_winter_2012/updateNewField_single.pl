#!/usr/bin/perl
use strict;

# This file updates the ekImages database with new correction information for one file. 

# arguments passed to it are just the absolute path of the file. ...

#Want to update newclat, newclon, distanceoff, angleoff

require "ekincl.pl";
require "distance_calc.pl";
require "frame_incl.pl";

# updates the database
sub update_single {

  my $TRUE = 1;
  my $FALSE = 0;
  my $pi = atan2(1, 1) *4;
  my $radius_earth = 6378;
  my $circ_earth = $radius_earth * 2 * $pi;

  my ($file, $user, $DEBUG) = @_; #input is a filepath
  print "Updating file: " . $file . "\n" if $DEBUG;
  open(FILE, $file) || die("ERROR: Could not open $file");
  my @data = <FILE>;
  close(FILE);

  my $found = $TRUE;
  open(KML, $file) || ($found = $FALSE);
  if($found == $FALSE)
  {
    print "Could not find $file.\n";
  }
  else
  {
    my $iid;
    my $north;
    my $south;
    my $east;
    my $west;
    my $rotation;
    while(<KML>)
    {
      if($_ =~ /\<name/) {
        $iid = (split /name\>/, $_)[1];
        $iid =~ s/<\///g;
      } elsif($_ =~ /\<north\>/) {
        $north = (split /north\>/, $_)[1];
        $north =~ s/<\///g; 
      } elsif($_ =~ /\<south\>/) {
        $south = (split /south\>/, $_)[1];
        $south =~ s/<\///g;
      } elsif( $_ =~ /\<east\>/) {
        $east = (split /east\>/, $_)[1];
        $east =~ s/<\///g;
      } elsif( $_ =~ /\<west\>/) {
        $west = (split /west\>/, $_)[1];
        $west =~ s/<\///g;
      } elsif( $_ =~ /\<rotation\>/) {
        $rotation = (split /rotation\>/, $_)[1];
        $rotation =~ s/<\///g;
      }
    }

    my ($lon, $lat, $rotation2) = get_angle_distances($file);
    my ($distanceOff, $angleOff) = calc_distanceOff_angleOff($file);

    my $clatR = $lat * 3.1415192653 / 180; #center latitude in radians
    my $cosCLat = cos($clatR); #cosine of center latitude
    my $dlat = abs($north - $south);  
    my $dlon = abs($east - $west);
    my $height = ($dlat / 360) * $circ_earth; #height and width are in km
    my $width = ($dlon / 360) * ($circ_earth * $cosCLat);
    my $rotation = $rotation % 360; # rotation value that is less than 360 degrees. %= does not work.
    
    my($c1lat, $c1lon, $c2lat, $c2lon, $c3lat, $c3lon, $c4lat, $c4lon) = calc_corners($lat, $lon, $width, $height, $rotation);
    
    # get the current date and time
    my $cd = `date`;
    
    # Essential to update. compstat and the new corner latitudes and longitudes (rotated by the newrotation value), newrotation
    # Also updated: compuser, compdate, newclat, newclon, newheight, newwidth, distanceOff, angleOff
    my $sql = "UPDATE ekImages SET compstat=\'final\', compuser=\'$user\', compdate=\'$cd\', newclat=$lat, newclon=$lon, newheight=$height, newwidth=$width, nc1lat=$c1lat, nc1lon=$c1lon, nc2lat=$c2lat, nc2lon=$c2lon, nc3lat=$c3lat, nc3lon=$c3lon, nc4lat=$c4lat, nc4lon=$c4lon, distanceoff=$distanceOff, angleOff=$angleOff, newrotation=$rotation WHERE filepath=\'$iid\'";
    
    print "Query: $sql\n" if $DEBUG;
    
    # Uses ekincl.pl's dbpudate function to send the query.
    &dbupdate($sql);
  }
}

# Gets the values for the distanceOff and angleOff fields from a .kml file
sub get_angle_distances {
  my ($filepath) = @_;
  
  open (KMLFILE, $filepath) or die "Could not open $filepath";

  my $longitude;
  my $latitude;
  my $rotation;
  
  while (my $line = <KMLFILE>)
  {
    chomp($line); # apparently, they tend to end with \n, so we get rid of it, though we don't have to

    if (index($line, "<longitude>") >= 0)
    {
      $longitude = substr($line, index($line, ">")+1, index($line, "</") - index($line, ">") - 1);
      $line = <KMLFILE>;
      $latitude = substr($line, index($line, ">")+1, index($line, "</") - index($line, ">") - 1);
    }
    elsif (index($line, "<rotation>") >= 0)
    {
      $rotation = substr($line, index($line, ">")+1, index($line, "</") - index($line, ">") - 1);
    }
  }

  # We are done with the file.
  close(KMLFILE);

  return ($longitude, $latitude, $rotation);
}

#calculates the distanceOff and angleOff values to update the database with
sub calc_distanceOff_angleOff {
  my ($filepath) = @_;
  
  my @completed = get_angle_distances($filepath); # Gets the latitude, longitude, and rotation values from the corrected or automated .kml file
  if (index($filepath, "completed") != -1) 
  {
    $filepath =~ s/\/completed\//\/initial\//;
  }
  elsif (index($filepath, "automated") != -1)
  {
    $filepath =~ s/\/automated\//\/initial\//;
  }
  else
  {
    die "invalid filepath $filepath was entered. It does not exist in the right folder structure.\n";
  }
  my @initial = get_angle_distances($filepath); # now get the latitude, longitude, and rotation values from the initial,  uncorrected .kml file
  
  my $angleOff = $completed[2] - $initial[2];
  my $distanceOff = distance($initial[1], $initial[0], $completed[1], $completed[0]);
  
  return ($distanceOff, $angleOff);
}

1;
