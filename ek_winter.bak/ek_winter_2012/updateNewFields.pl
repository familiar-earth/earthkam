#!/usr/bin/perl
# use strict;

# This file updates new fields in the ekImages database for corrected images. Images will not annotate unless the fields are updated. Currently takes in a .kml file as an argument. and a user as an argument 
#Args: 0 - absolute path to overlays directory (required)
#   1 - user (required)
#     2 - single image, orbit, or mission. "-i" for single image, "-o" for orbit, "-m" for mission, (otherwise will update all images in overlays directory)
#          3 - mission id (required unless argument 2 is not given) or 
#   4 - orbit id (required for unless argument 2 "-m" or not given)

# This program assumes that you have in your images in the hierarchy, "Overlays, Mission, Orbit, automated/completed/initial"

$usage = "Usage error. Go read documentation please\n";

require "ekincl.pl";
require "frame_incl.pl";
require "updateNewField_single.pl";

# user, put in your name, or anything you want
my $user = $ARGV[1] . "-GE" or die $usage;

my $cd = `date`;
chomp $cd;

my $option = $ARGV[2] || 0;
my $orbit = $ARGV[4] || 0; # orbit id
my $image; #image filepath
my $mission = $ARGV[3];

if ($option eq "-i")
{
  $image = $ARGV[0]; #image path
}
else
{
  my $overlays = $ARGV[0] or die $usage; # overlays directory
}


if ($option eq "-i") # update data for a single image
{
  update_single($image, $user);
}

if ($option eq "-o") # update data for a whole orbit
{
  # updates all files in the automaticaly corrected directory
  my $directory_auto = $overlays . "/" . $mission . "/" . $orbit . "/automated/";
  opendir(ORBIT_AUTO, $directory_auto) or die "Cannot open" . $directory_auto;
  while (defined($file = readdir(ORBIT_AUTO))) 
  {
    update_single($directory_auto . $file, $user);
  }
  
  # updates all manually corrected files
  my $directory_complete = $overlays . "/" . $mission . "/" . $orbit . "/completed/";
  opendir(ORBIT_COMPLETE, $directory_complete) or die "Cannot open" . $directory_complete;
  while (defined($file = readdir(ORBIT_COMPLETE))) 
  {
    update_single($directory_complete . $file, $user);
  }
}

if ($option eq "-m") # update data for a single mission
{
  @orbits = <$overlays/$mission/*>;
  foreach $orbit (@orbits)
  {
    my $directory_auto = $orbit . "/automated/";
    opendir(ORBIT_AUTO, $directory_auto) or die "Cannot open" .  $directory_auto;
    while (defined($file = readdir(ORBIT_AUTO))) 
    {
      update_single($directory_auto . $file, $user);
    }
    my $directory_complete = $orbit . "/completed/";
    opendir(ORBIT_COMPLETE, $directory_complete) or die "Cannot open" . $directory_complete;
    while (defined($file = readdir(ORBIT_COMPLETE))) 
    {
      update_single($directory_complete . $file, $user);
    }
  }
}

if (!$option) # update data for all images within an overlays folder
{
  @missions = <$overlays/*>;
  foreach $mission (@missions)
  {
    @orbits = <$missions/*>;
    foreach $orbit (@orbits)
    {
      my $directory_auto = $overlays . "/" . $mission . "/" . $orbit . "/automated/";
      opendir(ORBIT_AUTO, $directory_auto) or die "Cannot open" . $directory_auto;
      while (defined($file = readdir(ORBIT_AUTO))) 
      {
        update_single($directory_auto . $file, $user);
      }
      my $directory_complete = $overlays . "/" . $mission . "/" . $orbit . "/completed/";
      opendir(ORBIT_COMPLETE, $directory_complete) or die "Cannot open" . $directory_complete;
      while (defined($file = readdir(ORBIT_COMPLETE))) 
      {
        update_single($directory_complete . $file, $user);
      }
    }
  }
}
