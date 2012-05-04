-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
EarthKAM Readme

Please feel free to add any information I left out or you think important. If
you make any changes please add your name as one of the authors and if you want
include your email(BE PROUD OF YOUR WORK). Also update the LAST MODIFIED date.

LAST MODIFIED: 5/2/2012
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

Author(s):
  Allen Eubank <adeubank@gmail.com>

From Spring 2012,

Table of Contents:

  I. A Quick Introduction

  II. Description of EarthKAM code behind
    II.A constants.pm
    II.B create_GoogleEarthOverlays.pl
    II.C DataGet.pm
    II.D db_test.pl
    II.E distance_calc.pl
    II.F ekincl.pl
    II.G FeatureReader.pm
    II.H frame_incl.pl
    II.I KMLcorrect1.cgi
    II.J KMLupload.cgi
    II.K latLongBoxChanges.pl
    II.L Matrix.pm
    II.M stat_functions.pl
    II.N updateKMLFile.pl
    II.O updateNewFields.pl
    II.P updateNewField_singel.pl

  III. Issues that need attention

  IV. Format of Source Code, A simple Perl style sheet

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

I. A Quick Introduction

  This readme attempts to give an introduction and overview to current
  EarthKAM system. The purpose of this document is to serve as a guide
  to working on/with the source code of EarthKAM.

  The EarthKAM image correction process has been worked on by many students
  now. From here on out this readme should be included with the source code.
  This document is in no way a substitution for reading the source code. It
  only serves as a primer and a reference when needed. The only way to truly
  understand the program is to read the source. This readme should only be used
  as a reference and a guide to working with the EarthKAM system.

  It feels as most of the EarthKAM system was hacked together by students who
  were learning Perl and learning how to design software at the same time.

  *** An important rule of thumb here is if you write lines of code, make sure
      you provide comments for your lines, and if possible a unit test.

  Do not fret, you can stop the madness being done to the EarthKAM system here
  by being a smart programmer and making sure what you code can be understood
  and can be tested.

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

II. Description of EarthKAM files

  II.A constants.pm

    Module to hold constants for other Perl modules.

  II.B create_GoogleEarthOverlays.pl

    Perl script that queries the database and creates KML files based on the
    data from the database. This overwrites all the KML files in the directory.

  II.C DataGet.pm

    Contatins the dblookup method that runs a SQL query on the EarthKam database

  II.D db_test.pl

    Simple db test file that prints all rows from the test table in the
    earthkam database.

  II.E distance_calc.pl

    Distance calculation functions needed by updateKMLFile.pl.

  II.F ekincl.pl

    Used by updateNewFields.pl and updateNewFields_single.pl. The only method
    inside this file is the dbupdate routine. Mostly a jumble of code that is
    indecipherable and unused.

  II.G FeatureReader.pm

    Has no connection to other files. Looks like the beginning of the 
    annotation feature.

  II.H frame_incl.pl

    Contains routines that calculates the corner points of a lat long box.
    Needed by updateNewField_single.pl.

  II.I KMLcorrect1.cgi

    Web application that queries the EarthKam database and is responsible for
    displaying the KML files with their images. This is the first step in
    the correction process. Allows a user to select a mission, then an orbit,
    and displays the associated images. It creates the KML files everytime a
    mission and orbit code are provided.

  II.J KMLupload.cgi

    Web application responsible for uploading corrected KML files to the
    EarthKAM server. A user specifies how many images were corrected, then
    KMLupload.cgi takes the corrected KML files and puts them in the KML files
    in their respective Mission and Orbit's completed directory.

    After all the files have been uploaded, KMLupload.cgi runs the automated
    correction process populating the automated directories under each Mission
    and Orbit given.

  II.K latLongBoxChanges.pl

    Functions that are key to updateKMLFile.pl. It changes the longitude and
    latitude boxes to be represented as a vector. The vector only needs the
    center point, top-right corner point, and the value of rotation.

  II.L Matrix.pm

    Creates a matrix type and allows some Matrix operations between those types.
    Important for the sinusoidal regressions in updateKMLFile.pl

  II.M stat_functions.pl

    Perl script that contains statiscal functions such as max, min, standard
    deviation and mean.

  II.N updateKMLFile.pl

    Script that is used to initiate KML correction process. It calculates and
    applies corrections to KML files. There are four kinds of corrections
    constant, linear, quadratic, and sinusoidal. After correction values are
    calculated it applies these values to all initial kml files and populates
    the automated directory within a mission orbit.

  II.O updateNewFields.pl

    Used by KMLupload.cgi, it updates the EarthKAM database with the corrected
    values in a given orbit after they are uploaded back to the EarthKAM server.

  II.P updateNewField_singel.pl

    Updates the database with the corrected values for one image.


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

III. Issues that need attention

  Many issues can be found by searching through the source code for the text
  "TODO". These are issues that were found but were not solved. Most are small
  and not major, for example adding a clearer documentation for a function.

  NOTE: Issues are not ordered by priority.

  - Restructure updateKMLFile.pl so that it isn't some massive if-else if
    branch when doing a certain type of correction. Make the correction types
    their own sub routines. This will increase testability and increase cohesion

  - Adding a regular expression checking when uploading KML files. At the moment
    the files are not checked and files that will not fit the required format
    can be uploaded causing run time errors.

  - Check if the corner points are being calculated correctly in frame_incl.pl

  - Regression and unit tests. This is to automate that the EarthKAM image
    correction process is functioning properly and new additions do not break
    anything. Currently there is only a test for accessing the test database.
    
  - Refractor frame_incl.pl. This file seemed rushed and not tested. The code
    is inconsistent with the rest of the system. It is not reusing code where
    it could.
    
  - Sinusoidal regression is broken, refractor code to not allow this type of
    correction.

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

IV. Format of Source Code

  An example template of a Perl file for EarthKAM, this is not a strict
  template but it is to serve a guide for consistent formatting between
  all files. As the system has been handed down between many programmers,
  and this template should serve as an outline to making changes to the
  source code.

  Indenting is two spaces, not a TAB.

  Please try and keep each line of code less than 80 characters long.

  Use this example perl file as an outline to writing code to try and
  keep consistent formatting.

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
#   YourName Here <if_you_want@addyouremail.here>
#
### Description ###############################################################
#
# A simple Perl style sheet, this part describes the purpose of this
# Perl module.
#
#   param[0] DataType
#             A short description of my parameter.
#
#   param[1] DataType
#             A short description of my parameter.
#
### Imports ###################################################################

use something;
use somethingelse;

### CONSTANTS #################################################################

$MY_CONSTANT = "This should not change";
$Filepath = "/path/to/file";

###############################################################################

$foo = 1;
$bar = 0;

# this is comment
if ($foo) {
  $bar = $foo + $bar;
}
else if ($bar < $foo) {
  print "Please follow consistent formatting.";
}

# Let's call a sub routine that does something.
someFunctionThatDoesSomething($foo, $bar);

#
# A short description of what someFunctionThatDoesSomething is all about
# This function is just an example, returns the sum of the two
# parameters passed in.
#
#   param[0] DataType
#            a short description of my parameter.
#
#   param[1] DataType
#            a short description of my parameter.
#
#   return DataType
#          a short description of my return value.
#
sub someFunctionThatDoesSomething {
  my @variable = @_;
  my $returnValue = 0;

  foreach my $var (@variable) {
    $returnValue += $var;
  }

  return $returnValue;

}

# This makes sure that my Perl script will always return a true to
# the caller. The default value is false.
1;
