
EarthKAM Readme

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






I. A Quick Introduction

  This readme attempts to give an introduction and overview to current
  EarthKAM system. The purpose of this document is to serve as a guide
  to working on/with the source code of EarthKAM.

  The EarthKAM image correction process has been worked on by many students now.
  From here on out this readme should be included with the source code. This
  document is in no way a substitution for reading the source code. It only
  serves as a primer and a reference when needed.

II. Description of EarthKAM files

  II.A constants.pm

    Module to hold constants for other Perl modules.

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

III. Format of Source Code

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
########################################################################
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
### Description ########################################################
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
### Imports ############################################################

use something;
use somethingelse;

### CONSTANTS ##########################################################

$MY_CONSTANT = "This should not change";
$Filepath = "/path/to/file";

########################################################################

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
