#-------------------------------------------------------------------------
# tbUtils.pm
#-------------------------------------------------------------------------
# The program is instantiated with one command line parameter that defaults to '14',
# 	which is the USB com port of the teensyBoat.ino device on the laptop. The port
#	for the breadboard is currently '4'.
# A number XXX higher than 40 is taken as the IP address 10.237.50.XXX, the ip address
#	of tbESP32.ino which is an ESP32 connected to the teensy teensyBoat.ino, running
#	a myIOT device which uses UDP to provide two way serial data to the teensy from
#   this laptop.
# The number is also used to drive the "appTitle" for the program that shows in the
#   the WX frames so you can tell which device you are looking at, and the name of
#	the ini file so that you can open more than one teensyBoat window and each will
#	have its own screen layout.


package tbUtils;
use strict;
use warnings;
use threads;
use threads::shared;
use Pub::Utils;
use Pub::WX::AppConfig;
# use tbResources;


our $WITH_TB_SERVER = 0;

our $SHOW_DEGREE_MINUTES = 1;

our $DEFAULT_PROG_PARAM = 14;

our $appName = "teensyBoat";


# hardwired configuration

my $HIGHEST_COM_PORT = 40;
	# above this, will be considered the XXX in $UDP_IP address
my $FIXED_LAN_ADDR = '10.237.50.';
my $FIXED_UDP_PORT = 5005;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(

		$appName

		$PROG_PARAM
		$COM_PORT
		$UDP_PORT
		$UDP_IP

		$WITH_TB_SERVER

		$PORT_ST1
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

		$SHOW_DEGREE_MINUTES
		
		portId
		portName
		instrumentName

		degreeMinutes

	);
}









# defines that must agree with INO

our $PORT_ST1			= 0;
our $PORT_ST2			= 1;
our $PORT_0183A			= 2;
our $PORT_0183B			= 3;
our $PORT_2000			= 4;
our $NUM_BOAT_PORTS		= 5;

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




#--------------------------------
# main
#--------------------------------
# Parse the command line argument

our $PROG_PARAM = $DEFAULT_PROG_PARAM;
$PROG_PARAM = $ARGV[0] if $ARGV[0];
our $COM_PORT = $PROG_PARAM;				# comm port default = 14

our $UDP_PORT = '';
our $UDP_IP = '';
if ($PROG_PARAM > $HIGHEST_COM_PORT)		# above 40
{
	$COM_PORT = '';
	$UDP_PORT = $FIXED_UDP_PORT;			# udp port is 5005
	$UDP_IP = $FIXED_LAN_ADDR.$PROG_PARAM;	# and udp ip is 10.237.50.XXX
}


# the data directories only exist once for all $PROG_PARAMS

Pub::Utils::initUtils();
# createSTDOUTSemaphore("buddySTDOUT");
setStandardTempDir($appName);
setStandardDataDir($appName);

# but the ini file and shown title of the program get ($PROG_PARAM)

$ini_file = "$temp_dir/$appName.$PROG_PARAM.ini";
$appName .= "($PROG_PARAM)";


#--------------------------------
# methods
#--------------------------------


sub portName
	# human readable
{
	my ($port_num) = @_;
	return "SEATALK1"	if $port_num == $PORT_ST1;
	return "SEATALK2"	if $port_num == $PORT_ST2;
	return "NMEA0183A"	if $port_num == $PORT_0183A;
	return "NMEA0183B"	if $port_num == $PORT_0183B;
	return "NMEA2000"	if $port_num == $PORT_2000;
	return "UNKNOWN_PORT";
}


sub portId
	# understood by ino M_ and I_ commands
{
	my ($port_num) = @_;
	return "ST1"	if $port_num == $PORT_ST1;
	return "ST2"	if $port_num == $PORT_ST2;
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
