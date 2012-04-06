#!/usr/bin/perl -w
########################################################################
#
# Co-Author(s):
#   Allen Eubank <adeubank@gmail.com>
#   John Uba <johnu089@yahoo.com>
#
### Description ########################################################
#
# A simple Perl style sheet, this part describes the purpose of this
# Perl module.
#
### Imports ############################################################

use strict;
use warnings;

########################################################################


#
# Take values calculated from correction process, calculate the new
# LatLonBox and pass that to print a new KML file.
#
#   param[0] array
#            Array of two floats, representing the average translation
#            each manually corrected image under went.
#
#   param[1] float
#            Average rotation that all corrected images under went
#
#   param[2] array
#            Array of two floats, representing the average scale that
#            all corrected images changed by.
#
#   param[3] string
#            Filepath to initial KML file.
#
#   param[4] array
#            Dependent on the correction type.
#
sub applyCorrection {
  my @dTranslate = @{ $_[0] };
  my $dRotate = $_[1];
  my @dScale = @{ $_[2] };
  my $filepath = $_[3];
  my @regressionData = @{ $_[4] };

  my @newLatlonbox = calcLatLonBox(\@dTranslate, $dRotate, \@dScale, $filepath, \@regressionData);
  printKML($filepath, \@newLatlonbox);
}

#
# getLatLonBox parses the LatLonBox from a KML file
#
#   param string
#         Filepath to a KML file
#
#   return array
#          Return a LatLonBox.
#          north(0), south(1), east(2), west(3) and rotation(4)
#          all are floating point numbers.
#
sub getLatLonBox {
  my ($filepath) = @_;
  open (KMLFILE, $filepath) or die "Could not open $filepath";

  my $seenNorth = 0;
  my $line = "";
  until ($seenNorth) {
    $line = <KMLFILE>;
    chomp($line); # get rid of new line at end of this line

    my $index = index($line, "<north>"); # this is the index we need
    if ($index != -1) {
      $seenNorth = 1; # now we can just read 5 lines of data
    }
  }

  # the next 5 lines of data contain the
  # north (0), south (1), east (2), west (3), and rotation (4)
  # values in that order.
  # We are currently on the <north> line
  my @data = ();
  for (my $i = 0; $i < 5; $i++) {

    # Take the substring of the number between the < > and </ > tags
    # gets whatever is between the <tag>...</tag>
    my $string = substr($line, index($line, ">")+1,
                  index($line, "</") - index($line, ">") - 1);
    $data[$i] = $string;

    $line = <KMLFILE>; #get the next line
  }

  # If the picture so happens to cross the international date line here
  # (if the eastern side of the picture has coordinates that are less
  # than those on the western side), then we will add 360 degrees to the
  # eastern side for the rest of the correction step
  if (crossDateLine($data[2], $data[3])) {
    $data[2] += 360;
  }
  close(KMLFILE);

  return @data;
}


#
# Returns the time value at which this image was taken in seconds.
# This asks getImageID() for the ID and calculates the time value of the image
# As a result, we get the actual time in seconds
# Image ID is 9 digits long DDDHHMMSS (with 3 digits for day, 2 for hour,
# 2 for minute, and 2 for seconds)
# Image ID can also be 8 digits for the STS DDHHMMSS. Luckily, since I
# calculate 'the rest' as days, the formula still works!
#
#   param String
#         The filepath to a KML file.
#
#   return integer
#          The time at which this image was taken in seconds.
#
sub getImageTime
{
  my $filepath = $_[0];
  my $imageid = getImageID($filepath);

  $imageid = int($imageid); # since a string may have been returned, let's protect by converting to int (front 0s are deleted)

  my $time = 0;
  $time += ($imageid % 100); #tack on seconds
  $imageid = int($imageid / 100); #shift so that minutes are last

  $time += ($imageid % 100) * 60; # tack on minutes converted to seconds
  $imageid = int($imageid / 100); #shift so that hours are last

  $time += ($imageid % 100) * 60 * 60; # tack on hours converted to seconds
  $imageid = int($imageid / 100); #shift so that days are last

  $time += $imageid * 24 * 60 * 60; # The rest are days, so convert them to seconds

  return $time;
}

# This gets you the image id from the inputted .kml filepath
#
#   param string
#         The filepath to a KML file.
#
#   return string
#          The ID of a KML file that represents when this image was taken.
#
sub getImageID
{
  my $filepath = $_[0];

  open (KMLFILE, $filepath) or die "Could not open $filepath";
  while (my $line = <KMLFILE>)
  {
    if (index($line, "<name>") != -1) # This is the line with the imageid on it
    {
      my $string = substr($line, index($line, ">")+1, index($line, "</") - index($line, ">") - 1); # gets whatever is between the <tag>...</tag>

      # $string is of form ######.####.imageid
      # We are getting rid of everything before and including the 2 periods.
      $string = substr($string, index($string, ".")+1);
      $string = substr($string, index($string, ".")+1);

       # This is our $imageID
      return $string;
    }
  }
  die "Did not find an imageid in $filepath\n";
}

# This prints out the new .kml file, given the filepath to the old .kml
# file and the new latlonbox data. See a .kml file for the approximate
# syntax. This should be correct though. Make sure that 'initial' is the
# only folder called 'initial' in your filepath though. Writes to the
# automated directory.
#
#   param[1] string
#            The filepath to where to the initial KML files.
#
#   param[2] array
#            A LatLonBox.
#            north(0), south(1), east(2), west(3) and rotation(4)
#            all are floating point numbers.
#
sub printKML
{
  my $filepath = $_[0];
  my @data = @{ $_[1] };

  # Make a copy of the original filepath
  my $newFilepath = $filepath . "";

  # replaces the string '/initial/' with '/automated/' in the filepath
  $newFilepath =~ s/\/initial\//\/automated\//;

  # begin by reading from the old .kml file and copying to a new .kml
  # file until we reach "<LatLonBox>"
  open(FILE, $filepath) or die("ERROR: Could not open $filepath\n");
  open(NEWDATA, ">$newFilepath") or die("Could not open/create $newFilepath\n");

  my $lookAt = 0;
  until ($lookAt)
  {
    my $line = <FILE>;
    print NEWDATA $line;

    if (index($line, "<LookAt>") != -1)
    {
      $lookAt = 1;
    }
  }

  my $lon = mean($data[2], $data[3]);
  my $lat = mean($data[0], $data[1]);

  # lookAt box just needs 2 fields updated
  for (my $i = 0; $i < 2; $i++)
  {
    my $line = <FILE>; # skip lines in the oldfile

    # and write the corresponding new line
    # it is 4 spaces per 'tab'
    if ($i == 0)
    {
      print NEWDATA "            <longitude>$lon</longitude>\n";
    }
    else # $i is 1
    {
      print NEWDATA "            <latitude>$lat</latitude>\n";
    }
  }

  my $skipFive = 0;
  until ($skipFive)
  {
    my $line = <FILE>;
    print NEWDATA $line;

    if (index($line, "<LatLonBox>") != -1)
    {
      $skipFive = 1;
    }
  }

  # latlonbox data is north, south, east, west, rotation
  for (my $i = 0; $i < 5; $i++)
  {
    my $line = <FILE>; # skip lines in the oldfile

    #and write the corresponding new line
    if ($i == 0)
    {
      print NEWDATA "            <north>$data[$i]</north>\n";
    }
    elsif ($i == 1)
    {
      print NEWDATA "            <south>$data[$i]</south>\n";
    }
    elsif ($i == 2)
    {
      print NEWDATA "            <east>$data[$i]</east>\n";
    }
    elsif ($i == 3)
    {
      print NEWDATA "            <west>$data[$i]</west>\n";
    }
    elsif ($i == 4)
    {
      print NEWDATA "            <rotation>" . fixRotationValue($data[$i]) . "</rotation>\n";
    }
    else
    {
      print NEWDATA "This 'for' loop is broken.\n";
    }
  }

  while (my $line = <FILE>) # until end of file, continue copying over
  {
    print NEWDATA $line;
  }

  # We're done, so close the files.
  close(FILE);
  close(NEWDATA);
}



1;