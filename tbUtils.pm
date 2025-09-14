#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbUtils.pm
#-------------------------------------------------------------------------

package apps::teensyBoat::tbUtils;
use strict;
use warnings;
use threads;
use threads::shared;
use apps::teensyBoat::tbResources;
use Pub::Utils;

our $SHOW_DEGREE_MINUTES = 1;

BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(
		$SHOW_DEGREE_MINUTES
		
		degreeMinutes
	);
}


Pub::Utils::initUtils();
# createSTDOUTSemaphore("buddySTDOUT");
setStandardTempDir($appName);
setStandardDataDir($appName);



sub degreeMinutes
{
	my $DEG_CHAR = chr(0xB0);
	my ($ll) = @_;
	my $deg = int($ll);
	my $min = round(abs($ll - $deg) * 60,3);
	return "$deg$DEG_CHAR$min";
}



1;
