#!/usr/bin/perl -w
###############################################################################
#
# Co-Author(s):
#   Carson McNeil
#   David Choy
#   Stephanie Tsuei
#   Alex Fandrianto
#   Allen Eubank <adeubank@gmail.com>
#   John Uba <johnu089@yahoo.com>
#
### Description ###############################################################
#
# This program takes two points described by their latitudes and longitudes and
# calculates the distance (in km) between them.
#
### Imports ###################################################################

use strict;
use Math::Trig;

### CONSTANTS #################################################################

use constants 'PI', 'RADIUS_EARTH';

my $pi = atan2(1, 1) * 4;
my $radius_earth = RADIUS_EARTH;

###############################################################################

#
# calculates the distance between two points modeling the earth as an ellipsoid
#   
sub distance {

	################## CONSTANTS
	# deg2rad function is a built-in Perl function
	# -- change variable names into name_radian??
	my ($lat, $lon, $nlat, $nlon) = @_;
	$lat = deg2rad($lat);
	$lon = deg2rad($lon);
	$nlat = deg2rad($nlat);
	$nlon = deg2rad($nlon);

	# see http://en.wikipedia.org/wiki/Flattening
	# flattening = (a - b) / a
	# a = major axis = 6378, b = minor axis = 6356.7
	my $major_axis = 6378; # length of major axis in km
	my $minor_axis = 6357; # Actually 6356.7 rounded up
	my $flattening = ($major_axis - $minor_axis) / $major_axis;

	# From http://en.wikipedia.org/wiki/Vincenty%27s_formulae
	# L = L2 - L1, difference in longitude of two points ---> $longdiff
	my $reduced_lat = atan((1 - $flattening) * tan($lat));
	my $reduced_nlat = atan((1 - $flattening) * tan($nlat));
	my $longdiff = $nlon - $lon;
	################## END CONSTANTS


	# now the gory calculations. Yes, there be blood everywhere! The two times is 
  # so that we know for absolutely sure that calc_lambda will recurse at least 
  # once
	my @lambda_result = calc_lambda($reduced_lat, $reduced_nlat, $flattening, $longdiff);

	if (scalar(@lambda_result) == 1)
	{
		my $radius_earth = RADIUS_EARTH;
		my $pi = atan2(1, 1) * 4;
		return great_circle($lat, $lon, $nlat, $nlon);
	}

	my ($lambda, $cos_sq_alpha, $cos_2sigma_m, $sin_sigma, $sigma, $cos_sigma) = @lambda_result;

	# See SECOND HALF of the "Inverse Problem" section in Wikipedia.
	# When looking at the Wikipedia formula, $major_axis = a, $minor_axis = b
	my $u_sq = $cos_sq_alpha * ($major_axis**2 - $minor_axis**2) / $minor_axis**2;
	my $A = 1 + $u_sq / 16384 * (4096 + $u_sq * (-768 + $u_sq * (320 - 175 * $u_sq)));
	my $B = $u_sq / 1024 * (256 + $u_sq * (-128 + $u_sq * (74 - 47 * $u_sq)));
	my $delta_sigma = $B * $sin_sigma * ($cos_2sigma_m + .25 * $B * ($cos_sigma * (-1 + 2 * $cos_2sigma_m**2) - (1 / 6) * $B * $cos_2sigma_m * (-3 + 4 * $sin_sigma**2) * (-3 + 4 * $cos_2sigma_m**2)));
	my $distance = $minor_axis * $A * ($sigma - $delta_sigma);
	return $distance;
}

#
# a little iterative helper function for the great circle distance. 
# Once the value "lambda" is 10**-12 percent from the last one, it has converged
# to a value.
#
sub calc_lambda {
	my ($u, $v, $f, $longdiff) = @_;
	# From formula
	my $lambda = $longdiff;
	my $last_result = 2 + $longdiff; # so that there will be an initial calculation no matter what. Otherwise, if the two latitudes are the same when doing these calculations, then there will be a distance of 0 returned.
	my ($cos_sq_alpha, $cos_2sigma_m, $sin_sigma, $sigma, $cos_sigma); # variables that will be returned by the calc_lambda function
	while (abs($lambda - $last_result) > 10**-12)
	{
		$last_result = $lambda;
		my @helper_result = calc_lambda_helper($u, $v, $f, $lambda, $longdiff);
		if (scalar(@helper_result) == 1) # if it wants to resort to the great circle distance
		{
		    #### TODO?? Implement this area using Great Circle??
			return "Use Great Circle Distance";
		}
		($lambda, $cos_sq_alpha, $cos_2sigma_m, $sin_sigma, $sigma, $cos_sigma) = @helper_result;
	}
	return ($lambda, $cos_sq_alpha, $cos_2sigma_m, $sin_sigma, $sigma, $cos_sigma);
}

# helper function to calc_lambda so that calc_lambda can iterate. This part 
# iterates the lambda value so that From Wikipedia formula: $u = U1, $v = U2
# See FIRST HALF of the "Inverse Problem" section in Wikipedia.
sub calc_lambda_helper {
	my ($u, $v, $f, $lambda, $longdiff) = @_;
	my $sin_sigma = sqrt((cos($v) * sin($lambda))**2 + (cos($u) * sin($v) - sin($u) * cos($v) * cos($lambda))**2);
	my $cos_sigma = sin($u) * sin($v) + cos($u) * cos($v) * cos($lambda);
	my $sigma = atan2($sin_sigma, $cos_sigma);

	# We don't want any division by zero. So if there is any division by zero at all, then we will resort to the Great Circle Distance
	if ($sin_sigma == 0)
	{
		return 0;
	}

	my $sin_alpha = cos($u) * cos($v) * sin($lambda) / $sin_sigma;
	my $cos_sq_alpha = 1 - $sin_alpha**2;
	my $cos_2sigma_m = $cos_sigma - 2 * sin($u) * sin($v) / $cos_sq_alpha;
	my $C = $f / 16 * $cos_sq_alpha * (4 + $f * (4 - 3 * $cos_sq_alpha));
	$lambda = $longdiff + (1 - $C) * $f * $sin_alpha * ($sigma + $C * $sin_alpha * ($cos_2sigma_m + $C * $cos_sigma * (-1 + 2 * $cos_2sigma_m**2)));
	return ($lambda, $cos_sq_alpha, $cos_2sigma_m, $sin_sigma, $sigma, $cos_sigma);
}

# To model the Earth as a sphere instead and use the great circle distance 
# formula instead of the ellipsoid model, use the predefined function:
# great_circle_distance($lon, pi/2 - $lat, $nlon, pi/2 - $nlat, $radius_of_earth);
# Since the formula thinks that the north pole and not the equator is 0 degrees,
# the pi/2 - $ lat is necessary


################################################################################
# Names
#   distance_x1, distance_x2, distance_y
#
# Description
#   distance_x1: This function calculates the longitudinal distance before the
#   change in latitudinal distance.
#
#   distance_x2: This function calculates the longitudinal distance after the
#   change in latitudinal distance.
#
#   distance_y: This function calculates the latitudinal distance alone.
################################################################################

sub distance_x1 {
    my($lon, $lat, $nlon, $nlat) = @_;

	### $lon = center between east/west from INITIAL
	### $lat = center between north/south from INITIAL
	### $nlon = center between east/west from CORRECTED
	### $nlat = center between north/south from CORRECTED

	if ($nlon > $lon)
	{
		return distance($lat, $lon, $lat, $nlon);
	}
	elsif ($lon > $nlon)
	{
		return -distance($lat, $lon, $lat, $nlon);
	}
	else
	{
		return 0;
	}
}

sub distance_x2 {
    my($lon, $lat, $nlon, $nlat) = @_;

	### $lon = center between east/west from INITIAL
	### $lat = center between north/south from INITIAL
	### $nlon = center between east/west from CORRECTED
	### $nlat = center between north/south from CORRECTED

	if ($nlon > $lon)
	{
		return distance($nlat, $lon, $nlat, $nlon);
	}
	elsif ($lon > $nlon)
	{
		return -distance($nlat, $lon, $nlat, $nlon);
	}
	else
	{
		return 0;
	}
}

sub distance_y {
    my($lon, $lat, $nlon, $nlat) = @_;
	if ($nlat > $lat)
	{
		return distance($lat, $lon, $nlat, $lon);
	}
	elsif ($lat > $nlat)
	{
		return -distance($lat, $lon, $nlat, $lon);
	}
	else
	{
		return 0;
	}
}

# --great circle distance formula--
# Check: http://en.wikipedia.org/wiki/Great-circle_distance
# The one used is the last formula in the "Formulas" section:
#
# delta_sigma = arctan{ sqrt[ (cos (phi)f * sin (delta_lambda))^2 + (cos(phi)s * sin(phi)f - sin(phi)s * cos(phi)f * cos (delta_lambda))^2 ]
#                                                             / (divided by)
#                       sin(phi)s * sin(phi)f + cos(phi)s * cos(phi)f * cos delta_lambda }
#
# delta_sigma = $cent_angle
# delta_lambda = $theta
# (phi)f = $nlat
# (phi)s = $lat
sub great_circle {
    my($lat, $lon, $nlat, $nlon) = @_;

	# --- The parameters are already in radians?? Delete conversion ??? ---
    $lat = deg2rad($lat);
    $lon = deg2rad($lon);
    $nlat = deg2rad($nlat);
    $nlon = deg2rad($nlon);
	# ---

    my $theta = $lon - $nlon;
    my $y = sqrt((cos($nlat) * sin($theta))**2 + (cos($lat) * sin($nlat) - sin($lat) * cos($nlat) * cos($theta))**2); # top part numerator
    my $x = cos($lat) * cos($nlat) * cos($theta) + sin($lat) * sin($nlat); # denominator
    my $cent_angle = atan2($y, $x); # delta_sigma from formula
    return($radius_earth * $cent_angle); # great circle distance is (radius * delta_sigma)
}


1;