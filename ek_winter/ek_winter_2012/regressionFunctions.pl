#!/usr/bin/perl -w
########################################################################
#
# Co-Author(s):
#   Allen Eubank <adeubank@gmail.com>
#   John Uba <johnu089@yahoo.com>
#
### Description ########################################################
#
# This seperates the regression functions from updateKMLFile.pl. This
# is to increase the cohesiveness of that file. This allows for unit
# testing of the sub routines without having to run the whole script.
# This file should only contain sub routines needed for calculating
# regression data.
#
### Imports ############################################################

use strict;
use warnings;

#########################################################################

# Used with linear corrections. Finds the the y-intercepts and best fit
# slopes for the translate, rotate, and scale adjustments for making a
# linear equation. Think y = mx + b, our x is calculated time - avgTime.
#
# To see how these values are used search "sub calcLatLonBox"
#
#   param[0] float
#            The average change in X(West-East) translation.
#
#   param[1] float
#            The average change in Y(North-South) translation.
#
#   param[2] float
#            The average change in rotation that all corrected images
#            under went.
#
#   param[3] string
#            Filepath to directory with corrected images.
#
#   return array
#          All coefficients and values needed to make a linear equation.
#          avgTranslateX(0) used as the intercept for East-West linear
#          equation. avgTranslateY(1) used as the intercept for
#          North-South linear equation. avgRotate(2) used as the intercept
#          for rotation equation. slopesTranslateX(3) used as the slope
#          for the East-West linear equation. slopesTranslateY(4) used
#          as the slope for the North-South linear equation.
#          slopesRotate(5) used as the slope for the rotation linear
#          equation. avgTime(6) This value is subtracted from a
#          calculated time that an was taken and plugged into all above
#          equations as the independent variable.
#          All are floats except avgTime, it is an integer representing
#          the time at which this picture was taken in seconds.
#          See "sub getImageTime"
#
sub getInterceptsAndSlopes {

  my @translateX = @{$_[0]};
  my @translateY = @{$_[1]};
  my @rotate = @{$_[2]};
  my @correctedFilepaths = @{$_[3]};

  # two or more images were corrected, can use linear fit
  if (scalar(@correctedFilepaths) >= 2) {

    # first calculate the averages for the intercept
    my @timeValues = ();
    foreach my $correctedFilepath (@correctedFilepaths) {
      push(@timeValues, getImageTime($correctedFilepath));
    }
    my $avgTime = mean(@timeValues);
    my $avgTranslateX = mean(@translateX);
    my $avgTranslateY = mean(@translateY);
    my $avgRotate = mean(@rotate);

    # Now calculate the individual slopes with respect to that intercept to get the average slope
    my @slopesTranslateX = ();
    my @slopesTranslateY = ();
    my @slopesRotate = ();
    for (my $i = 0; $i < scalar(@correctedFilepaths); $i++) {
      my $time = getImageTime($correctedFilepaths[$i]);
      push(@slopesTranslateX, ($translateX[$i] - $avgTranslateX) / ($time - $avgTime));
      push(@slopesTranslateY, ($translateY[$i] - $avgTranslateY) / ($time - $avgTime));
      push(@slopesRotate, ($rotate[$i] - $avgRotate) / ($time - $avgTime));
    }

    return ($avgTranslateX, $avgTranslateY, $avgRotate,
      mean(@slopesTranslateX), mean(@slopesTranslateY), mean(@slopesRotate),
      $avgTime);
  }
  else
  {
    die ("Not enough images were corrected for a linear fit. Min 2\n");
  }
}


# Calculates the average of all the sets of triple quadratic regressions
sub getQuadraticRegressions
{
  my @translateX = @{$_[0]};
  my @translateY = @{$_[1]};
  my @rotate = @{$_[2]};
  my @correctedFilepaths = @{$_[3]};

  if (scalar(@correctedFilepaths < 3))
  {
    die ("Not enough images were corrected for a quadratic fit. Min 3\n");
  }
  # gets you the a, b, c coefficients for each of these values.
  my @coeffTransX = getQuadraticRegressionSingle(\@translateX, \@correctedFilepaths);
  my @coeffTransY = getQuadraticRegressionSingle(\@translateY, \@correctedFilepaths);
  my @coeffRotate = getQuadraticRegressionSingle(\@rotate, \@correctedFilepaths);
  return (\@coeffTransX, \@coeffTransY, \@coeffRotate);
}

# Calculates the quadratic regression for a single list only
sub getQuadraticRegressionSingle
{
  my @deltaYValues = @{$_[0]};
  my @correctedFilepaths = @{$_[1]};

  # Basically, we just need every combination of 3 corrected images.
  # Perform the regression and then average the results at the end
  # Calculates the coefficients for the given set of values, but only 1 set of given values

  my @aVals = ();
  my @bVals = ();
  my @cVals = ();
  for (my $i = 0; $i < scalar(@deltaYValues); $i++)
  {
    for (my $j = 0; $j < scalar(@deltaYValues); $j++)
    {
      for (my $k = 0; $k < scalar(@deltaYValues); $k++)
      {
        if ($i != $j && $j != $k && $i != $k)
        {
          my ($a, $b, $c) = getQuadraticRegressionSingleSingle(\@deltaYValues, \@correctedFilepaths, $i, $j, $k);
          push(@aVals, $a);
          push(@bVals, $b);
          push(@cVals, $c);
        }
      }
    }
  }

#  print mean(@aVals);
#  print "\n";
#  print mean(@bVals);
#  print "\n";
#  print mean(@cVals);
#  print "\n";

  # Average each of the combinations together for the final coefficients (There may be a better way involving minimizing RMSE instead of this average coefficients method)
  return (mean(@aVals), mean(@bVals), mean(@cVals));
}

# Calculates the quadratic regression for 3 points only with a very specific input
sub getQuadraticRegressionSingleSingle
{
  my @yVals = @{$_[0]};
  my @correctedFilepaths = @{$_[1]};
  my $point1 = $_[2];
  my $point2 = $_[3];
  my $point3 = $_[4];

  my $x1 = getImageTime($correctedFilepaths[$point1]);
  my $x2 = getImageTime($correctedFilepaths[$point2]);
  my $x3 = getImageTime($correctedFilepaths[$point3]);
  my $y1 = $yVals[$point1];
  my $y2 = $yVals[$point2];
  my $y3 = $yVals[$point3];

  # Calculate the coefficients for these 3 points. This is the exact quadratic curve for these 3 points
  my $a = (-1 * $x3 * ($y1 - $y2) + $x2 * ($y1 - $y3) - $x1 * ($y2 - $y3)) / (($x1 - $x2) * ($x1 - $x3) * ($x2 - $x3));
  my $b = ($x3**2 * ($y1 - $y2) - $x2**2 * ($y1 - $y3) + $x1**2 * ($y2 - $y3)) / (($x1 - $x2) * ($x1 - $x3) * ($x2 - $x3));
  my $c = ($x3 * ($x2 * ($x2 - $x3) * $y1 - $x1 * ($x1 - $x3) * $y2) + $x1 * ($x1 - $x2) * $x2 * $y3) / (($x1 - $x2) * ($x1 - $x3) * ($x2 - $x3));

  return ($a, $b, $c);
}


1;