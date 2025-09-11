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


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(
	);
}


Pub::Utils::initUtils();
# createSTDOUTSemaphore("buddySTDOUT");
setStandardTempDir($appName);
setStandardDataDir($appName);


1;
