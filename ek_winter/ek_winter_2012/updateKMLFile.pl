#!/usr/bin/perl
########################################################################
#
# Co-Author(s):
#   Stephanie Tsuei
#   Alex Fandrianto
#   Carson McNeil
#   David Choy
#   Allen Eubank <adeubank@gmail.com>
#   John Uba <johnu089@yahoo.com>
#
### Description ########################################################
#
# This script is used to calculate and apply corrections to KML files.
# The types of corrections that it can do are Constant, Linear, Quadratic,
# and Sinusodial. After corrections are calculated, the corrections are
# applied and printed to new KML files within the automated directory.
# Provide this script with a file path to a directory that contains
# three folders, completed(for KML files that have been manually adjusted)
# initial(for KML files that have not been altered), and automated(for
# KML files the output directory that this script prints KML files to.
#
#   param[0] string
#            The location to the root directory containing the
#            automated, completed, and initial directories.
#
#   param[1] string
#            The type of correction to apply to the KML files.
#
#   The possible correction values are listed here:
#
#   'constant': Uses the ellipsoidal model (for translations) to help it
#               look better than a constant offset application only, the
#               others do not use this model since they've already
#               attempted to model it.
#
#   '0': Skip the correction process and just copy over the initial
#        files to the automated. (That's a zero not a capital 'o',
#        by the way)
#
#   'lookAt': allow the application of no corrections, just copy over.
#             Useful for when manually correcting and wanting to update
#             LookAt only
#
#   'linear': application of the linear corrections to offsets for
#             rotation and translation values. Requires 2 images, or
#             fails otherwise. Scale is corrected using the 'constant'
#             corrections because those are better
#
#   'linearDirect': application of the linear corrections Directly to
#                   the values of rotation and center position.
#                   Scale is corrected using the 'constant' corrections
#                   because those are better
#
#   'quadratic': application of quadratic corrections to offsets for
#                rotation and translation values. Scale is corrected
#                using the 'constant' corrections because those are better
#
#   'quadraticDirect': application of quadratic corrections to Directly
#                      to the values of rotation and center position.
#                      Scale is corrected using the 'constant'
#                      corrections because those are better
#
#   'sinusoidal': application of sinusoidal/sawtooth corrections
#
#   'copyCorrected': copy over corrected images to automated folder
#
### Imports ############################################################

use strict;

# for avg
require "stat_functions.pl";

# for distances
require "distance_calc.pl";

# for the conversions to and from the latlonbox
require "latLongBoxChanges.pl";

# For obtaining the regression data
require "regressionFunctions.pl";

require "KMLhelperFunctions.pl";

use Matrix;

### Constants ##########################################################

use constants 'PI', 'RADIUS_EARTH';
my $pi = atan2(1, 1) * 4;
my $radius_earth = RADIUS_EARTH; # Wikipedia
my $circ_earth = 2 *$pi * $radius_earth;
my $orbitPath = $ARGV[0];
my $initialPath = $orbitPath . "initial/";
my $completedPath = $orbitPath . "completed/";
my $automatedPath = $orbitPath . "automated/";
my $CORRECT = 'constant';

########################################################################



# The general correction scheme is to apply a constant offset, averaging
# all those the differences in manual vs initial corrections. Requires 1
# corrected image to perform.

if (defined $ARGV[1]) {

  $CORRECT = $ARGV[1];

  # if sinusoidal correction, must be direct correction
  if ($CORRECT eq 'sinusoidal') {
    $CORRECT = 'sinusoidalDirect';
  }

  if ($CORRECT eq 'constantDirect') {
    die("What? Constant direct? Are you stupid/crazy? [It means every ".
      "image will be put in the exact same location...]\n");
  }
  if ($CORRECT ne 'constant' && $CORRECT ne '0' && $CORRECT ne 'lookAt'
      && $CORRECT ne 'linear' && $CORRECT ne 'linearDirect'
      && $CORRECT ne 'quadratic' && $CORRECT ne 'quadraticDirect'
      && $CORRECT ne 'sinusoidalDirect' && $CORRECT ne 'copyCorrected') {
        die("Invalid correction type: $CORRECT was inputted.\nPlease use".
          " one of the following values for correcting: \n".
          "\t0\n".
          "\tconstant\n".
          "\tlinear\n".
          "\tlinearDirect\n".
          "\tquadratic\n".
          "\tquadraticDirect\n".
          "\tsinusoidal\n".
          "\tcopyCorrected\n"); }
}

# The folders the .kml files should always be in are the 'initial' 'completed' and 'automated' folders.
# Initial is for the raw .kml files. All uncorrected .kml files go here.
# Completed is for the manually corrected .kml files.
# Automated will be the folder where all the automatically generated files appear.
# Note: The completed folder files are not simply copied over.
# Corrections are applied to them too.
#
# As a result, if more than the # of images required are manually corrected,
# then a correction will not keep those images in the same place.
#   Constant/Averaged requires 1
#   Linear requires 2
#   Quadratic requires 3
#   Sinusoidal requires 4 or more

print "$initialPath \n";
#if (! -d $initialPath) {
#  die("There are no initial images, so there is nothing to do.\n");
#}
if (! -d $completedPath) {
  `mkdir -p $completedPath`;
  unless ($CORRECT eq '0') {
    die "Warning: There are no completed images, ".
        "so there are no offsets, corrections should NOT occur.\n";
  }
}
if (! -d $automatedPath) {
  `mkdir -p -m 770 $automatedPath`;
}

if ($CORRECT eq 'copyCorrected') {
  print "Copying over corrected files to the automated folder\n";
  my @correctedFiles = <$completedPath*.kml>;
  foreach my $file (@correctedFiles) {
    my $automatedFilepath = $file . "";
    $automatedFilepath =~ s/\/completed\//\/automated\//;
    `cp -f $file $automatedFilepath`;
  }
  exit;
}

if ($CORRECT eq '0') {

  my @initialFiles = <$initialPath*.kml>;

  foreach my $file (@initialFiles) {
    my @data = getLatLonBox($file);
    printKML($file, \@data);
  }

}
else {
  # Actually apply a correction

  # X is Lon(East-West), Y is Lat(North-South)
  my @dTransX = ();
  my @dTransY = ();
  my @dRot = ();
  my @dScaleX = ();
  my @dScaleY = ();
  my @correctedFiles = <$completedPath*.kml>;

  if (scalar(@correctedFiles) == 0) {
    die ("You need a corrected image in $completedPath. Alternatively, ".
        "skip updateKMLFile by running with '0' as the second argument\n");
  }

  print "Reading " . scalar(@correctedFiles) . " corrected files from ".
        $completedPath . "\n";

  foreach my $corFile (@correctedFiles) {

    if ($CORRECT ne 'lookAt') {

      print "Reading corrected file: $corFile\n";
      # get the initial filename by using the search replace, Perl syntax
      # replace '/completed/' with '/initial/'
      my $initialFile = $corFile . "";
      $initialFile =~ s/\/completed\//\/initial\//;

      # get the lat lon boxes from the completed and initial KML file
      my @latLonBoxCorrected = getLatLonBox($corFile);
      my @latLonBoxInitial = getLatLonBox($initialFile);

      # change from latlonbox to the alt-form: four vectors, center, and
      # rotation
      my @vectorBoxCorrected = changeFromLatLonBox(@latLonBoxCorrected);
      my @vectorBoxInitial = changeFromLatLonBox(@latLonBoxInitial);

      # compare centers and push the change into the array
      my @center1 = @{ $vectorBoxInitial[1] };
      my @center2 = @{ $vectorBoxCorrected[1] };

      # Branch depending on what kind of correction is to be done.
      if (index($CORRECT, 'Direct') == -1) {

        # Calculate offsets by comparing against the initial files
        if ($CORRECT eq 'constant') {

          # put this distance is in km once you're done.
          # Remember to convert back later to degrees.
          # (Ellipsoidal model is called in the distance functions)
          my $x1 = distance_x1(@center1, @center2);
          my $y = distance_y(@center1, @center2); #north-south translation
          my $x2 = distance_x2(@center1, @center2);
          # east-west translation. We take the averages of the east-west
          # translation from before and after the north-south translation.
          my $x = mean($x1, $x2);

          # put the center value into array
          push(@dTransX, $x);
          push(@dTransY, $y);
        }
        else {
          # put the center value into array
          push(@dTransX, $center2[0] - $center1[0]);
          push(@dTransY, $center2[1] - $center1[1]);
        }

        # put rotation value into array
        my $dRotate = $vectorBoxCorrected[2] - $vectorBoxInitial[2];
        $dRotate = fixRotationValue($dRotate);
        # push the difference of rotation into the array
        push(@dRot, $dRotate);
      }
      # applying Direct corrections, so push in the actual values of the
      # corrected files. (don't compare to the initial files)
      else {
        # put the center value into array
        push(@dTransX, $center2[0]);
        push(@dTransY, $center2[1]);

        # put rotation value into array
        push(@dRot, fixRotationValue($vectorBoxCorrected[2]));
      }

      # compare the topRight vectors to get the scale change
      my @vector1 = @{ $vectorBoxInitial[0] };
      my @vector2 = @{ $vectorBoxCorrected[0] };

      # calculate and push in scale values.
      push(@dScaleX, ($vector2[0]) / $vector1[0]);
      push(@dScaleY, ($vector2[1]) / $vector1[1]);
    }
    # Only updating the lookAt values for the corrected files.
    else {
      my @latLonBoxCorrected = getLatLonBox($corFile);
      my $initialFile = $corFile . "";
      $initialFile =~ s/\/completed\//\/initial\//;
      printKML($initialFile, \@latLonBoxCorrected);
      # Doing this prints the automated file.
      # The initial filepath is just a formality to make sure the
      # printing happens in the automated folder.
    }
  }

  if ($CORRECT ne "lookAt") {

    # Now calculate the y-intercept of dTranslate, dRotate, and dScale

    my @dTranslate = (mean(@dTransX), mean(@dTransY));
    my $dRotate = avgRotationValues(@dRot);
    my @dScale = (mean(@dScaleX), mean(@dScaleY));

    my @regressionValues = (); # This will be used by the linear and quadratic corrections to store their deviously different values.
    if (index($CORRECT, 'linear') != -1) {
      @regressionValues = getInterceptsAndSlopes(\@dTransX, \@dTransY, \@dRot, \@correctedFiles);
    }
    elsif (index($CORRECT, 'quadratic') != -1) {
      @regressionValues = getQuadraticRegressions(\@dTransX, \@dTransY, \@dRot, \@correctedFiles);
    }
    elsif (index($CORRECT, 'sinusoidal') != -1) {
      @regressionValues = getSinusoidalRegressions(\@dTransX, \@dTransY, \@dRot, \@correctedFiles);
    }

    # Now compute the mean changes and apply them to each initial file (except for the complete ones)
    my @initialFiles = <$initialPath*.kml>;
    print "Correcting " . scalar(@initialFiles) . " initial files in " . $initialPath . "\n";
    foreach my $initFile (@initialFiles) {
      print "Correcting initial file: $initFile\n";
      # apply corrections to the initial files and the automated files will pop-out later
      # We no longer ignore the completed folder
      # completedImages need to have their lookAt values updated too, so we'll correct those again.
      applyCorrection(\@dTranslate, $dRotate, \@dScale, $initFile, \@regressionValues);
    }
  }
}

# search array for an element (strings)
# Nobody calls this function :(
sub containsString {
  my @array = @{ $_[0] };
  my $element = $_[1];

  foreach my $item (@array)
  {
    if ($item eq $element)
    {
      return 1;
    }
  }
  return 0;
}



#
# Takes the initial LatLonBox, applies the calculated correction
# values, and returns the new LatLonBox.
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
#            Array of values needed for regression equations.
#            Dependent on the correction type.
#
#   return array
#          Return a LatLonBox.
#          north(0), south(1), east(2), west(3) and rotation(4)
#          all are floating point numbers.
#
sub calcLatLonBox {
  my @dTranslate = @{ $_[0] };
  my $dRotate = $_[1];
  my @dScale = @{ $_[2] };
  my $filepath = $_[3];
  my @regressionData = @{$_[4]};

  # get the individual .kml data for this initial file
  my @data = getLatLonBox($filepath);

  # get the centeredData
  # 0 is the distance array (x,y) to the corner (top right)
  # 1 is center point (array, (x,y))
  # 2 is rotation value
  my @centeredData = changeFromLatLonBox(@data);

  # Scale: Everyone applies scales the same way
  my @cornerVector = @{ $centeredData[0] };
  $cornerVector[0] *= $dScale[0]; # multiply x value
  $cornerVector[1] *= $dScale[1]; # multiply y value
  $centeredData[0] = \@cornerVector;

  if ($CORRECT eq 'constant') {
    # Rotate: The rotation value just goes up by dRotate
    $centeredData[2] += $dRotate;

    # Use the great circle distance formula to get back to degrees from km.
    $dTranslate[0] *= 360 / ($circ_earth * cos(deg2rad($centeredData[1]->[1]))); # x translation
    $dTranslate[1] *= 360 / $circ_earth; # y translation

    # Translate: add to the center value and put the value back into the centered data
    my @center = @{ $centeredData[1] };
    $center[0] += $dTranslate[0];
    $center[1] += $dTranslate[1];
    $centeredData[1] = \@center;
  }
  else {
    my $timeValue = getImageTime($filepath);

    if (index($CORRECT, 'linear') != -1) {
      # obtain regression data variables
      my ($dTransX, $dTransY, $dRotation, $dTransXSlope, $dTransYSlope, $dRotateSlope, $avgTime) = @regressionData;

      #rotate
      my $rotationValue = ($dRotation + ($timeValue - $avgTime) * $dRotateSlope);

      #translate
      my @center = @{$centeredData[1]};
      my $changeX = $dTransX + ($timeValue - $avgTime) * $dTransXSlope;
      my $changeY = $dTransY + ($timeValue - $avgTime) * $dTransYSlope;

      if (index($CORRECT, 'Direct') != -1) {
        $centeredData[2] = $rotationValue;

        $center[0] = $changeX;
        $center[1] = $changeY;
      }
      else {
        $centeredData[2] += $rotationValue;

        $center[0] += $changeX;
        $center[1] += $changeY;
      }

      # store the translation changes
      $centeredData[1] = \@center;
    }
    elsif (index($CORRECT, 'quadratic') != -1) {
      # obtain regression data variables. In a, b, c format
      my @coeffTransX = @{$regressionData[0]};
      my @coeffTransY = @{$regressionData[1]};
      my @coeffRotate = @{$regressionData[2]};

      #rotate
      my $rotationValue = $coeffRotate[0] * $timeValue**2 + $coeffRotate[1] * $timeValue + $coeffRotate[2];

      #translate
      my @center = @{ $centeredData[1] };
      my $changeX = $coeffTransX[0] * $timeValue**2 + $coeffTransX[1] * $timeValue + $coeffTransX[2];
      my $changeY = $coeffTransY[0] * $timeValue**2 + $coeffTransY[1] * $timeValue + $coeffTransY[2];

      if (index($CORRECT, 'Direct') != -1) {
        $centeredData[2] = $rotationValue;

        $center[0] = $changeX;
        $center[1] = $changeY;
      }
      else {
        $centeredData[2] += $rotationValue;

        $center[0] += $changeX;
        $center[1] += $changeY;
      }

      # store the translation changes
      $centeredData[1] = \@center;
    }
    else {
      # sinusoidal regression
      # obtain regression data variables. In a, b, c format
      my @coeffTransX = @{$regressionData[0]};
      my @coeffTransY = @{$regressionData[1]};
      my @coeffRotate = @{$regressionData[2]};

      #rotate
      #my $rotationValue = $coeffRotate[0] * $timeValue**2 + $coeffRotate[1] * $timeValue + $coeffRotate[2]; #quadratic
      my $rotationValue = $coeffRotate[0] * sin($coeffRotate[1] * $timeValue) + $coeffRotate[2] * cos($coeffRotate[1] * $timeValue) + $coeffRotate[3] + $coeffRotate[4] * $timeValue; #sinusoidal

      #translate
      my @center = @{ $centeredData[1] };
      #my $changeX = $coeffTransX[0] + ($timeValue - $coeffTransX[2]) * $coeffTransX[1]; #linear
      #my $changeX = $coeffTransX[0] * $timeValue**2 + $coeffTransX[1] * $timeValue + $coeffTransX[2]; #quadratic
      #my $changeX = $coeffTransX[0] * sin($coeffTransX[1] * $timeValue) + $coeffTransX[2] * cos($coeffTransX[1] * $timeValue) + $coeffTransX[3] + $coeffTransX[4] * $timeValue; #sinusoidal
      my $changeX = $coeffTransX[0] * (($timeValue-$coeffTransX[2])/$coeffTransX[1] - int(($timeValue-$coeffTransX[2])/$coeffTransX[1])) + $coeffTransX[3]; #sawtooth

      my $changeY = $coeffTransY[0] * sin($coeffTransY[1] * $timeValue) + $coeffTransY[2] * cos($coeffTransY[1] * $timeValue) + $coeffTransY[3] + $coeffTransY[4] * $timeValue; #sinusoidal

      if (index($CORRECT, 'Direct') != -1) {
        # move image to place along regression line, where we calculate it should be
        $centeredData[2] = $rotationValue;

        $center[0] = $changeX;
        #$center[0] = $center[0]; # don't change X coordinate at all
        $center[1] = $changeY;
      }
      else {
        $centeredData[2] += $rotationValue;

        $center[0] += $changeX;
        $center[1] += $changeY;
      }

      # store the translation changes
      $centeredData[1] = \@center;
    }
  }

  # if the translation is more than 180 degrees, then we know that this
  # crossed the international date line after it moved. So we need to
  # keep the data as it is for now, but will pass a boolean ($cross)
  # saying that the image crossed the date line after it was corrected
  my $cross = 0;
  if (abs($dTranslate[0]) > 180) {
    $cross = 1;
  }

  # Now make this a LatLonBox again
  # Recall that it gets you back North, south, east, west, rotate
  my @boxedData = changetolatlonbox(@centeredData, $cross);

  # This is actually what we want to return, so...
  return @boxedData;
}



#
# gets rotation value to within 0 and 360
#
#   param float
#         A rotation value from the LatLonBox of a KML file
#
#   return float
#          A rotation value between 0 and 360
#
sub fixRotationValue
{
  my ($dRotate) = @_;
  while ($dRotate > 360)
  { $dRotate -= 360;  }
  while ($dRotate < -0)
  { $dRotate += 360;  }
  return $dRotate;
}

# Idea for this true avg of rotation values came from: http://stackoverflow.com/questions/491738/how-do-you-calculate-the-average-of-a-set-of-angles
# The point is that avg of 5 and 355 is not 180, but rather 0.
sub avgRotationValues
{
  my $ySum = 0;
  my $xSum = 0;
  for (my $i = 0; $i < @_; $i++)
  {
    $ySum += sin(@_[deg2rad($i)]);
    $xSum += cos(@_[deg2rad($i)]);
    #print "Angle being avgd: @_[$i]\n";
  }

  my $angle = atan2($ySum, $xSum);

  #print "Final angle: " . fixRotationValue($angle) . "\n";
  return fixRotationValue($angle);
}

# Calculates the sinusoidal/sawtooth regressions
sub getSinusoidalRegressions
{
  my @translateX = @{$_[0]};
  my @translateY = @{$_[1]};
  my @rotate = @{$_[2]};
  my @correctedFilepaths = @{$_[3]};

  if (scalar(@correctedFilepaths < 4))
  {
    # sometimes it'll die if not given enough images, even if given 3
    # usually happens when a couple of the images are too close together
    # so we'll say we need 4 to guarentee it working
    die ("Not enough images were corrected for a sinusoidal/quadratic fit. Min 4\n");
  }
  # gets you the a, b, c(, d) coefficients for each of these values.
  # for linear regression
#    my @coeffTransX = ();
#    my $avgTranslateX = mean(@translateX);
#    my @timeValues = ();
#    foreach my $correctedFilepath (@correctedFilepaths)
#    {
#      push(@timeValues, getImageTime($correctedFilepath));
#    }
#    my $avgTime = mean(@timeValues);
#    # Now calculate the individual slopes with respect to that intercept to get the average slope
#    my @slopesTranslateX = ();
#    for (my $i = 0; $i < scalar(@correctedFilepaths); $i++)
#    {
#     my $time = getImageTime($correctedFilepaths[$i]);
#      push(@slopesTranslateX, ($translateX[$i] - $avgTranslateX) / ($time - $avgTime));
#    }
#    push(@coeffTransX, $avgTranslateX);
#    push(@coeffTransX, mean(@slopesTranslateX));
#    push(@coeffTransX, $avgTime);
#    print @coeffTransX[0];
#    print "\n";
#    print @coeffTransX[1];
#    print "\n";
#    print @coeffTransX[2];
#    print "\n";
  #my @coeffTransX = getSinusoidalRegressionSingle(\@translateX, \@correctedFilepaths, 91*60);
  my @coeffTransX = getSawtoothRegressionSingle(\@translateX, \@correctedFilepaths, 91*60);
  my @coeffTransY = getSinusoidalRegressionSingle(\@translateY, \@correctedFilepaths, 91*60);
  my @coeffRotate = getSinusoidalRegressionSingle(\@rotate, \@correctedFilepaths, 91*60);
  return (\@coeffTransX, \@coeffTransY, \@coeffRotate);
}

# Calculates the sinusoidal regression for a single list (dimension) only
sub getSinusoidalRegressionSingle
{
  my @deltaYValues = @{$_[0]};
  my @correctedFilepaths = @{$_[1]};
  my $periodTime = $_[2];

  #my @times = map(getImageTime, @correctedFilepaths);
  my @times = ();
  for(my $i = 0; $i < scalar(@correctedFilepaths); $i++) {
    push(@times, getImageTime(@correctedFilepaths[$i]));
  }

  # guess an initial period, then increment up/down until we have the highest r^2 value
  my $timeStep = 10;

  my ($aVals, $bVals, $cVals, $dVals, $eVals) = getSinusoidalRegressionSingleSingle(\@deltaYValues, \@times, $periodTime - $timeStep);
  my ($rSquaredLess, $stdDevLess) = getSinusoidalRegressionStats(\@deltaYValues, \@times, $aVals, $bVals, $cVals, $dVals, $eVals);
  ($aVals, $bVals, $cVals, $dVals, $eVals) = getSinusoidalRegressionSingleSingle(\@deltaYValues, \@times, $periodTime + $timeStep);
  my ($rSquaredMore, $stdDevMore) = getSinusoidalRegressionStats(\@deltaYValues, \@times, $aVals, $bVals, $cVals, $dVals, $eVals);
  ($aVals, $bVals, $cVals, $dVals, $eVals) = getSinusoidalRegressionSingleSingle(\@deltaYValues, \@times, $periodTime);
  my ($rSquared, $stdDev) = getSinusoidalRegressionStats(\@deltaYValues, \@times, $aVals, $bVals, $cVals, $dVals, $eVals);
  if ($rSquaredLess > $rSquared) {
    while ($rSquaredLess > $rSquared) {
      $periodTime -= $timeStep;
      ($aVals, $bVals, $cVals, $dVals, $eVals) = getSinusoidalRegressionSingleSingle(\@deltaYValues, \@times, $periodTime - $timeStep);
      ($rSquaredLess, $stdDevLess) = getSinusoidalRegressionStats(\@deltaYValues, \@times, $aVals, $bVals, $cVals, $dVals, $eVals);
      ($aVals, $bVals, $cVals, $dVals, $eVals) = getSinusoidalRegressionSingleSingle(\@deltaYValues, \@times, $periodTime);
      ($rSquared, $stdDev) = getSinusoidalRegressionStats(\@deltaYValues, \@times, $aVals, $bVals, $cVals, $dVals, $eVals);
    }
  }
  elsif ($rSquaredMore > $rSquared) {
    while ($rSquaredMore > $rSquared) {
      $periodTime += $timeStep;
      ($aVals, $bVals, $cVals, $dVals, $eVals) = getSinusoidalRegressionSingleSingle(\@deltaYValues, \@times, $periodTime + $timeStep);
      ($rSquaredMore, $stdDevMore) = getSinusoidalRegressionStats(\@deltaYValues, \@times, $aVals, $bVals, $cVals, $dVals, $eVals);
      ($aVals, $bVals, $cVals, $dVals, $eVals) = getSinusoidalRegressionSingleSingle(\@deltaYValues, \@times, $periodTime);
      ($rSquared, $stdDev) = getSinusoidalRegressionStats(\@deltaYValues, \@times, $aVals, $bVals, $cVals, $dVals, $eVals);
    }
  }
  else {
    # keep the values from the given period, which was last calculated
    # do nothing
  }

  print "r^2: " . $rSquared;
  print "\n";
  #print "std dev: " . $stdDev;
  #print "\n";

  print $aVals;
  print "\n";
  #print $bVals . " " . $periodTime;
  print $bVals;
  print "\n";
  print $cVals;
  print "\n";
  print $dVals;
  print "\n";
  print $eVals;
  print "\n";
  print "\n";

  # Passing back a*cos(c), b, a*sin(c), d
  # Average each of the combinations together for the final coefficients (There may be a better way involving minimizing RMSE instead of this average coefficients method)
  return ($aVals, $bVals, $cVals, $dVals, $eVals);
}

# Calculate the regression coefficients given a period
sub getSinusoidalRegressionSingleSingle
{
  my @yValues = @{$_[0]};
  my @times = @{$_[1]};
  my $periodTime = $_[2];

  # Create regression on absolute values on deltaYValues vs times
  # least squares analysis
  # minimize
  # sum[({a*cos(c)}*sin(b*x(k)) + {a*sin(c)}*cos(b*x(k)) + d + e*x(k) - y(k))^2], for n = 1,2,...,n
  # x(k) = time
  # y(k) = deltaYValue
  my @sines = ();
  my @cosines = ();
  my @ones = ();
  for (my $i = 0; $i < scalar(@times); $i++) {
    push(@sines, sin(2*$pi/$periodTime*@times[$i])); # to get sin(2*pi/period * t)
    push(@cosines, cos(2*$pi/$periodTime*@times[$i]));
    push(@ones, 1);
  }
  # Calculate the regression coefficients
  # Beta = (X^T * X)^-1 * X^T * Y
  my $matrixX = new Matrix(\@sines, \@cosines, \@ones, \@times);
  $matrixX = $matrixX->transpose();
  my $matrixY = new Matrix(\@yValues);
  $matrixY = $matrixY->transpose();
  my $matrixBeta = ($matrixX->transpose() * $matrixX)->inverse() * $matrixX->transpose() * $matrixY;

  return ($matrixBeta->[0][0], 2*$pi/$periodTime, $matrixBeta->[1][0], $matrixBeta->[2][0], $matrixBeta->[3][0]);
}

sub getSinusoidalRegressionStats
{
  # y = a*sin(b*x) + c*cos(b*x) + d + e*x
  my @yValues = @{$_[0]};
  my @times = @{$_[1]};
  my $aVal = $_[2];
  my $bVal = $_[3];
  my $cVal = $_[4];
  my $dVal = $_[5];
  my $eVal = $_[6];

  # Calculate residuals
  my $mean = mean(@yValues);
  my $SSerr = 0;
  my $SStot = 0;
  for (my $i = 0; $i <= $#yValues; $i++) {
    $SSerr += ($yValues[$i] - ($aVal * sin($bVal * $times[$i]) + $cVal * cos($bVal * $times[$i]) + $dVal + $eVal * $times[$i]))**2;
    $SStot += ($yValues[$i] - $mean)**2;
    #print "$deltaYValues[$i] $SSerr $SStot \n";
  }
  my $rSquared = 1 - $SSerr/$SStot;
  my $stdDev = sqrt($SStot);

  return ($rSquared, $stdDev);
}

sub getSawtoothRegressionSingle
{
  my @deltaYValues = @{$_[0]};
  my @correctedFilepaths = @{$_[1]};
  my $periodTime = $_[2];

  #my @times = map(getImageTime, @correctedFilepaths);
  my @times = ();
  for(my $i = 0; $i < scalar(@correctedFilepaths); $i++) {
    push(@times, getImageTime(@correctedFilepaths[$i]));
  }

  # y = h * (t/period - int(t/period - s)) + v
  # s is horizontal shift to the right (between 0 and 1)
  # v is vertical shift
  # h is total height from bottom to top

  my $h;
  my $period;
  my $s;
  my $v;

  my @periods = ();
  my @rSquares = ();
  my $rSquared = 0;

  for (my $i = 0; $i < 100; $i++) {
    #initial guesses along with $period
    $h = 360;
    $period = 92*60 + 10*$i;
    $s = 0;
    $v = -180;
    push(@periods, $period);

    ($h, $period, $s, $v, $rSquared) = getSawtoothRegressionSingleSingle(\@deltaYValues, \@times, $h, $period, $s, $v);

    #store regression data to compare after
    push(@rSquares, $rSquared);

    print "Period: " . $period . " -> r^2: " . $rSquared . "\n";
  }

  # find maximum r^2 value from table
  # also gives initial guess for period that yielded this result
  my $maxRSquared = $rSquares[0];
  my $period = $periods[0];
  for (my $i = 1; $i < scalar(@rSquares); $i++) {
    if ($rSquares[$i] > $maxRSquared) {
      $maxRSquared = $rSquares[$i];
      $period = $periods[$i];
    }
  }
  # get actual values that gave the maximum r^2 value
  ($h, $period, $s, $v, $rSquared) = getSawtoothRegressionSingleSingle(\@deltaYValues, \@times, 360, $period, 0, -180);

  print "r^2: " . $rSquared;
  print "\n";

  print $h;
  print "\n";
  print $period;
  print "\n";
  print $s;
  print "\n";
  print $v;
  print "\n";
  print "\n";

  return ($h, $period, $s, $v);
}

sub getSawtoothRegressionSingleSingle
{
  my @deltaYValues = @{$_[0]};
  my @times = @{$_[1]};
  my $h = $_[2];
  my $period = $_[3];
  my $s = $_[4];
  my $v = $_[5];

  my $rSquared = 0;
  my $rSquaredLess = 0;
  my $rSquaredMore = 0;

  # amounts to shift
  my $timeStep = .125;
  my $sShift = .02;
  my $heightScale = .1;
  my $vShift = .1;

  my $iterations = 100;
  for (my $i = 0; $i < $iterations; $i++) {
    my $num_changes = 4;

    #fix period
    $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period - $timeStep, $s, $v);
    $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period + $timeStep, $s, $v);
    $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
    if ($rSquaredLess > $rSquared) {
      while ($rSquaredLess > $rSquared) {
        $period -= $timeStep;
        $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period - $timeStep, $s, $v);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } elsif ($rSquaredMore > $rSquared) {
      while ($rSquaredMore > $rSquared) {
        $period += $timeStep;
        $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period + $timeStep, $s, $v);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } else {
      # do nothing, guess is fine
      $num_changes -= 1;
    }

    #fix horizontal shift
    $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s - $sShift, $v);
    $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s + $sShift, $v);
    $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
    if ($rSquaredLess > $rSquared) {
      while ($rSquaredLess > $rSquared) {
        $s -= $sShift;
        $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s - $sShift, $v);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } elsif ($rSquaredMore > $rSquared) {
      while ($rSquaredMore > $rSquared) {
        $s += $sShift;
        $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s + $sShift, $v);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } else {
      # do nothing, guess is fine
      $num_changes -= 1;
    }

    #fix height
    $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h - $heightScale, $period, $s, $v);
    $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h + $heightScale, $period, $s, $v);
    $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
    if ($rSquaredLess > $rSquared) {
      while ($rSquaredLess > $rSquared) {
        $h -= $heightScale;
        $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h - $heightScale, $period, $s, $v);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } elsif ($rSquaredMore > $rSquared) {
      while ($rSquaredMore > $rSquared) {
        $h += $heightScale;
        $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h + $heightScale, $period, $s, $v);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } else {
      # do nothing, guess is fine
      $num_changes -= 1;
    }

    #fix vertical shift
    $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v - $vShift);
    $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v + $vShift);
    $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
    if ($rSquaredLess > $rSquared) {
      while ($rSquaredLess > $rSquared) {
        $v -= $vShift;
        $rSquaredLess = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v - $vShift);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } elsif ($rSquaredMore > $rSquared) {
      while ($rSquaredMore > $rSquared) {
        $v += $vShift;
        $rSquaredMore = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v + $vShift);
        $rSquared = getSawtoothRegressionStats(\@deltaYValues, \@times, $h, $period, $s, $v);
      }
    } else {
      # do nothing, guess is fine
      $num_changes -= 1;
    }

    if ($num_changes == 0) {
      # didn't make any changes to the variables, so break out of loop
      last;
    }
  }

  return ($h, $period, $s, $v, $rSquared);
}

sub getSawtoothRegressionStats
{
  # y = a * ((t-c)/b - int((t-c)/b)) + d
  my @yValues = @{$_[0]};
  my @times = @{$_[1]};
  my $aVal = $_[2];
  my $bVal = $_[3];
  my $cVal = $_[4];
  my $dVal = $_[5];

  # Calculate residuals
  my $mean = mean(@yValues);
  my $SSerr = 0;
  my $SStot = 0;
  for (my $i = 0; $i <= $#yValues; $i++) {
    $SSerr += ($yValues[$i] - ($aVal * (($times[$i]-$cVal)/$bVal - int(($times[$i]-$cVal)/$bVal)) + $dVal))**2;
    $SStot += ($yValues[$i] - $mean)**2;
    #print "$deltaYValues[$i] $SSerr $SStot \n";
  }
  my $rSquared = 1 - $SSerr/$SStot;
  my $stdDev = sqrt($SStot);

  #return ($rSquared, $stdDev);
  return $rSquared;
}

1;
