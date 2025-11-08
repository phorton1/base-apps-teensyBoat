#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbUtils.pm
#-------------------------------------------------------------------------

package tbUtils;
use strict;
use warnings;
use threads;
use threads::shared;
use Pub::Utils;
use Pub::WX::AppConfig;
use tbResources;


our $WITH_TB_SERVER = 0;

our $SHOW_DEGREE_MINUTES = 1;

BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(

		$WITH_TB_SERVER

		$PORT_SEATALK
	    $PORT_0183
	    $PORT_2000
	    $NUM_BOAT_PORTS

		$INST_DEPTH
	    $INST_LOG
	    $INST_WIND
	    $INST_COMPASS
	    $INST_GPS
	    $INST_AIS
	    $INST_AUTOPILOT
	    $INST_ENGINE
	    $INST_GENSET
	    $NUM_INSTRUMENTS


		$NO_ECHO_TO_PERL

		$SHOW_DEGREE_MINUTES
		
		portId
		portName
		instrumentName

		degreeMinutes

	);
}


# defines that must agree with INO

our $PORT_SEATALK		= 0;
our $PORT_0183A			= 1;
our $PORT_0183B			= 2;
our $PORT_2000			= 3;
our $NUM_BOAT_PORTS		= 4;

our $INST_DEPTH			= 0;
our $INST_LOG			= 1;
our $INST_WIND			= 2;
our $INST_COMPASS		= 3;
our $INST_GPS			= 4;
our $INST_AIS			= 5;
our $INST_AUTOPILOT		= 6;
our $INST_ENGINE 		= 7;
our $INST_GENSET		= 8;
our $NUM_INSTRUMENTS 	= 9;


our $NO_ECHO_TO_PERL   = 10000;




#--------------------------------
# main
#--------------------------------

Pub::Utils::initUtils();
# createSTDOUTSemaphore("buddySTDOUT");
setStandardTempDir($appName);
setStandardDataDir($appName);


$ini_file = "$temp_dir/$appName.ini";



#--------------------------------
# methods
#--------------------------------

sub portName
	# human readable
{
	my ($port_num) = @_;
	return "SEATALK"	if $port_num == $PORT_SEATALK;
	return "NMEA0183A"	if $port_num == $PORT_0183A;
	return "NMEA0183B"	if $port_num == $PORT_0183B;
	return "NMEA2000"	if $port_num == $PORT_2000;
	return "UNKNOWN_PORT";
}

sub portId
	# understood by ino M_ and I_ commands
{
	my ($port_num) = @_;
	return "ST"		if $port_num == $PORT_SEATALK;
	return "83A"	if $port_num == $PORT_0183A;
	return "83B"	if $port_num == $PORT_0183B;
	return "2000"	if $port_num == $PORT_2000;
	return "UNKNOWN_PORT_ID";
}

sub instrumentName
{
	my ($inst_num) = @_;
	return "DEPTH"		if $inst_num == $INST_DEPTH;
	return "LOG"		if $inst_num == $INST_LOG;
	return "WIND"		if $inst_num == $INST_WIND;
	return "COMPASS"	if $inst_num == $INST_COMPASS;
	return "GPS"		if $inst_num == $INST_GPS;
	return "AIS"		if $inst_num == $INST_AIS;
	return "AP"			if $inst_num == $INST_AUTOPILOT;
	return "ENG" 		if $inst_num == $INST_ENGINE;
	return "GEN"	    if $inst_num == $INST_GENSET;
	return "UNKNOWN_INSTRUMENT";
}


sub degreeMinutes
{
	my $DEG_CHAR = chr(0xB0);
	my ($ll) = @_;
	my $deg = int($ll);
	my $min = round(abs($ll - $deg) * 60,3);
	return "$deg$DEG_CHAR$min";
}




1;
