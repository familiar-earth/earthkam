#!/usr/bin/perl -w

package FeatureReader;

use DataGet qw(dblookup);
use CGI qw(:standard);

sub findImageIds
{
  my @features = @_;
  my @results = ();
  # choose files which contains only the selected features
  my $query = "SELECT msnCode, source, photoID FROM feature_containment WHERE ";
  foreach $code (@features)
  {
    $code =~ s/\s/_/g;
    $query .= "$code=1 AND ";
  }
  $query .= "updated=1;";
  
  print "Query failed!\n" unless &dblookup($query, \@results);
  foreach my $row (@results)
  {
    $row =~ s/\s+/\./g;
  }
  return @results;
}

sub printThumbs
{
  my @features = @_;
  my @images = &findImageIds(@features);
  my $html = "";
  my @data = ();
  my $i = 0;
  until ($i > $#images)
  { 
    my @contents = ();
    for (my $j = $i;$j <= $i+5;$j++)
    {
      my ($msn, $src, $id) = split(/\./, $images[$j]);
      my $url = "http://ssvekdev.jpl.nasa.gov/ek/imgs/$msn$src/$id/level1.jpg";
      push @contents, table(Tr({-align=>CENTER,-valign=>TOP}, 
            [td("<img src=\"$url\" />"), td($images[$j])]));
    }
    push @data, td(\@contents);
    $i += 6;
  }
  $html .= table({-border=>undef}, Tr(\@data));
  return $html;
  
}

1;
