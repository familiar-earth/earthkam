package constants;

use base 'Exporter';

# It is predicted that featureReader.pl, jiggle.pl, annotate.pl, and get_pts.pl will need these constants, so to use, copy the following line in
# use constants 'FONT', 'COLOR', 'FONT_SIZE', 'COUNTRY', 'MAX_NUM', 'PRIORITY', 'FONT_OUTLINE', 'OUTLINE_STROKE_WIDTH', 'FEATURE_CODE', 'GRAVITY', 'SIZE';

# It is predicted that distance_calc.pl and updateKMLFile.pl will need these constants, so to use, copy the following line in
# use constants 'PI', 'RADIUS_EARTH';

use constant {
	FONT => 0,
	COLOR => 1,
	FONT_SIZE => 2,
	COUNTRY => 3,
	MAX_NUM => 4,
	PRIORITY => 5,
	FONT_OUTLINE => 6,
	OUTLINE_STROKE_WIDTH => 7,
	FEATURE_CODE => 8,
	GRAVITY => 9,
	SIZE => 10,
};

my $pi = atan2(1, 1) * 4;

# some constants
use constant PI => $pi;
use constant RADIUS_EARTH => 6371; # Wikipedia

our @EXPORT_OK = ('FONT', 'COLOR', 'FONT_SIZE', 'COUNTRY', 'MAX_NUM', 'PRIORITY', 'FONT_OUTLINE', 'OUTLINE_STROKE_WIDTH', 'FEATURE_CODE', 'GRAVITY', 'SIZE',
	'PI', 'RADIUS_EARTH', 'CIRC_EARTH');

1;