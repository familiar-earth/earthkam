#!/usr/bin/perl -w

use DataGet;

$msn = $ARGV[0];
$orb = $ARGV[1];

###%%% INSTALLER SET CONSTANTS
$PUBLIC_WEB_ROOT = "/var/www/html";
$SERVER_NAME = "ssvekdev.jpl.nasa.gov";
$CGI_ROOT = "/var/www/cgi-bin";
$INSTALLATION_ROOT = "datasys/ek_summer";
$KML_ROOT = "ek/ek_summer/kml_files";
###%%%

$IMAGE_ROOT = "$PUBLIC_WEB_ROOT/ek/imgs";

$kml_file_dir = "$PUBLIC_WEB_ROOT/$KML_ROOT";
$IMAGE_ROOT =~ /$PUBLIC_WEB_ROOT\/(.*)$/;
$web_image_root = "http://$SERVER_NAME/$1";

$msn .= "%";
if ($orb eq '' || $orb eq 'ALL'){
    $CMD1 = "select filepath, imagedate, frmwidth, frmheight, altitude, cenlat, cenlon, newclat, newclon, newwidth, newrotation, orbit, lookdir, locname, divavisible, compstat from ekImages where filepath like \'$msn\' order by filepath";
}
else {
    $CMD1 = "select filepath, imagedate, frmwidth, frmheight, altitude, cenlat, cenlon, newclat, newclon, newwidth, newrotation, orbit, lookdir, locname, divavisible, compstat from ekImages where filepath like \'$msn\' and orbit=\'$orb\' order by filepath";
}
print "Cannot perform $CMD1 properly\n" unless(&DataGet::dblookup($CMD1, \@RESULTS));
foreach $image (@RESULTS){
    ($fp, $imgd, $wid, $hght, $alt, $clat, $clon, $nclat, $nclon, $nwid, $nld, $orb, $ld, $loc, $visible, $cs) = split (/\t/, $image);

    #print "fp is $fp , clat is $clat , clon is $clon , lookdir is $ld  ..\n nclat is $nclat nclon is $nclon and nld is $nld\n";
    if ($clat==0 && $clon==0){
        #print "skipping $fp , clat is $clat , clon is $clon ,  vis is $visible and compstat is $cs ..\n";
        next;
    }
    if ($clat eq "" || $visible eq "X" ){
        #print "skipping $fp ,vis is $visible and compstat is $cs ..\n";
        #next;
    }
    $completed = 0;
    if (($nclat ne "" && $nclat != 0) && ($nclon ne "" && $nclon != 0) && ($nld ne "" && $nld != 0) && ($nwid ne "" && $nwid != 0)){
        $completed = 1;
    }
    if ($completed){
        @states = ('initial', 'completed');
    }
    else {
        @states = ('initial');
    }
    foreach $state (@states){
        
        if ($state eq "completed"){
            $clon = $nclon; 
            $clat = $nclat; 
            $ld = $nld; 
            $wid = $nwid;
            $hght = (2 * $wid/3);
        }
        ($mid,$esc,$met) = split(/\./, $fp);
        $outdir = $kml_file_dir."/".
            $mid.$esc."/".$orb."/".$state."/";
    #print "Output File is: ".$outdir."\n";

        #print "continuing with  $fp ,\n clat is $clat , clon is $clon \n";
        
        # we need to make the folders individually to give them all the right permissions
        $outdir = $kml_file_dir . "/" . $mid.$esc . "/";
        if (! -d $outdir) {
          `mkdir -m 770 $outdir`;
        }
        $outdir = $outdir . $orb . "/";
        if (! -d $outdir) {
          `mkdir -m 770 $outdir`;
        }
        $outdir = $outdir . $state . "/";
        if (! -d $outdir){
            `mkdir -p -m 770 $outdir`;
        }
#        system("chmod $kml_file_dir/$mid.$esc")
        $outfile = $outdir."/ek_".$fp.".kml";
        if (( -s $outfile) && (! $overwrite)){
            #print "skipping $fp ..\n";
            next;
        }
        else {
            if ( -s $outfile){
                `rm -f $outfile`;
            }
            open OUT, ">$outfile" or die "Can't open $outfile for write, $!\n";
            print OUT "<\?xml version=\"1.0\" encoding=\"UTF-8\"\?>\n";
            print OUT "<kml xmlns=\"http://earth.google.com/kml/2.2\">\n";
            $clatR = $clat * 3.1415192653 / 180;
            $cosCLat = cos($clatR);
            $radius_earth = 6378;
            $circ_earth = $radius_earth * 2 * 3.141592653;
            $delta_lon = abs($wid * 0.5/($circ_earth * $cosCLat) * 360);
            $delta_lat = ($hght * 0.5/$circ_earth) * 360;
            $upperLat = $clat + $delta_lat;
            $lowerLat = $clat - $delta_lat;
            $rightLon = $clon + $delta_lon;
            $leftLon = $clon - $delta_lon;
            ($msn,$esc,$met)=split(/\./, $fp);
            $msnid = $msn.$esc;
            $msnFolderDescrip = "Overlays of images from $msnid, that were taken in $missionDate{$msnid} $missionString{$msnid}";
            $msnFolderName = "$msnid Ovelays";
            $msnFolderState = 0;
            $image_url="$web_image_root/".$msnid."/".$met."/IMAGE.JPG";
            $overlayDescrip = "Overlay of $fp, located at or near $loc, taken on $imgd";
            $overlayDescrip =~ s/&/and/g;
            $range = $alt * 1000;
            $overlayName = $fp;
            $rot = 360 - $ld;
            
            print OUT "        <GroundOverlay>\n";
            print OUT "          <name>$overlayName</name>\n";
            print OUT "          <description>$overlayDescrip</description>\n";
            print OUT "          <LookAt>\n";
            print OUT "            <longitude>$clon</longitude>\n";
            print OUT "            <latitude>$clat</latitude>\n";
            print OUT "            <range>$range</range>\n";
            print OUT "            <tilt>0</tilt>\n";
            print OUT "            <heading>0</heading>\n";
            print OUT "          </LookAt>\n";
            print OUT "          <Icon>\n";
            print OUT "            <href>$image_url</href>\n";
            print OUT "          </Icon>\n";
            print OUT "          <LatLonBox>\n";
            print OUT "            <north>$upperLat</north>\n";
            print OUT "            <south>$lowerLat</south>\n";
            print OUT "            <east>$rightLon</east>\n";
            print OUT "            <west>$leftLon</west>\n";
            print OUT "            <rotation>$rot</rotation>\n";
            print OUT "          </LatLonBox>\n";
            print OUT "        </GroundOverlay>\n";
            print OUT "</kml>\n";
            close OUT;
            system("chmod 777 $outfile");
        }
    }
}






