#!/usr/bin/perl
###############################################################################
#
# Co-Author(s):
#   Carson McNeil
#   David Choy
#   Stephanie Tsuei
#   Alex Fandrianto
#   Allen Eubank <adeubank@gmail.com>
#   John Uba
#
### Description ###############################################################
#
# Necessary functions for the correction process. Contains sub routines to
# change a lat lon box to be represented as a center point, top-right corner 
# point and the degrees of rotation and a sub routine given the center and 
# top-right point convert it back to a lat lon box.
#
# We are assuming that the Earth is flat when making these calculations
#
### Imports ###################################################################

require "stat_functions.pl";

#
# Takes a center point, top-right corner point, and the degrees of rotation 
# then recalculates lat lon box data
#
#   param[0] array
#            The top-right corner point of a lat lon box.
#
#   param[1] array
#            The center point of a lat lon box.
#
#   param[2] float
#            The degrees of rotation.
#
#   return array
#          The calculated LatLonBox with north[0], south[1], west[2], east[3],
#          and rotation[4]. All floats.
#
sub changetolatlonbox {
  # the vector array is the topRight corner point (normally thought of 
  # as Corner 1) $center[0] is longitude of center of image. $center[1] is 
  # latitude of the center.
  my @vector = @{$_[0]};
  my @center = @{$_[1]};
  my $rotation = $_[2];
  # boolean specifying whether the image crossed the international date line 
  # after correction or not
  my $cross = $_[3]; 

  my $nrth;
  my $sth;
  my $est;
  my $wst;

  # If the image crossed the date line after the average correction was applied,
  # then the translation vector and the value for the east coordinate needs to 
  # change before
  if ($cross) {
    $vector[0] -= 360 if ($vector[0] > 0);
    $vector[0] += 360 if ($vector[0] < 0);
    $est += 360;
  }

  $nrth = $center[1] + $vector[1];
  $sth = $center[1] - $vector[1];
  $est = $center[0] + $vector[0];
  $wst = $center[0] - $vector[0];

  my @latlonbox = ($nrth, $sth, $est, $wst, $rotation);
  return @latlonbox;
}

#
# Obtains the North-East corner point, center point, and a rotation value
# from a LatLonBox. These are used to represent this LatLonBox as a vector.
#
#   param array
#          The LatLonBox with north[0], south[1], west[2], east[3],
#          and rotation[4]. All floats.
#
#   return array
#           [0]The top-right corner point(array of two floats)
#           [1]center point (array of two floats), 
#           [2]rotation.
#
sub changeFromLatLonBox {

  my @latlonbox = @_;

  # find the center point.
  my $y = mean($latlonbox[0], $latlonbox[1]);
  my $x = mean($latlonbox[2], $latlonbox[3]);

  my @center = ($x, $y);
  my $rotation = $latlonbox[4];

  # all very rectangular, but get these mini-vectors so that we can put
  # them together for the topRight vector.
  my $up = $latlonbox[0] - $y;
  my $right = $latlonbox[2] - $x;

  my @topRight = ($right, $up);

  # @center is (long, lat), @topRight is (long, lat) displacements from the center
  my @result = (\@topRight, \@center, $rotation);
  return @result;
}

#
# Test whether an image crosses the international date line.
#
#   param[0] float
#             Eastern Coordinate of a LatLonBox
#   param[1] float
#             Western Coordinate of a LatLonBox
#   return integer
#           1 if the image crosses the international date line, and 0 if
#           it does not.
#
sub crossDateLine {
  my ($east, $west) = @_;
  # If the value for the eastern coordinate is less than that of the
  # western value (for images that have not been corrected yet) or the
  # eastern value is above 180 degrees (for images that have already
  # been corrected), then return 1. Otherwise, the image does not cross
  # the international date line
  if ($east < $west || $east > 180) {
    return 1;
  }
  else {
    return 0;
  }
}

1;