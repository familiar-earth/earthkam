#!/usr/bin/perl -w
###############################################################################
#
# Co-Author(s):
#   Stephanie Tsuei
#   Alex Fandrianto
#   Allen Eubank <adeubank@gmail.com>
#   John Uba <johnu089@yahoo.com>
#
### Description ###############################################################
#
# Calculates the four corners of a lat long box. 
#
### IMPORTS ###################################################################

use constants 'PI', 'RADIUS_EARTH';

### CONSTANTS #################################################################

my $pi = PI;
$pi = ${$pi};
my $radius_earth = RADIUS_EARTH;
my $circ_earth = $radius_earth * 2 * $pi;

###############################################################################

# Name
#   calc_orig_dim
# Description: calculates the original dimensions of an image...? (
# after the image has been resized and stuff?)
#   
# Arguments
#   0   bounding rectangle width
#   1   bounding rectangle height
#   2   angle (degrees CCW) of original image
# Return Value
#   (original width, original height)

# Steph: Does anything actually use this?
sub calc_orig_dim {
    my($w, $h, $ang) = @_;
    
    $ang = $ang % 360;
    
    my $t = deg2rad($ang);
    
    my $width = ($w * (cos($t)) - $h * (sin($t))) / cos(2 * $t);
    my $height = ($h * (cos($t)) - $w * (sin($t))) / cos(2 * $t);
    
    return($width, $height);
}


# Name
#   calc_corners
# Description
#   Given a rectangle and a rotation angle, this will calculate the corner
#   points of the resulting rectangle. The points returned are numbered with
#   corner 1 in the upper-right and proceeding counter-clockwise.
# Arguments
#   0   center latitude coordinate   
#   1   center longitude coordinate
#   2   width of rectangle
#   3   height of rectangle
#   4   angle of rotation (degrees CCW)
# Return Value
#   (c1lat, c1lon, c2lat, c2lon, c3lat, c3lon, c4lat, c4lon)

# calculates the position of the four corners of an image given the coordinates of the center and the width and the height (in kilometers) and the angle of rotation. Returns the latitude and longitudes of the four corners
sub calc_corners {
    my($cLat, $cLon, $width, $height, $angle) = @_; # the angle will always be less than 360 degrees
    
	#print "$cLat $cLon $width $height $angle \n";
	
    # Rotates the corner points relative to the center of the image
    # Stores in c1...c4 the points relative to the center of the image in km 
    my($c1lon, $c1lat) = rotate_vector($width / 2, $height / 2, $angle); # These are distance vectors in kilometers
    my($c2lon, $c2lat) = rotate_vector(-$width / 2, $height / 2, $angle);
    my($c3lon, $c3lat) = rotate_vector(-$width / 2, -$height / 2, $angle);
    my($c4lon, $c4lat) = rotate_vector($width / 2, -$height / 2, $angle);
		
    # Converts corner point latitudes from kilometers to degrees
    $c1lat *= 360 / $circ_earth;
    $c2lat *= 360 / $circ_earth;
    $c3lat *= 360 / $circ_earth;
    $c4lat *= 360 / $circ_earth;

    # Converts corner point longitudes from kilometers to degrees
    $c1lon *= 360 / ($circ_earth * cos(deg2radOUR($c1lat + $cLat)));
    $c2lon *= 360 / ($circ_earth * cos(deg2radOUR($c2lat + $cLat)));
    $c3lon *= 360 / ($circ_earth * cos(deg2radOUR($c3lat + $cLat)));
    $c4lon *= 360 / ($circ_earth * cos(deg2radOUR($c4lat + $cLat)));    

    # Adds the center latitudes and longitudes to c1..c4 so that c1...c4 are
    # the true latitude and longitudes of the corners on the earth
    $c1lat += $cLat;
    $c2lat += $cLat;
    $c3lat += $cLat;
    $c4lat += $cLat;
    $c1lon += $cLon;
    $c2lon += $cLon;
    $c3lon += $cLon;
    $c4lon += $cLon;
    
    return($c1lat, $c1lon, $c2lat, $c2lon, $c3lat, $c3lon, $c4lat, $c4lon);
}

# Name
#   rotate_vector
# Description
#   This function takes a vector (x, y) and rotates it by angle degrees CCW.
#   Rotates using rotation matrix.
# Arguments
#   0   x-coord
#   1   y-coord
#   2   angle (degrees CCW)
# Return Value
#   (newX, newY)

sub rotate_vector {
    my($x, $y, $ang) = @_;
    
    $ang = $ang * $pi / 180; # convert to radians
    my $newX = $x * cos($ang) - $y * sin($ang); # multiply by rotation matrix
    my $newY = $x * sin($ang) + $y * cos($ang);
    
    return($newX, $newY);
}

################################################################################
# Name
#   deg2rad, rad2deg
#
# Arguments
#   deg2rad: 0   degrees
#   rad2deg: 0   radians
#
# Return Value
#   deg2rad: radians
#   rad2deg: degrees
################################################################################

sub deg2radOUR {
    my($deg) = @_;
    return($deg * $pi / 180);
}

sub rad2degOUR {
    my($deg) = @_;
    return($deg * 180 / $pi);
}

=comment
################################################################################
# Name
#   arccos
# Arguments
#   0   angle in radians
# Return Value
#   acos of angle
################################################################################

sub acos {
   my($x) = @_;
   return atan2(sqrt(1 - $x**2), $x);
}
=cut
1;