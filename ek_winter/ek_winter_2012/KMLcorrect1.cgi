#!/usr/bin/perl -w
################################################################################
#
# Co-Author(s):
#   Carson McNeil
#   David Choy
#   Stephanie Tsuei
#   Alex Fandrianto
#   Allen Eubank
#   John Uba
#
### Imports ####################################################################

use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use DataGet;
use List::Util qw(min);

### Constants ##################################################################

$PUBLIC_WEB_ROOT = "/var/www/html";
$SERVER_NAME = "ssvekdev.jpl.nasa.gov";
$CGI_ROOT = "/var/www/cgi-bin";
$INSTALLATION_ROOT = "datasys/ek_summer";
$KML_ROOT = "ek/ek_summer/kml_files";
$PROGRAM_ROOT = "$CGI_ROOT/$INSTALLATION_ROOT";
$KML_ROOT = "$PUBLIC_WEB_ROOT/$KML_ROOT";
$IMAGE_ROOT = "$PUBLIC_WEB_ROOT/ek/imgs";
$kml_file_dir = "$KML_ROOT";
$IMAGE_ROOT =~ /$PUBLIC_WEB_ROOT\/(.*)$/;
$image_root = "http://$SERVER_NAME/$1";
$KML_ROOT =~ /$PUBLIC_WEB_ROOT\/(.*)$/;
$kml_dir_web = "http://$SERVER_NAME/$1";
$PROGRAM_ROOT =~ /$CGI_ROOT\/(.*)$/;
$own_url = "http://$SERVER_NAME/cgi-bin/$1/KMLcorrect1.cgi";

################################################################################

# Default place to look for images is the automated folder. Otherwise,
# it will be sent as a parameter.
$correction_stage = "automated";

if (param('stage')) {
  $correction_stage = param('stage');
}


my $informationQuery = "SELECT DISTINCT msnCode, orbit FROM ekImages";
my @flightData = ();
&DataGet::dblookup($informationQuery, \@flightData);

# take all the missions and orbits and create a hash table of orbits in each mission
my %missionCodes = ();
foreach my $val (@flightData) {
  my @values = split(/\t/, $val);
  if (exists $missionCodes{$values[0]}) {
    push @{$missionCodes{$values[0]}}, $values[1];
  }
  else {
    $missionCodes{$values[0]} = [$values[1]];
  }
}

my @codes = sort keys %missionCodes;
my %missionLabels = ();
foreach my $val (@codes) {
  $missionLabels{$val} = $val;
}

print header;
print start_html("KML Corrector"),
      h1("KML Correct"),br,
      i("Please select the mission and orbit(or \"All\" if desired.)"),
      br,br,start_form;

# if no mission has been selected, present menu for it
if (not param('msnCode')) {
   print "Mission Code: ",
          popup_menu(-name => 'msnCode',
          -values => \@codes,
          -default => @codes[0],
          -labels => \%missionLabels),
          submit,hr;
}

# if mission has been selected and orbit hasn't, 
# show mission and present menu for orbit
elsif (not param('orbit')) {

  print "Mission Code is: ", param('msnCode'),
        hidden(-name => 'msnCode', -value => param('msnCode')), br;

  my @orbits = sort @{$missionCodes{param('msnCode')}};
  unshift @orbits, "ALL";
  my %orbitLabels = ();

  foreach my $val (@orbits) {
    $orbitLabels{$val} = $val;
  }

  print i("Please select an orbit:"), br,
        "Orbits: ", popup_menu(-name => 'orbit',
        -values => \@orbits,
        -default => 'ALL',
        -labels => %orbitLabels), submit, hr;
}

# if both mission and orbit are chosen, show what was selected and show images 
# from those orbit(s)
else {
  my $missionCode = param('msnCode');
  my $orbitCode = param('orbit');
  print "Mission is: ", $missionCode, br,
        "Orbit is: ", $orbitCode, hr;
  my $query = '';

  if ($orbitCode eq 'ALL') {
    $query = "SELECT filepath, orbit, compstat FROM ekImages WHERE msnCode='$missionCode';";
  }
  else {
    $query = "SELECT filepath, orbit, compstat FROM ekImages WHERE msnCode='$missionCode' AND orbit='$orbitCode';";
  }

  system("perl create_GoogleEarthOverlays.pl $missionCode $orbitCode");

  my @imageData = ();
  &DataGet::dblookup($query, \@imageData);

  print h4("Download KML files below"), i("Please correct as many KML files as possible"),
        br, i("Do not change any filenames"), br
        i("After you have corrected the KML files using Google Earth, you can upload them with the ").
        a({-href => "KMLupload.cgi"}, "Extrapolation Tool").i(".").br.
        "If you want to see initial images (without automated corrections), click ".
        a({-href => "$own_url?msnCode=$missionCode&orbit=$orbitCode&stage=initial"}, "here").".";

  my $i = 0;
  my @data = ();
  while ($i <= $#imageData) {

    my @contents = ();

    for (my $j = $i; $j <= min($i + 3, $#imageData); $j++) {

      my ($filePath, $orbit, $compStat) = split(/\t/, $imageData[$j]);
      my ($msn, $src, $id) = split(/\./, $filePath);

      unless (<$kml_file_dir/$msn$src/$orbit/automated/*>) {
        $correction_stage = "initial";
      }

      my $url = "$image_root/$msn$src/$id/level1.jpg";
      my $kml_url = "$kml_dir_web/$msn$src/$orbit/$correction_stage/ek_$msn.$src.$id.kml";
      my $updated = "";

      if ($compStat eq 'final') {
        $kml_url = "$kml_dir_web/$msn$src/$orbit/completed/ek_$msn.$src.$id.kml";
        $updated = font({-color => "Red"},"COMPLETED");
      }
      else {
        $kml_url = "$kml_dir_web/$msn$src/$orbit/initial/ek_$msn.$src.$id.kml";
      }
      push @contents, table(Tr({-align=>CENTER,-valign=>TOP},
                      [td(a({-href => $kml_url},"<img src=\"$url\" />")),
                      td(a({-href => $kml_url},$filePath)),
                      td($updated)]));
    }

    push @data, td(\@contents);
    $i += 4;
  }

  print table({-border=>undef}, Tr(\@data));

}

print end_form, end_html;
