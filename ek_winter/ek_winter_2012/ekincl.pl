################################
# SET LAUNCH TIME AFTER LAUNCH #
################################
#use Time::JulianDay;  
#$Launch_sec  = 00;
#$Launch_min  = 4;
#$Launch_hr   = 17;
#$Launch_day  = 11;
#$Launch_mth  = 02;
#$Launch_yr   = 2000;
#ISS3 TEST MAY 15 ISS011 YR 2001 DAY 100 TO 199
# DAY 100 CORRESPONDS TO APRIL 10TH 2001
$Launch_sec  = 00;
$Launch_min  = 00;
$Launch_hr   = 00;

###%%% INSTALLER SET CONSTANTS
$DB_NAME = "earthkam_test";
$DB_HOST = "ssvekdev";
$DB_USER = "ssvekdev";
$DB_PASSWD = "ssvekdev";
###%%%

$jd_1=`date -u +%j`;
#$hundreds_day = $conf{hdoy}."00";
#$jd=$jd_1 + $hundreds_day;
#($Launch_yr, $Launch_mth, $Launch_day) = inverse_julian_day($jd);

#$Launch_mth  = 04;
#$Launch_yr   = $conf{year};
#$doy = `date -u +%j`;
#chomp($doy);
#($hdoy, $tdoy, $odoy) = split(/ */,$doy); 

# poke the environment for oracle
#$ENV{TWO_TASK}='ds';
#$ENV{ORACLE_HOME}='/u01/app/ocacle/product/8.1.5';
#$ENV{ORACLE_PATH}='/u01/app/oracle/product/8.1.5/bin';
$F0='/misc/netscape/passwords/earthkam/user.txt';
$F1='/misc/netscape/passwords/earthkam/password.txt';
$FX="/projects/earthkam/www/ds/\ \ \ /one";
$FY="/projects/earthkam/www/ds/\ \ \ /two";

sub mysystem;

=toc
  some of the subs in this file:
    
(*hash)=getftpfilelist("ftp.somewhere.com","/remote/dir","username","password");
(*hash)=getlocalfilelist("/local/dir");
ftpfiles("ftp.somewhere.com","/remote/dir","username","password",\@filelist);
(*list)=comparedirs(\%remotehash,\%localhash,$ignoresize);
$time=gettime("filename");
(*newfilelist)=afterthistime($time,\@filelist);

=cut


=doc
    showhashes - displays two hashes side-by-side for easy comparison

=cut
sub showhashes {
    my($a,$b)=@_;
    my(@alist,@blist,$i,$x,$y);

    @alist=sort keys %$a;
    @blist=sort keys %$b;

    while (@alist || @blist) {
  $x=shift @alist unless defined $x;
  $y=shift @blist unless defined $y;

  $as=$$a{$x}>1023 ? 
      sprintf "% 5dk",int($$a{$x}/1024) :
    sprintf " % 5d",$$a{$x};

  $bs=$$b{$y}>1023 ? 
      sprintf "% 5dk",int($$b{$y}/1024) :
    sprintf " % 5d",$$b{$y};

  if (defined $x && ($x lt $y || !defined $y)) {
          printf "% 30s$as\n",$x; 
      undef $x;
  } elsif (defined $y && ($y lt $x || !defined $x)) {
      printf "% 36s   $bs $y\n","";
      undef $y;
  } elsif ($x eq $y) {
      printf "% 30s$as   $bs $y\n",$x;
      undef $x;
      undef $y;
  }
    }
}

=doc

    getftpfilelist - retrieves a hash of files and their sizes
    from a remote ftp site. specify the hostname, directory, 
    username and password. this returns a hash: the keys are 
    the files and the values are the file sizes.

=cut
sub getftpfilelist {
    my($host,$dir,$user,$pass)=@_;

    my $rh;
    local(%filehash);
    if ($host=~m,^ssh://(.+)$,) {
  # use ssh
  $rh=$1;
  $rh=$user.'@'.$rh if (length $user);

  open DAT, "ssh $rh '(cd $dir && ls -l)' |";
# ssh -l pma -L2222:137.78.73.40:22 thneed cat -
# open DAT, "ssh -p 2222 localhost '(cd $dir && ls -l)' |";
    } elsif ($host=~m,^local://(.+)$,) {
  # use ssh

  open DAT, "cd $dir && ls -l |";
    } else {
  # use plain-old ftp
  open TMP, ">/tmp/ks_temp$$" or die "Can't create /tmp/ks_temp$$\n";
  print TMP "open $host\nuser $user $pass\ncd $dir\nls -l\nbye\n";
  close TMP;
  open DAT, "ftp -n < /tmp/ks_temp$$ |" or die "can't open pipe from ftp\n";
    }

    while (<DAT>) {
      print if ($debug > 1);
      chomp ;
      $_=~/(.+)\s(\d+)(\s.{10,14}\s)(.+)$/;
  unless ($4 eq "." || $4 eq ".." || length($4)<1) {
        print " File: $4 ($2 bytes)\n" if ($debug);
        $filehash{$4}=$2;
  }
    }
    close DAT;
    unlink "/tmp/ks_temp$$";
    return (\%filehash);
}


=doc

    ftpfiles - retrieves each file listed in the input array. files
    are stored in the current local directory.

=cut
sub ftpfiles {
    my($host,$dir,$user,$pass,$filelist)=@_;
    my($count)=0;

    if ($host=~m,^ssh://(.+)$,i) {
  # use ssh
  $rh=$1;
  $rh=$user.'@'.$rh if (length $user);

  print "Using SCP...\n";
  foreach (@$filelist) {
      print "get $_\n" if ($debug);
      `date`;
      mysystem("scp $rh:$dir/$_ .");
#     mysystem("scp -P 2222 localhost:$dir/$_ .");
      $count++;
  }
    } elsif ($host=~m,^local://(.+)$,i) {
  # use cp

  print "Using PLAIN OLD unix CP...\n";
  foreach (@$filelist) {
      print "get $_\n" if ($debug);
      mysystem("cp $dir/$_ .");
      $count++;
  }
    } else{
  # plain old ftp
  open TMP, ">/tmp/ks_temp$$" or die "Can't create /tmp/ks_temp$$\n";
  print TMP "open $host\nuser $user $pass\ncd $dir\nbinary\n";
  foreach (@$filelist) {
      print TMP "get $_\n";
      print "get $_\n" if ($debug);
      $count++;
  }
  print TMP "bye\n";
  close TMP;
  print "Retrieving $count file(s)...\n";
  open(TMP,"ftp -n < /tmp/ks_temp$$ |") or die "can't open ftp";
  print "starting xfer...\n";
  foreach (<TMP>) {
      print if $debug;
  }
  close TMP;
    }
    print "xfer done...\n";    
    unlink "/tmp/ks_temp$$";
    return;
}
=doc

    ftpfiles - retrieves each file listed in the input array. files
    are stored in the current local directory.

=cut
sub scpfiles_R {
    my($host,$dir,$user,$pass,$filelist)=@_;
    my($count)=0;

    if ($host=~m,^ssh://(.+)$,i) {
  # use ssh
  $rh=$1;
  $rh=$user.'@'.$rh if (length $user);

  print "Using SCP...\n";
  foreach (@$filelist) {
      print "get $_\n" if ($debug);
      `date`;
      mysystem("scp -r $rh:$dir/$_ .");
      $count++;
  }
    } elsif ($host=~m,^local://(.+)$,i) {
  # use cp

  print "Using PLAIN OLD unix CP...\n";
  foreach (@$filelist) {
      print "get $_\n" if ($debug);
      mysystem("cp $dir/$_ .");
      $count++;
  }
    } else{
  # plain old ftp
  open TMP, ">/tmp/ks_temp$$" or die "Can't create /tmp/ks_temp$$\n";
  print TMP "open $host\nuser $user $pass\ncd $dir\nbinary\n";
  foreach (@$filelist) {
      print TMP "get $_\n";
      print "get $_\n" if ($debug);
      $count++;
  }
  print TMP "bye\n";
  close TMP;
  print "Retrieving $count file(s)...\n";
  open(TMP,"ftp -n < /tmp/ks_temp$$ |") or die "can't open ftp";
  print "starting xfer...\n";
  foreach (<TMP>) {
      print if $debug;
  }
  close TMP;
    }
    print "xfer done...\n";    
    unlink "/tmp/ks_temp$$";
    return;
}


=doc

    putftpfiles - puts each file listed in the input array. 
  note: directory names (if any) in the input array list
  will *not* be stored on the remote, only the file name

    host - ftp host site (like 'ftp.earthkam.edu'), or
           'localhost' for no ftp, just copy, or
           'ssh://hostname.domain' for the ssh's scp

    dir  - remote directory
    user - remote username
    pass - remote password
    filelist - \@array of stuff

=cut
sub putftpfiles {
    my($host,$dir,$user,$pass,$filelist)=@_;
    my($count)=0;
    my($asfile,$rh);

    if ($host =~m,^ssh://(.+)$,i) {
  # SECURE SHELL ( doesn't use password, 
  # ------------   you must setup .shosts or RSA key )
  $rh=$1;
  $rh=$user.'@'.$rh if (length $user);
  $rh.=":$dir";
  print "scp is copying ".@$filelist." file(s) to $rh\n" if $debug;
  print "Note: password isn't used with SSH. .shosts or RSA key is required\n"
      if length($pass);
  system("scp",@$filelist,$rh);

    } elsif (lc($host) eq 'localhost') {
  # COPY TO LOCALHOST
  # -----------------
  print "Copying ".@$filelist." file(s) to $dir\n" if $debug;
  system("cp",@$filelist,$dir);

    } else {
  # FTP
  # ---
  $host=~s,^ftp://,,i;
  open TMP, "|ftp -n" or die "Can't open pipe to ftp:$!\n";
  print TMP "open $host\nuser $user $pass\ncd $dir\nbinary\n";
  foreach (@$filelist) {
      $asfile=$_;
      $asfile=s#^.*/##;
      # asfile has no path in it
      print TMP "put $_ $asfile\n";
      print "put $_ $asfile\n" if ($debug);
      $count++;
  }
  print TMP "bye\n";
  close TMP;
    }
    return;
}

=doc

    putondatasystem - 
      creates a directory and puts the specified files on datasystem

=cut
sub putondatasystem {
    my($dirname, @filelist) = @_;
    my($i,$asfile);

    if (-d $conf{datasysdir}) {
  if ( -d "$conf{datasysdir}/$dirname" ||
       mkdir "$conf{datasysdir}/$dirname", 0755 ) {
      foreach (@filelist) {
    print "Copying $_ to $conf{datasysdir}/$dirname\n";
    system "cp", $_, "$conf{datasysdir}/$dirname";
      }
  } else {
      print "Cannot create directory $conf{datasysdir}/$dirname\n";
  }
    } else {
  print "datasysdir($conf{datasysdir}) not found\n";
    }
}

=old_code
    open TMP, "|ftp -n" or die "Can't open pipe to ftp:$!\n";
    print TMP "open $conf{charlotte}\nuser $conf{charlotteuser} ";
    print TMP "$conf{charlottepass}\ncd $conf{charlottedir}\nbinary\n";
    print TMP "mkdir $dirname\ncd $dirname\n";
    foreach $i (@filelist) {
  $asfile=$i;
  $asfile=~s/^.*\///;
  # asfile has no path in it
  print TMP "put $i $asfile\n";
  print "put $i $asfile\n" if ($debug);
    }
    print TMP "bye\n";
    close TMP;
=cut


=doc 

    filterfiles - returns a pointer to an array with only those
     files which match the input regular expression

=cut
sub filterfiles {
    my($array,$regexp) = @_;
    local @ret;

    foreach (@$array) {
  if ($_=~/$regexp/i) {
      push @ret, $_;
      print "Accepting $_ \n" if $debug;
  } else {
      print "Omitting $_ \n" if $debug;
      sleep .5;
  }
    }
    return \@ret;
}

=doc

    comparedirs - compares two hashes and returns an array
    that lists all elements found in remote that arent in
    local. set ignoresize to just compare the filenames. 

    if ignoresize=0, then no 0 byte files will be transferred.

=cut
sub comparedirs {
    my($remote,$local,$ignoresize) = @_;
    local(@list);

    if ($ignoresize) {
  foreach (keys %$remote) {
      unless (defined $$local{$_}) {
    push @list, $_;
      }
  }
    } else {
  foreach (keys %$remote) {
      unless ($$remote{$_} <= $$local{$_}) {
    push @list, $_;
      }
  }
    }
    return(\@list);
}


=doc

    getlocalfilelist - returns a hash of local files and their
    sizes. specify the directory to look at.

=cut
sub getlocalfilelist {
    my($dir)=@_;
    local(%filehash);
    chdir $dir;
    foreach (glob "*") {
  $filehash{$_}=(stat($_))[7];
    }
    return (\%filehash);
} 


=doc

    gettime - returns stat[9], the time that the file was last updated 

=cut
sub gettime {
    return (stat $_[0])[9];
}

sub getsize {
    return (-s $_[0]);
}

=doc

    afterthistime - returns an array of files updated on or after the specified time

=cut
sub afterthistime {
    my($time, $arrayptr)=@_;
    my($i);
    local(@ret);

    for $i (@$arrayptr) {
  if (gettime($i) >= $time) {
      push @ret, $i;
  }
    }
    return \@ret;
}


=autostretch

    autostretches the input .ppm file

=cut
sub autostretch {
    my($infile, $blackp, $whitep) = @_;
    my($jnk,$pwd);
    $blackp = 0.95 unless $blackp >= 0;
    $whitep = 0.95 unless $whitep >= 0;

    print "Stretch($blackp,$whitep) image: $infile\n" if $debug;

    $infile =~ s#(^.*/)##; 
    $indir = $1;
    ($infile, $jnk) = split ( '\.', $infile);
    
    chomp($pwd=`pwd`);

    if (length($indir)) {
  unless (chdir $indir) { print "Cannot cd to $indir: $!\n\n"; }
    }

    print "Warning: Input file should be in .ppm format\n" 
  unless ($jnk =~ /ppm/i);
    die "$0: Fatal: Cannot open $infile.ppm\n" unless -f "$infile.ppm";

    # create .red, .grn, .blu files
    print "ppmtorgb3 $infile.ppm\n" if $debug;
    mysystem "ppmtorgb3 $infile.ppm 2>/dev/null";

    # stretch each color layer (r,g,b)
    foreach ("red","grn","blu") {
  die "$0: Fatal: Cannot open $infile.$_\n" unless -s "$infile.$_";
  mysystem ("pgmnorm -bp $blackp -wp $whitep $infile.$_ > $infile.$_.str 2>/dev/null");
  die "$0: Fatal: $infile.$_.str was not created\n" unless -s "$infile.$_.str";
  unlink "$infile.$_";
    }

    # recombine the three layers
    mysystem ("rgb3toppm $infile.red.str $infile.grn.str $infile.blu.str > $infile.ppm 2>/dev/null");

    # clean up the mess
    mysystem ( "rm $infile.red.str $infile.grn.str $infile.blu.str");

    unless (chdir $pwd) { print "Warning: Cannot chdir to $pwd\n"; }
}


# performs the system command, catches errors in $conf{errors}
sub mysystem {
    my($syscmd)=@_;
    my($ret);
    unless ($syscmd =~ /2>/ || !length $conf{errors} ) {
  $syscmd="date >>$conf{errors} ; $syscmd 2>>$conf{errors}";
    }

    $ret=system($syscmd);

    if ($ret<0) {
  open (ACK,">>$conf{errors}");
  print ACK "*** System call failed: $syscmd\n";
  close ACK;
  print "System call failed!\n";
  sleep 5;
  # try it again...
  $ret=system($syscmd);    
  if ($ret<0) {
      open (ACK,">>$conf{errors}");
      print ACK "*** System call failed again: $syscmd\n";
      close ACK;
      print "System call failed again!\n";
  }

    }
    return $ret;
}

=doc

    natesleep - sleeps the number of seconds ... but keeps
      printing zzz... to keep tcl/tk awake, ready to
       kill the process at a seconds notice... 

=cut
sub natesleep {
    my $sleeptime=shift;
    my $end_sleep = time + $sleeptime;
    my $i = 0;
    print "Sleeping $sleeptime seconds";
    while (time < $end_sleep) {
  if ($i == 5) {
      print ($end_sleep - time);
      $i=0;
  } else {
      print ".";
      $i++;
  }
        sleep 2;
    }
    print "\n";
}

=doc

     tiffinfo - returns a string with header information
       from the tiff file.

=cut
sub tiffinfo {
    my($filename,$mission)=@_;
    my($ret);

    die "Cannot locate file - $filename\n" unless -f $filename;
    die "No mission specified\n" unless length $mission;

    ($basename, $ext) = split(/\./, $filename);
    if (length($basename) == 13){
  my  $met=substr($basename,4,9); #$met=sprintf("%09d",int $1);
    }
    else{
  my  $met=substr($basename,1,9); #$met=sprintf("%09d",int $1);
    }
    my $file="$filename";

    my $ctime = (stat $filename)[9];
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ctime);
    $year = 1900 + $year;
    my $fileDate = ($mon + 1) . "/" . $mday . "/" . $year . " ";
    $fileDate .= sprintf("%02d:%02d:%02d",$hour,$min,$sec);

    print "Reading $filename\n" if $debug;
    open(TIFFINFO,"tiffinfo $filename|") or die "Can't open tiffinfo: $!\n";
    while (<TIFFINFO>){
  chomp;

  if ( s/Date & Time:// ) {
      s/\"//g;
      s/^\s*//;
      my($Datetemp, $Timetemp) = split;
      my($GMT_year, $GMT_mnth, $GMT_day ) = split(/:/,$Datetemp);
#     my($MET_year, $MET_mth, $MET_day ) = split(/:/,$Datetemp);
#     $day_prefix = substr($mission, -1, 1);
#     $MET_DAY = $day_prefix.$MET_day;
      my($GMT_hr, $GMT_min, $GMT_sec ) = split(/:/,$Timetemp);
      #####################################
      # ack.. convert met to gmt here ... #
      #####################################
      if($debug) {
    print " GMT is $GMT_day/$GMT_mnth $GMT_year $GMT_hr : $GMT_min : $GMT_sec\n\n";
      }        

#     # Build the GMT
  #    my $carry_min = 0;
   #   my $carry_hr = 0;
    #  my $carry_day = 0;
     # my $carry_mth = 0;

      #if ( $MET_sec + $Launch_sec > 59){
    #$GMT_sec = $MET_sec + $Launch_sec - 60;
    #$carry_min = 1;
#     }
  #    else {
#   $GMT_sec = $MET_sec + $Launch_sec ;
#     }
#     if ( $MET_min + $Launch_min + $carry_min > 59){
#   $GMT_min = $MET_min + $Launch_min + $carry_min - 60;
#   $carry_hr = 1;
#     }
#     else {
#   $GMT_min = $MET_min + $Launch_min + $carry_min;
#     }
#     if ( $MET_hr + $Launch_hr + $carry_hr > 23){
#   $GMT_hr = $MET_hr + $Launch_hr + $carry_hr - 24;
#   $carry_day = 1;
#     }
#     else {
#   $GMT_hr = $MET_hr + $Launch_hr + $carry_hr;
#     }
      
#     if($debug) {
#   print " met hr is $MET_hr, launch hr is $Launch_hr \n";
#   print " and GMT hour is $GMT_hr \n\n";
#     }
      
#     if ( $MET_day + $Launch_day + $carry_day > 29){
#   $GMT_day = $MET_day + $Launch_day + $carry_day - 30;
#   $carry_mth = 1;
#     }
#     else {
#   $GMT_day = $MET_day + $Launch_day + $carry_day ;
#     }
#     if ( $Launch_mth + $carry_mth > 12){
#   $GMT_mth = $Launch_mth + $carry_mth - 12;
#   $GMT_yr = $Launch_yr + 1;
#     }
#     else {
#   $GMT_mth = $Launch_mth + $carry_mth;
#   $GMT_yr = $Launch_yr;
#     }

      #####################################

      $iid = $conf{msn}.".".$conf{src}.".".$met; 
      $ret= "$iid|$fileDate|$file|";
      $ret.= sprintf("%02d:%02d:%02d ", $GMT_hr, $GMT_min, $GMT_sec);
      $ret.= sprintf("%02d/%02d/$GMT_yr|", $GMT_mth, $GMT_day);
  }

  if ( s/Image Description:// ) {
      s/\s+//;
      my ($junk,$iso,$aperture,$shutter,$lens,$exposure,$cam_prog,
       $exposure_comp,$meter_area,$flash_syn,$drive_mode,$focus_mode,
       $focus_area,$kidsat_gps,$gps_time,$gps_lat,$gps_lon) = split(/\s*\\r/,$_);
      my($keyword,$iso_v) = split(/:\s*/,$iso);
      my($keyword,$aperture_v) = split(/:\s*/,$aperture);
      my($keyword,$shutter_v) = split(/:\s*/,$shutter);
      my($keyword,$lens_v) = split(/:\s*/,$lens);
      my($keyword,$exposure_v) = split(/:\s*/,$exposure);
      my($keyword,$cam_prog_v) = split(/:\s*/,$cam_prog);
      my($keyword,$exposure_comp_v) = split(/:\s*/,$exposure_comp);
      my($keyword,$meter_area_v) = split(/:\s*/,$meter_area);
      my($keyword,$flash_sync_v) = split(/:\s*/,$flash_syn);
      my($keyword,$drive_mode_v) = split(/:\s*/,$drive_mode);
      my($keyword,$focus_mode_v) = split(/:\s*/,$focus_mode);
      my($keyword,$focus_area_v) = split(/:\s*/,$focus_area);
      ##my($keyword,$kidsat_gps_v) = split(/$/,$kidsat_gps);
      my($keyword,$kidsatPID) = split(/:\s*/,$gps_time);  #changed for STS086
      ##my($keyword,$kidsat_gps_v) = split(/$/,$kidsat_gps);
      ##my($keyword,$gps_time_v) = split(/e:/,$gps_time);
      ##my($keyword,$gps_lat_v) = split(/t:/,$gps_lat);
      ##my($keyword,$gps_lon_v) = split(/g:/,$gps_lon);
            ##my($keyword,$distance_v) = split(/:\s*/,$distance);
      my $eff_foc = int($lens_v * 1.28);  
      $ret.="$iso_v|$aperture_v|$shutter_v|$eff_foc|$exposure_v|$cam_prog_v|";
      $ret.="$exposure_comp_v|$meter_area_v|$flash_sync_v|$drive_mode_v|";
      $ret.="$focus_mode_v|$focus_area_v|$kidsatPID";
  }
    }
    close(TIFFINFO);

    return $ret;
}
=doc

     tiffinfo - returns a string with header information
       from the tiff file.

=cut
sub tiffinfo2 {
    my($filename,$mission)=@_;
    my($ret);

    die "Cannot locate file - $filename\n" unless -f $filename;
    die "No mission specified\n" unless length $mission;

    ($basename, $ext) = split(/\./, $filename);
    if (length($basename) == 13){
  my  $met=substr($basename,4,9); #$met=sprintf("%09d",int $1);
    }
    else{
  my  $met=substr($basename,1,9); #$met=sprintf("%09d",int $1);
    }
    my $file="$filename";

    my $ctime = (stat $filename)[9];
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ctime);
    $year = 1900 + $year;
    my $fileDate = ($mon + 1) . "/" . $mday . "/" . $year . " ";
    $fileDate .= sprintf("%02d:%02d:%02d",$hour,$min,$sec);

    print "Reading $filename\n" if $debug;
    open(TIFFINFO,"tiffinfo $filename|") or die "Can't open tiffinfo: $!\n";
    while (<TIFFINFO>){
  chomp;

  if ( s/Date & Time:// ) {
      s/\"//g;
      s/^\s*//;
      my($Datetemp, $Timetemp) = split;
      my($GMT_year, $GMT_mnth, $GMT_day ) = split(/:/,$Datetemp);
#     my($MET_year, $MET_mth, $MET_day ) = split(/:/,$Datetemp);
#     $day_prefix = substr($mission, -1, 1);
#     $MET_DAY = $day_prefix.$MET_day;
      my($GMT_hr, $GMT_min, $GMT_sec ) = split(/:/,$Timetemp);
      #####################################
      # ack.. convert met to gmt here ... #
      #####################################
      if($debug) {
    print " GMT is $GMT_day/$GMT_mnth $GMT_year $GMT_hr : $GMT_min : $GMT_sec\n\n";
      }        

#     # Build the GMT
  #    my $carry_min = 0;
   #   my $carry_hr = 0;
    #  my $carry_day = 0;
     # my $carry_mth = 0;

      #if ( $MET_sec + $Launch_sec > 59){
    #$GMT_sec = $MET_sec + $Launch_sec - 60;
    #$carry_min = 1;
#     }
  #    else {
#   $GMT_sec = $MET_sec + $Launch_sec ;
#     }
#     if ( $MET_min + $Launch_min + $carry_min > 59){
#   $GMT_min = $MET_min + $Launch_min + $carry_min - 60;
#   $carry_hr = 1;
#     }
#     else {
#   $GMT_min = $MET_min + $Launch_min + $carry_min;
#     }
#     if ( $MET_hr + $Launch_hr + $carry_hr > 23){
#   $GMT_hr = $MET_hr + $Launch_hr + $carry_hr - 24;
#   $carry_day = 1;
#     }
#     else {
#   $GMT_hr = $MET_hr + $Launch_hr + $carry_hr;
#     }
      
#     if($debug) {
#   print " met hr is $MET_hr, launch hr is $Launch_hr \n";
#   print " and GMT hour is $GMT_hr \n\n";
#     }
      
#     if ( $MET_day + $Launch_day + $carry_day > 29){
#   $GMT_day = $MET_day + $Launch_day + $carry_day - 30;
#   $carry_mth = 1;
#     }
#     else {
#   $GMT_day = $MET_day + $Launch_day + $carry_day ;
#     }
#     if ( $Launch_mth + $carry_mth > 12){
#   $GMT_mth = $Launch_mth + $carry_mth - 12;
#   $GMT_yr = $Launch_yr + 1;
#     }
#     else {
#   $GMT_mth = $Launch_mth + $carry_mth;
#   $GMT_yr = $Launch_yr;
#     }

      #####################################

      $iid = $conf{msn}.".".$conf{src}.".".$met; 
      $ret= "$iid|$fileDate|$file|";
      $ret.= sprintf("%02d:%02d:%02d ", $GMT_hr, $GMT_min, $GMT_sec);
      $ret.= sprintf("%02d/%02d/$GMT_yr|", $GMT_mth, $GMT_day);
  }

  if ( s/Image Description:// ) {
      s/\s+//;
      my ($junk,$iso,$aperture,$shutter,$lens,$exposure,$cam_prog,
       $exposure_comp,$meter_area,$flash_syn,$drive_mode,$focus_mode,
       $focus_area,$kidsat_gps,$gps_time,$gps_lat,$gps_lon) = split(/\s*\\r/,$_);
      my($keyword,$iso_v) = split(/:\s*/,$iso);
      my($keyword,$aperture_v) = split(/:\s*/,$aperture);
      my($keyword,$shutter_v) = split(/:\s*/,$shutter);
      my($keyword,$lens_v) = split(/:\s*/,$lens);
      my($keyword,$exposure_v) = split(/:\s*/,$exposure);
      my($keyword,$cam_prog_v) = split(/:\s*/,$cam_prog);
      my($keyword,$exposure_comp_v) = split(/:\s*/,$exposure_comp);
      my($keyword,$meter_area_v) = split(/:\s*/,$meter_area);
      my($keyword,$flash_sync_v) = split(/:\s*/,$flash_syn);
      my($keyword,$drive_mode_v) = split(/:\s*/,$drive_mode);
      my($keyword,$focus_mode_v) = split(/:\s*/,$focus_mode);
      my($keyword,$focus_area_v) = split(/:\s*/,$focus_area);
      ##my($keyword,$kidsat_gps_v) = split(/$/,$kidsat_gps);
      my($keyword,$kidsatPID) = split(/:\s*/,$gps_time);  #changed for STS086
      ##my($keyword,$kidsat_gps_v) = split(/$/,$kidsat_gps);
      ##my($keyword,$gps_time_v) = split(/e:/,$gps_time);
      ##my($keyword,$gps_lat_v) = split(/t:/,$gps_lat);
      ##my($keyword,$gps_lon_v) = split(/g:/,$gps_lon);
            ##my($keyword,$distance_v) = split(/:\s*/,$distance);
      my $eff_foc = int($lens_v * 1.28);  
      $ret.="$iso_v|$aperture_v|$shutter_v|$eff_foc|$exposure_v|$cam_prog_v|";
      $ret.="$exposure_comp_v|$meter_area_v|$flash_sync_v|$drive_mode_v|";
      $ret.="$focus_mode_v|$focus_area_v|$kidsatPID";
  }
    }
    close(TIFFINFO);

    return $ret;
}

sub pidDBInsert {
    my($iid)=@_;
    $dblog = $conf{dblogfile};
    open DBLOG, ">>$dblog";

    $iid_dir = $conf{datasysdir}.$iid."/PID_IS_*.txt";
    $pidfile = `ls -1 $iid_dir`;
    if ($pidfile eq ""){
  print DBLOG "\n*** no $pidfile found skip this file\n";
  $ret=0;
  return $ret;
    }
    else {
  print DBLOG "found $pidfile continue processing\n\n";
    }
    $date = `grep "Date & Time:" $pidfile`;
    chomp $date;
    ($s1,$img_date) = split(/Time: /,$date);
    $img_date =~ s/\"//g;

    ($S1, $S2, $S3) = split(/_/,$pidfile);

    ($pid,$ext) = split(/\./,$S3);

    $ret=1;
    
    if ($debug){
  print " The current values of the input variables are: \n
filepath is $iid\n, imageDate is $img_date\n, where photoID is $pid\n\n";
    }

    my($cmd) = "select orbit, lookDir from ekImages where photoID=$pid";
    print "Initial command is $cmd\n";           
    my(@results);
    
    print "Cannot lookup filePath in the ekImages table with Camera Info for PhotoID $pid\n" unless(&dblookup($cmd, \@results));

    ($orbit, $lookDir) = split(/\t/, $results[0]);

    if($orbit ne ''){
  my($cmd1) = "update ekImages set filepath='$iid', imageDate='$img_date' where photoID=$pid";
  if (&dbupdate($cmd1)){
      print "$iid tiff header successfully inserted in DB with command $cmd1\n\n";
      print DBLOG "$iid tiff header successfully inserted in DB with command $cmd1\n\n";
  } else {
      print "*****ERROR for $iid Cannot update the Camera Info into the ekImages table for PhotoID $photoID\n";
      print DBLOG "*****ERROR for $iid Cannot update the Camera Info into the ekImages table for PhotoID $photoID\n";
  }    
  
    }
    elsif ($dbFilePath eq '') {
  my($cmd1) = "insert into ekImages (filePath,imageDate,photoID) values ('$iid','$img_date',$pid)"; 
  if (&dbupdate($cmd1)){
      print "$iid tiff header successfully inserted in DB with command $cmd1\n\n";
      print DBLOG "$iid tiff header successfully inserted in DB with command $cmd1\n\n";
  } else {
      print "*****ERROR for $iid Cannot insert the Camera Info into the ekImages table for PhotoID $photoID\n";
      print DBLOG "*****ERROR for $iid Cannot insert the Camera Info into the ekImages table for PhotoID $photoID\n";
  }    
    }
    else {
  print "\nPhotoID $photoID already corresponds to an image in the DataBase, specifically $dbFilePath, I will continue to process images and note that $iid 's TIFF Header Info did NOT make it to the database\n\n";
  print DBLOG "\nPhotoID $photoID already corresponds to an image in the DataBase, specifically $dbFilePath, I will continue to process images and note that $iid 's TIFF Header Info did NOT make it to the database\n\n";
    }
    close DBLOG;
    return $ret;
}

sub tiffHeaderDBInsert {
    my($tiffHeader)=@_;
    $dblog = $conf{dblogfile};
    open DBLOG, ">>$dblog";
    $tiffHeader =~ s/(['"])//g; #"'

    $ret=1;
    
    ($filePath, $modified, $coFileName, $imageDate, $iso, $aperture, $shutter, $effFocalLen, $exposure, $program, $exposComp, $lightMeter, $flashSync, $driveMode, $focusMode, $focusArea, $photoID) = split(/\|/, $tiffHeader);

         
    if ($debug){
  print " The current values of the input variables are: \n
filepath is $filePath\n, modified is $modified\n, coFileName is $coFileName\n, imageDate is $imageDate\n, iso is $iso\n, aperture is $aperture\n, shutter is $shutter\n, effFocalLen is $effFocalLen\n, exposure is $exposure\n, program is $program\n, exposComp is $exposComp\n, lightMeter is $lightMeter\n, flashSync is $flashSync\n, driveMode is $driveMode\n, focusMode is $focusMode\n, focusArea is $focusArea where photoID is $photoID\n\n";
    }

    my($cmd) = "select filePath, lookDir from ekImages where photoID=$photoID";
    print "Initial command is $cmd\n";           
    my(@results);
    
    print "Cannot lookup filePath in the ekImages table with Camera Info for PhotoID $photoID\n" unless(&dblookup($cmd, \@results));

    ($dbFilePath, $lookDir) = split(/\t/, $results[0]);

    if($dbFilePath eq $filePath){
  my($cmd1) = "update ekImages set modified='$modified', coFileName='$coFileName', imageDate='$imageDate', iso=$iso, aperture='$aperture', shutter=$shutter, effFocalLen=$effFocalLen, exposure='$exposure', program='$program', exposComp=$exposComp, lightMeter='$lightMeter', flashSync='$flashSync', driveMode='$driveMode', focusMode='$focusMode', focusArea='$focusArea' where photoID=$photoID";
  if (&dbupdate($cmd1)){
      print "$filepath tiff header successfully inserted in DB with command $cmd1\n\n";
      print DBLOG "$filepath tiff header successfully inserted in DB with command $cmd1\n\n";
  } else {
      print "*****ERROR for $filepath Cannot insert the Camera Info into the ekImages table for PhotoID $photoID\n";
      print DBLOG "*****ERROR for $filepath Cannot insert the Camera Info into the ekImages table for PhotoID $photoID\n";
  }    
  
    }
    elsif ($dbFilePath eq '') {
  my($cmd1) = " insert into ekImages (filePath,modified,coFileName,imageDate,iso,aperture,shutter,effFocalLen,exposure,program,exposComp,lightMeter,flashSync,driveMode,focusMode,focusArea,photoID) values ('$filePath','$modified','$coFileName','$imageDate',$iso,'$aperture','$shutter',$effFocalLen,'$exposure','$program',$exposComp,'$lightMeter','$flashSync','$driveMode','$focusMode','$focusArea',$photoID)"; 
  if (&dbupdate($cmd1)){
      print "$filepath tiff header successfully inserted in DB with command $cmd1\n\n";
      print DBLOG "$filepath tiff header successfully inserted in DB with command $cmd1\n\n";
  } else {
      print "*****ERROR for $filepath Cannot insert the Camera Info into the ekImages table for PhotoID $photoID\n";
      print DBLOG "*****ERROR for $filepath Cannot insert the Camera Info into the ekImages table for PhotoID $photoID\n";
  }    
    }
    else {
  print "\nPhotoID $photoID already corresponds to an image in the DataBase, specifically $dbFilePath, I will continue to process images and note that $filePath 's TIFF Header Info did NOT make it to the database\n\n";
  print DBLOG "\nPhotoID $photoID already corresponds to an image in the DataBase, specifically $dbFilePath, I will continue to process images and note that $filePath 's TIFF Header Info did NOT make it to the database\n\n";
    }
    close DBLOG;
    return $ret;
}


#### dblookup - runs sql to get data from the database
# input: SQL_command, *array_ptr
# output: returns 0
#         @array_ptr=("headercol1\tcol2\tcol3","row1c1\tr1c2\t|...",...)
#
#example SQL command:
# "SELECT row1,row2 FROM ekImages WHERE filePath='STS081.ESC.01234567'"
#
#### dblookup - runs sql to get data from the database
# input: SQL_command, *array_ptr
# output: returns 0
#         @array_ptr=("headercol1\tcol2\tcol3","row1c1\tr1c2\t|...",...)
#                       ^ This is a lie...doesn't actually return headers.
#                         - Marland Sitt (Summer 08)
#
#example SQL command:
# "SELECT row1,row2 FROM ekImages WHERE filePath='STS081.ESC.01234567'"
#
sub dblookup ($\\@) {
    local($sql, *arrayp) = @_;
    undef @arrayp;

#    you didn't see this
#    use DBI;
    use DBI;

    my $dbh = DBI->connect("DBI:Pg:database=$DB_NAME;host=$DB_HOST",
                "$DB_USER","$DB_PASSWD",
         {RaiseError => 1});

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    # collect results
    while ((@row = $sth->fetchrow())) {
  foreach (@row) {
      if (/[+-]?\d+\.\d+e[+-]\d+/i) {
    $_=sprintf("%f",$_);
    s/(\.\d+)0000$/$1/;
      }
  }
  push @arrayp, join("\t",@row);
    }

    # disconnect
    $sth->finish();
    $dbh->disconnect();

    # done
    return 1;
}
sub dbupdate {
    local($sql) = @_;

    use DBI;

    my $dbh = DBI->connect("DBI:Pg:database=$DB_NAME;host=$DB_HOST",
                "$DB_USER","$DB_PASSWD",
         {RaiseError => 1});
    
    #set trace output at level 2 to help debugging of DB error
    #DBI->trace( 2 );

    # run the sql
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    # disconnect
    $sth->finish();
    $dbh->disconnect();

    # done
    return 1;
}





