# !/usr/bin/perl

# We are assuming that the Earth is flat when making these calculations

# calculates the average changes in the <LatLonBox> between several .kml files
# arguments: vectors
# output: array of changes 0: new north, 1: new south, 2: new east, 3: new west, 4: new rotation

# require "matrix_functions.pl";
require "stat_functions.pl";

# takes data and recalculates lat lon box data
sub changetolatlonbox {
	# the vector array is the topRight corner point (normally thought of as Corner 1)
	# $center[0] is longitude of center of image. $center[1] is latitude of the center.
	my @vector = @{$_[0]};
	my @center = @{$_[1]};
	my $rotation = $_[2];
	my $cross = $_[3]; # boolean specifying whether the image crossed the international date line after correction or not

	my $nrth;
	my $sth;
	my $est;
	my $wst;

	# If the image crossed the date line after the average correction was applied, then the translation vector and the value for the east coordinate needs to change before
	if ($cross)
	{
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
# changeFromLatLonBox
#   @param Array of Doubles
#          Array[0] = North coordinate
#          Array[1] = South coordinate
#          Array[2] = East coordinate
#          Array[3] = West coordinate
#          Array[4] = Rotation
#   - returns a array with reference \@topRight, \@center, $rotation
#
# TODO Test if this works
#      Whats the goal of this function?
sub changeFromLatLonBox {

	my @latlonbox = @_;

	# find the center point.
	my $y = mean($latlonbox[0], $latlonbox[1]);
	my $x = mean($latlonbox[2], $latlonbox[3]);

	my @center = ($x, $y);
	my $rotation = $latlonbox[4];

	# all very rectangular, but get these mini-vectors so that we can put
  # them together for the topRight vector.
  # TODO Check this out, what is this really calculating?
	my $up = $latlonbox[0] - $y;
	my $right = $latlonbox[2] - $x;

	my @topRight = ($right, $up);

  # @center is (long, lat), @topRight is (long, lat) displacements from the center
	my @result = (\@topRight, \@center, $rotation);
  return @result;
}

#
# crossDateLine
#   @param[0] Double Eastern Coordinate of a LatLonBox
#   @param[1] Double Western Coordinate of a LatLonBox
#   - returns 1 if the image crosses the international date line
#   - 0 if it doesn't.
#
# TODO Test if this works
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