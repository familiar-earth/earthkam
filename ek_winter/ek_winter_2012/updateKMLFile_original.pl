#!/usr/bin/perl
use strict;

# This file is called in KMLupload.cgi. The first input is the orbit, and the second is the number of corrected files.

# Useful for create_automated_orbit.pl when reading old and creating the new .kml files
# Note that throughout this file, dScale and dTranslate will be in km, so the final reading involves a change

require "stat_functions.pl"; # for avg
require "distance_calc.pl"; # for distances
require "lat_long_box_changes.pl"; #for the conversions to and from the latlonbox
use Matrix; # see Matrix.pm file

use constants 'PI', 'RADIUS_EARTH';
# some constants
my $pi = atan2(1, 1) * 4;
my $radius_earth = RADIUS_EARTH; 
my $circ_earth = 2 *$pi * $radius_earth;

my $orbitPath = $ARGV[0]; # $ARGV[0] obtained from KMLupload.cgi
my $CORRECT = 'constant'; # The general correction scheme is to apply a constant offset, averaging all those the differences in manual vs initial corrections. Requires 1 corrected image to perform.
if (defined $ARGV[1])
{
  # 'constant': Uses the ellipsoidal model (for translations) to help it look better than a constant offset application only, the others do not use this model since they've already attempted to model it.
  # '0': Skip the correction process and just copy over the initial files to the automated. (That's a zero not a capital 'o', by the way)
  # 'lookAt': allow the application of no corrections, just copy over. Useful for when manually correcting and wanting to update LookAt only
  # 'linear': application of the linear corrections to offsets for rotation and translation values. Requires 2 images, or fails otherwise. Scale is corrected using the 'constant' corrections because those are better
  # 'linearDirect': application of the linear corrections Directly to the values of rotation and center position. Scale is corrected using the 'constant' corrections because those are better
  # 'quadratic': application of quadratic corrections to offsets for rotation and translation values. Scale is corrected using the 'constant' corrections because those are better
  # 'quadraticDirect': application of quadratic corrections to Directly to the values of rotation and center position. Scale is corrected using the 'constant' corrections because those are better
  # 'sinusoidal': application of sinusoidal/sawtooth corrections
  # 'copyCorrected': copy over corrected images to automated folder
  
  $CORRECT = $ARGV[1]; # $ARGV[1] obtained from KMLupload.cgi around lines 113-150
  
  # if sinusoidal correction, must be direct correction
  if ($CORRECT eq 'sinusoidal') {
    $CORRECT = 'sinusoidalDirect';
  }

  if ($CORRECT eq 'constantDirect')
  { die("What? Constant direct? Are you stupid/crazy? [It means every image will be put in the exact same location...]\n"); }
  if ($CORRECT ne 'constant' && $CORRECT ne '0' && $CORRECT ne 'lookAt' && $CORRECT ne 'linear' && $CORRECT ne 'linearDirect' && $CORRECT ne 'quadratic' && $CORRECT ne 'quadraticDirect' && $CORRECT ne 'sinusoidalDirect' && $CORRECT ne 'copyCorrected')
  { die("Invalid correction type: $CORRECT was inputted.\n"); }
}

# The folders the .kml files should always be in are the 'initial' 'completed' and 'automated' folders.
# Initial is for the raw .kml files. All uncorrected .kml files go here.
# Completed is for the manually corrected .kml files.
# Automated will be the folder where all the automatically generated files appear. Note: The completed folder files are not simply copied over. Corrections are applied to them too.
  # As a result, if more than the # of images required are manually corrected, then a correction will not keep those images in the same place.
  # Constant/Averaged requires 1
  # Linear requires 2
  # Quadratic requires 3
my $initialPath = $orbitPath . "initial/";
my $completedPath = $orbitPath . "completed/";
my $automatedPath = $orbitPath . "automated/";

print "$initialPath \n";

#if (! -d $initialPath)
#{
#  die("There are no initial images, so there is nothing to do.\n");
#}

#create the directories if they do not exist
if (! -d $completedPath) 
{
  `mkdir -p $completedPath`;
  unless ($CORRECT eq '0')
  {
    die "Warning: There are no completed images, so there are no offsets, corrections should NOT occur.\n";
  }
}
if (! -d $automatedPath)
{
  `mkdir -p -m 770 $automatedPath`;
}

# Copy corrected files to automated folder.
if ($CORRECT eq 'copyCorrected')
{
  print "Copying over corrected files to the automated folder\n";
  my @correctedFiles = <$completedPath*.kml>;
  foreach my $file (@correctedFiles)
  {
    my $automatedFilepath = $file . "";
    $automatedFilepath =~ s/\/completed\//\/automated\//;
    `cp -f $file $automatedFilepath`;
  }
  exit;
}

if ($CORRECT eq '0') #### How can $CORRECT be 0? KMLUpload does not allow it.
{
  my @initialFiles = <$initialPath*.kml>;
  foreach my $file (@initialFiles)
  {
    my @data = getLatLonBox($file);
    printKML($file, \@data);
  }
}
else # MAIN CORRECTION 
{
  # Actually apply a correction

  # X is Lon, Y is Lat
  my @dTransX = (); # translation, movement in x/y direction
  my @dTransY = ();
  my @dRot = (); # rotation
  my @dScaleX = ();
  my @dScaleY = ();

  my @correctedFiles = <$completedPath*.kml>;
  
  # check if number of corrected images is 0
  if (scalar(@correctedFiles) == 0) 
  {
    die ("You need a corrected image in $completedPath. Alternatively, skip updateKMLFile by running with '0' as the second argument\n");
  }
  print "Reading " . scalar(@correctedFiles) . " corrected files from " . $completedPath . "\n";
  
  foreach my $file (@correctedFiles) 
  {
    if ($CORRECT ne 'lookAt')
    {
      #print "Reading corrected file: $file\n";
      # get the initial filename by using the search replace, Perl syntax
      # replace '/completed/' with '/initial/'
      my $initialFile = $file . "";
      $initialFile =~ s/\/completed\//\/initial\//;
      
      # get the lat lon boxes
	  # getLatLonBox returns an array that contains the north, south, east, west, and rotation values of the KML file
	  # [0] = north
	  # [1] = south
	  # [2] = east
	  # [3] = west
	  # [4] = rotation
      my @latLonBoxCorrected = getLatLonBox($file);
      my @latLonBoxInitial = getLatLonBox($initialFile);

      # change from latlonbox to the alt-form: four vectors, center, and rotation
      my @vectorBoxCorrected = changefromlatlonbox(@latLonBoxCorrected); # changefromlatlonbox subroutine is found in lat_long_box_changes.pl file
      my @vectorBoxInitial = changefromlatlonbox(@latLonBoxInitial);
	  
	  # -- AFTER CALLING THE changefromlatlonbox SUBROUTINE --
	  # @vectorBoxCorrected and @vectorBoxInitial now contain an array: (@topRight, @center, $rotation)
	  # @topright = ($right (longitude), $up (latitude) ), the coordinates for the top right vector
	  # @center = ( center of east/west (longitude), center of north/south (latitude) )

      # compare centers and push the change into the array
      my @center1 = @{ $vectorBoxInitial[1] };
      my @center2 = @{ $vectorBoxCorrected[1] };
	  # @center1/@center2 now contain: @center from initial and corrected
      
	  # See comments above in lines 22-30 for information on Direct and Non-Direct
      if (index($CORRECT, 'Direct') == -1) # if $CORRECT does not contain the string 'Direct'
      {  
        # not applying Direct corrections. Calculate offsets by comparing against the initial files
        if ($CORRECT eq 'constant')
        {
          # put this distance is in km once you're done. Remember to convert back later to degrees. (Ellipsoidal model is called in the distance functions)
          # The 'distance' subroutines below can be found in distance_calc.pl file.
		  my $x1 = distance_x1(@center1, @center2); # longitudinal distance before the change in latitudinal distance
          my $y = distance_y(@center1, @center2); # north-south translation
          my $x2 = distance_x2(@center1, @center2); # longitudinal distance after the change in latitudinal distance
          my $x = mean($x1, $x2); #east-west translation. We take the averages of the east-west translation from before and after the north-south translation. 
          
          # put the center value into array
          push(@dTransX, $x); # $center2 is coordinate of initial, $center1 is corrected
          push(@dTransY, $y);
        }
        else
        {
          # put the center value into array
          push(@dTransX, $center2[0] - $center1[0]); # (center between east/west from CORRECTED) - (center between east/west from INITIAL)
          push(@dTransY, $center2[1] - $center1[1]); # (center between north/south from CORRECTED) - (center between north/south from INITIAL)        
        }
        
        # put rotation value into array
		# Rotation is the same for Direct or Non-Direct
        my $dRotate = $vectorBoxCorrected[2] - $vectorBoxInitial[2]; # rotation of Corrected - rotation of Initial
		# fixRotationValue is found in lines 795-804. It makes sure that the rotation is between 0 and 360 degrees.
        $dRotate = fixRotationValue($dRotate);
        # compare rotations and push the change into the array
        push(@dRot, $dRotate);        
      }
      else #applying Direct corrections, so push in the actual values of the corrected files. (don't compare to the initial files)
      {
        # put the center value into array
        push(@dTransX, $center2[0]); # longitude of corrected
        push(@dTransY, $center2[1]); # latitude of corrected

        # put rotation value into array
        push(@dRot, fixRotationValue($vectorBoxCorrected[2]));        
      }
	  
      # compare the topRight vectors to get the scale change
      my @vector1 = @{ $vectorBoxInitial[0] };
      my @vector2 = @{ $vectorBoxCorrected[0] };

      # calculate and push in scale values.
      push(@dScaleX, ($vector2[0]) / $vector1[0]); # topRight longitude of corrected / topRight longitude of initial
      push(@dScaleY, ($vector2[1]) / $vector1[1]); # topRight latitude of corrected / topRight latitude of initial
    }
	
	# -- AT THIS POINT --
	# @dScaleX/Y contain: topRight longitude/latitude of corrected - initial
	# @dRot contains: If NOT DIRECT then, rotation of corrected - initial. If DIRECT then, rotation of corrected.
	# @dTransX/Y contain: If NOT DIRECT then, X contains avg east-west translation from before north/south translation, Y contains north-south translation. If DIRECT then, center longitude/latitude of corrected.
	
    else # If $CORRECT == lookAt
    {
      # Only updating the lookAt values for the corrected files.
      my @latLonBoxCorrected = getLatLonBox($file);
      my $initialFile = $file . "";
      $initialFile =~ s/\/completed\//\/initial\//;
      printKML($initialFile, \@latLonBoxCorrected);
      # Doing this prints the automated file.
      # The initial filepath is just a formality to make sure the printing happens in the automated folder.
    }
  }
  
  # --END OF FOR LOOP--

  if ($CORRECT ne "lookAt")
  {
    # Now calculate the y-intercept of dTranslate, dRotate, and dScale

    # Also calculate the avg. slope of the changes
    #my @printThisArray = getInterceptsAndSlopes(\@dTransX, \@dTransY, \@dRot, \@dScaleX, \@dScaleY, \@correctedFiles);
    #print "@printThisArray\n";

    my @dTranslate = (mean(@dTransX), mean(@dTransY));
    my $dRotate = avgRotationValues(@dRot);
    my @dScale = (mean(@dScaleX), mean(@dScaleY)); 
    
    my @regressionValues = (); # This will be used by the linear and quadratic corrections to store their deviously different values.
	# Apply Linear correction
    if (index($CORRECT, 'linear') != -1) 
    {
      @regressionValues = getInterceptsAndSlopes(\@dTransX, \@dTransY, \@dRot, \@correctedFiles);
	  # @regressionValues will have: (y-int of X translation, y-int of Y trans, y-int of rotation, avg slope of X translations, avg slope of Y translations, avg slope of rotations, y-int of time)
    }
	# Apply Quadratic regression
    elsif (index($CORRECT, 'quadratic') != -1)
    {
      @regressionValues = getQuadraticRegressions(\@dTransX, \@dTransY, \@dRot, \@correctedFiles);
	  # @regressionValues will have: (coefficient of transX, coefficient of TransY, coefficient of Rotation)
    }
	# Apply Sinusoidal regression
    elsif (index($CORRECT, 'sinusoidal') != -1)
    {
      @regressionValues = getSinusoidalRegressions(\@dTransX, \@dTransY, \@dRot, \@correctedFiles);
    }

    # Now compute the mean changes and apply them to each initial file (except for the complete ones)
    my @initialFiles = <$initialPath*.kml>;
    print "Correcting " . scalar(@initialFiles) . " initial files in " . $initialPath . "\n";
    foreach my $file (@initialFiles)
    {
      #print "Correcting initial file: $file\n";
      # apply corrections to the initial files and the automated files will pop-out later
      # We no longer ignore the completed folder
        # completedImages need to have their lookAt values updated too, so we'll correct those again.
      applyCorrection(\@dTranslate, $dRotate, \@dScale, $file, \@regressionValues);
    }
  }
}

# search array for an element (strings)
# Nobody calls this function :(
sub containsString
{
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

# apply a correction to an initial file and print to a new file
# takes in the average deltaTranslate, Rotate, and Scale as well as the initial filepath
sub applyCorrection
{
  my @dTranslate = @{ $_[0] };
  my $dRotate = $_[1];
  my @dScale = @{ $_[2] };
  my $filepath = $_[3]; # the KML file
  my @regressionData = @{ $_[4] };

  my @newLatlonbox = calcLatLonBox(\@dTranslate, $dRotate, \@dScale, $filepath, \@regressionData); 
  printKML($filepath, \@newLatlonbox);
}


# Requires the input of the avg change in translation, rotation, and size, as well as the old latlonbox.
# translation and scale are x, y  arrays
# This gives back the newLatLonBox with the avg changes applied
sub calcLatLonBox
{
  my @dTranslate = @{ $_[0] };
  my $dRotate = $_[1];
  my @dScale = @{ $_[2] };
  my $filepath = $_[3]; # KML File
  my @regressionData = @{$_[4]};

  # get the individual .kml data for this initial file
  my @data = getLatLonBox($filepath);
  # @data now contains: north, south, east, west, rotation coordinates of the KML file

  # get the centeredData
  # 0 is the distance array (x,y) to the corner (top right)
  # 1 is center point (array, (x,y))
  # 2 is rotation value 
  my @centeredData = changefromlatlonbox(@data);  
  
  # Scale: Everyone applies scales the same way
  my @cornerVector = @{ $centeredData[0] }; 
  $cornerVector[0] *= $dScale[0]; # multiply x value by scale
  $cornerVector[1] *= $dScale[1]; # multiply y value by scale
  
  $centeredData[0] = \@cornerVector;  # $centeredData[0] now contains the reference to the SCALED topright vectors.
  
  if ($CORRECT eq 'constant')
  {
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
	# $centeredData[1] now contains the reference to the increased center (x, y)
  }
  else # $CORRECT is either linear, quadratic, or sinusoidal
  {
    my $timeValue = getImageTime($filepath);

    if (index($CORRECT, 'linear') != -1)
    {
      # obtain regression data variables
	  # They contain the y intercepts and slopes of the longitude, latitude, and rotation.  $avgTime is the y-intercept of time
      my ($dTransX, $dTransY, $dRotation, $dTransXSlope, $dTransYSlope, $dRotateSlope, $avgTime) = @regressionData; 
      
      #rotate
      my $rotationValue = ($dRotation + ($timeValue - $avgTime) * $dRotateSlope);
      
      #translate
      my @center = @{$centeredData[1]};
      my $changeX = $dTransX + ($timeValue - $avgTime) * $dTransXSlope;
      my $changeY = $dTransY + ($timeValue - $avgTime) * $dTransYSlope;
      
      if (index($CORRECT, 'Direct') != -1)
      {
        $centeredData[2] = $rotationValue;

        $center[0] = $changeX;
        $center[1] = $changeY;          
      }
      else
      {
        $centeredData[2] += $rotationValue;

        $center[0] += $changeX;
        $center[1] += $changeY;       
      }

      # store the translation changes, $centeredData[1] now contains the updated centers.
      $centeredData[1] = \@center;      
    }
    elsif (index($CORRECT, 'quadratic') != -1)
    {
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
      
      if (index($CORRECT, 'Direct') != -1)
      {
        $centeredData[2] = $rotationValue;

        $center[0] = $changeX;
        $center[1] = $changeY;          
      }
      else
      {
        $centeredData[2] += $rotationValue;

        $center[0] += $changeX;
        $center[1] += $changeY;       
      }
      
      # store the translation changes
      $centeredData[1] = \@center;      
    }
    else # sinusoidal regression
    {   
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
      
      if (index($CORRECT, 'Direct') != -1)
      {
        # move image to place along regression line, where we calculate it should be
        $centeredData[2] = $rotationValue;

        $center[0] = $changeX;
        #$center[0] = $center[0]; # don't change X coordinate at all
        $center[1] = $changeY;          
      }
      else
      {
        $centeredData[2] += $rotationValue;

        $center[0] += $changeX;
        $center[1] += $changeY;       
      }
      
      # store the translation changes
      $centeredData[1] = \@center;    
    }
  }
  
  # -- AT THIS POINT --
  # @centeredData contains 3 items: (the reference to the SCALED topright vectors, the TRANSLATED center, the TRANSLATED rotation)

  # if the translation is more than 180 degrees, then we know that this crossed the international date line after it moved. So we need to keep the data as it is for now, but will pass a boolean ($cross) saying that the image crossed the date line after it was corrected
  my $cross = 0;
  if (abs($dTranslate[0]) > 180)
  {
    $cross = 1;
  }

  # Now make this a Lat Lon Box again
  # Recall that it gets you back North, south, east, west, rotate
  my @boxedData = changetolatlonbox(@centeredData, $cross); # subroutine found in lat_long_box_changes.pl

  # This is actually what we want to return, so...
  return @boxedData;
}

# This gets you the lat lon box (new or old) from a .kml file
# Please give a .kml filepath for me to read too, thanks.
# The returned array gives you a north, south, east, west, and rotation value
sub getLatLonBox
{
  my ($filepath) = @_; # @_ contains $file/$initialFile from line 132
  
  # A filehandle named KMLFILE is created. The contents of $filepath will come through KMLFILE
  open (KMLFILE, $filepath) or die "Could not open $filepath";
  
  my $seenNorth = 0;
  my $line = "";
  
  # This loop keeps on iterating until the <north> tag is seen.
  until ($seenNorth)
  {
    $line = <KMLFILE>;
    
    chomp($line); # apparently, they tend to end with \n, so we get rid of it, though we don't have to
    
    my $index = index($line, "<north>"); #this is the index we need. Returns the index of the first occurrence of <north>
    if ($index != -1)
    {
      $seenNorth = 1; # north is found, stop the loop. now we can just read 5 lines of data
    }
  }
  
  # After the until loop: $index contains

  
  # We are currently on the <north> line
  # the next 5 lines of data contain the north (0), south (1), east (2), west (3), and rotation (4) values in that order. 
  my @data = (); ### The data array contains the coordinates.
  for (my $i = 0; $i < 5; $i++)
  {
    # Take the substring of the number between the < > and </ > tags
	### substr parameters consist of: substr(string, initial position, length)
    my $string = substr($line, index($line, ">")+1, index($line, "</") - index($line, ">") - 1); # gets whatever is between the <tag>...</tag>
    $data[$i] = $string; 
    $line = <KMLFILE>; #get the next line
  }
  
  # If the picture so happens to cross the international date line here (if the eastern side of the picture has coordinates that are less than those on the western side), then we will add 360 degrees to the eastern side for the rest of the correction step
  if (cross_date_line($data[2], $data[3])) #cross_date_line subroutine is found in lat_long_box_changes.pl file
  {
    $data[2] += 360;
  }

  # We are done with the file.
  close(KMLFILE);

  return @data;
}

# -- This subroutine is used for LINEAR correction --
# returns the y-intercepts and best fit slopes for the translate, rotate, and scale adjustments
# The inputs must be indexed together (in the same order)
# y-intercept... how to find that?
  # involves finding average time and average values
  # This is not a true y-intercept at time 0
  # These are the y-intercepts, make sure to record the time value
# average slope... how to find that?
  # involves subtracting y-intercept from the current value and dividing by the time for the current file.
  # average the individual slopes for the overall slope. compare to the avg
  # apply the slope change after comparing the time to the average
# avgTranslateX, avgTranslateY, avgRotate, avgScaleX, avgScaleY, slopeTranslateX, slopeTranslateY, slopeRotate, slopeScaleX, slopeScaleY, avgTime)  
sub getInterceptsAndSlopes
{ 
  my @translateX = @{$_[0]};
  my @translateY = @{$_[1]};
  my @rotate = @{$_[2]};
  my @correctedFilepaths = @{$_[3]};
  
  # Saving time with these base cases
  if (scalar(@correctedFilepaths) >= 2) # two or more images were corrected, can use linear fit
  {
    # first calculate the averages for the intercept
    my @timeValues = ();
    foreach my $correctedFilepath (@correctedFilepaths)
    { 
      push(@timeValues, getImageTime($correctedFilepath));
    }
	
	# @timeValues now contains: the time in seconds of every correctedFilePath
	
    my $avgTime = mean(@timeValues); # the average time of the correctedFilePath 
    my $avgTranslateX = mean(@translateX);
    my $avgTranslateY = mean(@translateY);
    my $avgRotate = mean(@rotate);
    
    # Now calculate the individual slopes with respect to that intercept to get the average slope
    my @slopesTranslateX = ();
    my @slopesTranslateY = ();
    my @slopesRotate = ();
    for (my $i = 0; $i < scalar(@correctedFilepaths); $i++)
    {
      my $time = getImageTime($correctedFilepaths[$i]);
      push(@slopesTranslateX, ($translateX[$i] - $avgTranslateX) / ($time - $avgTime)); # ( current value (translateX[$i]) - y intercept(avgTranslateX)  ) / time for current file
      push(@slopesTranslateY, ($translateY[$i] - $avgTranslateY) / ($time - $avgTime)); # ( current value (translateY[$i]) - y intercept(avgTranslateY)  ) / time for current file
      push(@slopesRotate, ($rotate[$i] - $avgRotate) / ($time - $avgTime)); # ( current value of rotation - y intercept (avg rotation) ) / time for current file
    }
	
	# -- AT THIS POINT --
	# @slopesTranslateX/Y contain: the slope of every x/y translation
	# @slopesRotate contains: the slope of every rotation 
	# $avgTranslateX/Y contain: the y-intercept of X/Y translation
	# $avgRotate: y-intercept for rotation
	# $avgTime: y-intercept for time of correctedFilePath
    
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
  # translateX/Y will contain: center of corrected files
  my @translateX = @{$_[0]}; 
  my @translateY = @{$_[1]};
  my @rotate = @{$_[2]}; # rotation of corrected files
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
  my @deltaYValues = @{$_[0]}; # contains center of translateX/Y
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
  my @yVals = @{$_[0]}; # contains center translate X/Y
  my @correctedFilepaths = @{$_[1]};
  # points are i, j, k from previous subroutine
  my $point1 = $_[2];
  my $point2 = $_[3];
  my $point3 = $_[4];
  
  my $x1 = getImageTime($correctedFilepaths[$point1]);
  my $x2 = getImageTime($correctedFilepaths[$point2]);
  my $x3 = getImageTime($correctedFilepaths[$point3]);
  # $y1,2,3 will contain the center of the three images provided
  my $y1 = $yVals[$point1];
  my $y2 = $yVals[$point2];
  my $y3 = $yVals[$point3];
  
  # Calculate the coefficients for these 3 points. This is the exact quadratic curve for these 3 points
  my $a = (-1 * $x3 * ($y1 - $y2) + $x2 * ($y1 - $y3) - $x1 * ($y2 - $y3)) / (($x1 - $x2) * ($x1 - $x3) * ($x2 - $x3));
  my $b = ($x3**2 * ($y1 - $y2) - $x2**2 * ($y1 - $y3) + $x1**2 * ($y2 - $y3)) / (($x1 - $x2) * ($x1 - $x3) * ($x2 - $x3));
  my $c = ($x3 * ($x2 * ($x2 - $x3) * $y1 - $x1 * ($x1 - $x3) * $y2) + $x1 * ($x1 - $x2) * $x2 * $y3) / (($x1 - $x2) * ($x1 - $x3) * ($x2 - $x3));
  
  return ($a, $b, $c);
}

# This asks getImageID() for the ID and calculates the time value of the image
# As a result, we get the actual time in seconds
# Image ID is 9 digits long DDDHHMMSS (with 3 digits for day, 2 for hour, 2 for minute, and 2 for seconds)
# Image ID can also be 8 digits for the STS DDHHMMSS. Luckily, since I calculate 'the rest' as days, the formula still works!
# Example ID: 114014732. 114 = day, 01 = hour, 47 = minute, 32 = seconds.
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
  
  return $time; # time is in seconds
}

# This gets you the image id from the inputted .kml filepath
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
	  # Example ID: ISS017.ESC1.114014732, 114014732 is the Image ID.
      $string = substr($string, index($string, ".")+1);
      $string = substr($string, index($string, ".")+1);
      
       # This is our $imageID
      return $string;
    }
  }
  die "Did not find an imageid in $filepath\n";
}

# This prints out the new .kml file, given the filepath to the old .kml file and the new latlonbox data
# See a .kml file for the approximate syntax. This should be correct though.]
# Make sure that 'initial' is the only folder called 'initial' in your filepath though.
sub printKML
{
  my $filepath = $_[0];
  my @data = @{ $_[1] };

  my $newFilepath = $filepath . ""; # Make a copy of the original filepath
  $newFilepath =~ s/\/initial\//\/automated\//; # replaces the string '/initial/' with '/automated/' in the filepath

  # begin by reading from the old .kml file and copying to a new .kml file until we reach "<LatLonBox>"
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

# gets rotation value to within 0 and 360
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
