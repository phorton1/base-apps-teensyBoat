#!/usr/bin/perl
#-------------------------------------------------------------------------
# teensyBoat.pm
#-------------------------------------------------------------------------
# A purpose built WX application with a console to interfaces to the
# Arduino-boat-teensyBoat program over the teensy USB serial port.

package teensyBoat;
use strict;
use warnings;
use threads;
use threads::shared;
use Pub::Utils;
use Pub::WX::Resources;
use Pub::WX::Main;
use tbResources;
use tbUtils;
use tbFrame;
use tbConsole;
use base 'Wx::App';


my $http_server;
if ($WITH_TB_SERVER)
{
	display(0,0,"starting tbServer");
	$http_server = tbServer->new();
	$http_server->start();
	display(0,0,"finished starting http_server");
}



my $frame;

sub OnInit
{
	$frame = tbFrame->new();
	if (!$frame)
	{
		error("unable to create frame");
		return undef;
	}

	$frame->Show( 1 );
	display(0,0,"$$resources{app_title} started");
	start_tbConsole();
	return 1;
}

my $app = teensyBoat->new();

Pub::WX::Main::run($app);

display(0,0,"ending $appName.pm frame=$frame");
$frame->DESTROY() if $frame;
$frame = undef;
display(0,0,"finished $appName.pm");



1;
