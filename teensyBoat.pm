#!/usr/bin/perl
#-------------------------------------------------------------------------
# teensyBoat.pm
#-------------------------------------------------------------------------
# A purpose built WX application with a console to interfaces to the
# Arduino-boat-teensyBoat program over the teensy USB serial port.

package apps::teensyBoat::teensyBoat;
use strict;
use warnings;
use threads;
use threads::shared;
use Pub::Utils;
use Pub::WX::Resources;
use Pub::WX::Main;
use apps::teensyBoat::tbResources;
use apps::teensyBoat::tbUtils;
use apps::teensyBoat::tbFrame;
use base 'Wx::App';

my $frame;

sub OnInit
{
	$frame = apps::teensyBoat::tbFrame->new();
	if (!$frame)
	{
		error("unable to create frame");
		return undef;
	}

	$frame->Show( 1 );
	display(0,0,"$$resources{app_title} started");
	return 1;
}

my $app = apps::teensyBoat::teensyBoat->new();
Pub::WX::Main::run($app);


display(0,0,"ending $appName.pm frame=$frame");
$frame->DESTROY() if $frame;
$frame = undef;
display(0,0,"finished $appName.pm");



1;
