#!/usr/bin/perl -w
###############################################################################
#
# Co-Author(s):
#   Carson McNeil
#   David Choy
#   Stephanie Tsuei
#   Alex Fandrianto
#   Allen Eubank <adeubank@gmail.com>
#   John Uba
#
### Description ###############################################################
#
# A web application that uploads corrected KML files. It stores them in the 
# KML file's corresponding mission/orbit/completed directory. After the files 
# have been uploaded the corrected values of the KML file are sent to the 
# database. Then it begins the correction process by calling the
# updateKMLFile.pl with the filepath to the completed directory with the newly 
# uploaded files.
#
### Imports ###################################################################

use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use DataGet;

### CONSTANTS #################################################################

$PUBLIC_WEB_ROOT = "/var/www/html";
$SERVER_NAME = "ssvekdev.jpl.nasa.gov";
$CGI_ROOT = "/var/www/cgi-bin";
$INSTALLATION_ROOT = "datasys/ek_summer";
$KML_ROOT = "ek/ek_summer/kml_files";
$kml_file_dir = "$PUBLIC_WEB_ROOT/$KML_ROOT";
$DOWNLOAD_TOOL_URL = "http://$SERVER_NAME/cgi-bin/$INSTALLATION_ROOT/KMLcorrect1.cgi";
my $return_url = "";
$CGI::POST_MAX = 1024 * 1024;  # maximum upload filesize is 1MB

###############################################################################

print header;
print start_html("KML Uploader"),
    h1("KML Upload"),br,
    i("Please upload corrected KML files"),br,br,
    start_multipart_form;

# select total number of files to upload
if (not param('numberOfFiles')) {
  print "Select number of files to upload: ",
          textfield(-name => 'numberOfFiles'),
          submit(-value => "Enter"),hr;
}

# if number has been given, show that many boxes to upload
elsif (param('numberOfFiles')) {
  print "Number of files to upload: ", param('numberOfFiles'), br;
  for (my $i = 0; $i < param('numberOfFiles'); $i++) {
    print "Enter a filename, or click on the browse button to choose one: ",
              filefield(
                  -name      => "file$i",
                  -size      => 40,
                  -maxlength => 80), br;
  }
  print br, submit(-value => "Upload the files");

}
print end_form;

#
# Look for uploads that exceed $CGI::POST_MAX
#
if (!param('filename') && cgi_error()) {
    print cgi_error();
    print p("The file you are attempting to upload exceeds the maximum allowable file size."),
        p("Please refer to your system administrator");
    print hr, end_html;
}

#
# check for correct KML file name format
#
while (param("file$i")) {
  my $name = param("file$i");
  if ($name !~ m/ek_ISS(\d){3}\.ESC(\d){1}\.(\d){9}\.kml/) {
	print p("Hold it! You are trying to upload a KML file whose format is not
          "." like ek_ISS###.ESC#.#########.kml"),
        p("Please refresh the page and try again.");
    print hr, end_html;
  }
}

#
# Upload the file
#
if (param('file0')) {

  my $i = 0;
  my %orbitMap = ();
  my $source = "";
  my $msnCode = "";
  while (param("file$i")) {
    my $name = param("file$i");
    $name =~ /ek_(.*)\.kml/;
    my $query = "SELECT filepath,orbit FROM ekImages WHERE filepath=\'$1\';";
    my @orbits = ();
    &DataGet::dblookup($query, \@orbits);
    my @data = split(/\t/, @orbits[0]);
    my $orbit = $data[1];
    my $filepath = $data[0];
    my ($msn, $src, $id) = split(/\./, $filepath);

    # push each image's data to a hash table to find total number of orbits
    if (exists $orbitMap{$orbit}) {
      push @{$orbitMap{$orbit}}, $filepath;
    }
    else {
      $orbitMap{$orbit} = [$filepath];
    }
    $msn =~ s/ek_(.*)/$1/g;
    $msnCode = $msn;
    $source = $src;


    save_file("file$i", $orbit);
    # update database (ekImages) with new corrected location data
    `perl updateNewFields.pl $kml_file_dir/$msn$src/$orbit/completed/ek_$filepath.kml WebUser -i`;
    $i += 1;
  }

  my $numberOfOrbits = length(keys %orbitMap);
  my @orbits = keys %orbitMap;
  print "<br>Applying regression to other images.  This will take some time.  Do not close this window!<br><br>";

  if ($numberOfOrbits == 1) {
    # if only one orbit, do regresssion on orbit only
    print "SELECT photoid FROM ekImages WHERE msnCode='$msnCode' AND orbit='$orbits[0]' AND compstat='final' <br>";
    my $query = "SELECT photoid FROM ekImages WHERE msnCode='$msnCode' AND orbit='$orbits[0]' AND compstat='final'";
    my @pictures = ();
    &DataGet::dblookup($query, \@pictures);
    my $i = $#pictures + 1;
    # number of corrected files in orbit gives which regression to do
    $CORRECT = "constant";
    if ($i == 0) {
        print "How are there no corrected images?<br>";
    }
    elsif ($i == 1) {
        $CORRECT = "constant";
    }
    elsif ($i == 2) {
        $CORRECT = "linear";
    }
    elsif ($i == 3) {
        $CORRECT = "quadratic";
    }
    else {
        $CORRECT = "sinusoidal";
    }

    print "perl updateKMLFile.pl $kml_file_dir/$msnCode$source/$orbits[0]/ $CORRECT <br>";
    print  "perl updateKMLFile.pl $kml_file_dir/$msnCode$source/$orbits[0]/ copyCorrected <br><br>";
    `perl updateKMLFile.pl $kml_file_dir/$msnCode$source/$orbits[0]/ $CORRECT`;
    `perl updateKMLFile.pl $kml_file_dir/$msnCode$source/$orbits[0]/ copyCorrected`;
    $return_url = "$DOWNLOAD_TOOL_URL?msnCode=$msnCode&orbit=$orbits[0]";
  }
  else {

    # images from multiple orbits given, so do regression on whole mission
    my $query = "SELECT photoid FROM ekImages WHERE msnCode='$msnCode' AND compstat='final'";
    my @pictures = ();
    &DataGet::dblookup($query, \@pictures);
    my $i = $#pictures + 1;

    # number of corrected files in the mission gives which regression to do
    $CORRECT = "constant";
    if ($i == 0) {
        print "How are there no corrected images?<br>";
    }
    elsif ($i == 1) {
        $CORRECT = "constant";
    }
    elsif ($i == 2) {
        $CORRECT = "linear";
    }
    elsif ($i == 3) {
        $CORRECT = "quadratic";
    }
    else {
        $CORRECT = "sinusoidal";
    }
    `perl updateKMLFile.pl $kml_file_dir/$msnCode$source/ $CORRECT`;
    `perl updateKMLFile.pl $kml_file_dir/$msnCode$source/ copyCorrected`;

    $return_url = "$DOWNLOAD_TOOL_URL?msnCode=$msnCode&orbit=ALL";
  }
  print i("Images done correcting, go back to the ".
          a({-href => $return_url},
          "Download Tool")." to see them and/or correct more.");
}

print end_html;

sub save_file {

  my ($name, $orbit) = @_;
  my ($bytesread, $buffer);
  my $num_bytes = 1024;
  my $totalbytes;
  my $filename = upload($name);
  my $untainted_filename;

  if (!$filename) {
    print p("You must enter a filename before you can upload it");
    return;
  }

  # Untaint $filename

  if ($filename =~ /^([-\@:\/\\\w.]+)$/) {
      # remove any folder heirarchy from filename so we only get filename
      my @pieces = split(/\//, $1);
      $untainted_filename = pop @pieces;
  }
  else {
    die <<"EOT";
    Unsupported characters in the filename "$filename".
    Your filename may only contain alphabetic characters and numbers,
    and the characters '_', '-', '\@', '/', '\\' and '.'
EOT
  }

  if ($untainted_filename =~ m/\.\./) {
    die <<"EOT";
    Your upload filename may not contain the sequence '..'
    Rename your file so that it does not include the sequence '..', and try again.
EOT
  }

  my ($msn, $src, $id) = split(/\./, $untainted_filename);
  $msn =~ s/ek_(.*)/$1/g;

  if (! -d "$kml_file_dir/$msn$src/$orbit/completed/") {
    `mkdir -m 770 $kml_file_dir/$msn$src/$orbit/completed/`;
  }
  my $file = "$kml_file_dir/$msn$src/$orbit/completed/$untainted_filename";

  # If running this on a non-Unix/non-Linux/non-MacOS platform, be sure to
  # set binmode on the OUTFILE filehandle, refer to
  #    perldoc -f open
  # and
  #    perldoc -f binmode
  open (OUTFILE, ">", "$file") or die "Couldn't open $file for writing: $! <br>";

  while ($bytesread = read($filename, $buffer, $num_bytes)) {
    $totalbytes += $bytesread;
    print OUTFILE $buffer;
  }
  die "Read failure" unless defined($bytesread);
  unless (defined($totalbytes)) {
    print "<p>Error: Could not read file ${untainted_filename}, ";
    print "or the file was zero length.<br>";
  }
  else {
    print "<p>File $filename uploaded successfully ($totalbytes bytes) <br>";
  }
  close OUTFILE or die "Couldn't close $file: $! <br>";

}
