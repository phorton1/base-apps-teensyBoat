#!/usr/bin/perl
#-----------------------------------------------------
# apps::teensyBoat::tbServer.pm
#-----------------------------------------------------
# An HTTP Server for teensyBoat.
# Provides realtime updates via kml to Google Earth network links.


package apps::teensyBoat::tbServer;
use strict;
use warnings;
use threads;
use threads::shared;
use Time::HiRes qw(time);
use Math::Trig qw(deg2rad );
# use HTML::Entities;
use Pub::Utils;
# use Pub::Prefs;
# use Pub::ServerUtils;		# only if wifi
use Pub::HTTP::ServerBase;
use Pub::HTTP::Response;
use base qw(Pub::HTTP::ServerBase);

our $tb_tracking:shared = 0;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(
		$tb_tracking
		updateTBServer
		clearTBTrack
	);
}


my $EOL = "\r\n";

my $SERVER_PORT = 9881;
# our $SERVER_URL = "http://localhost:$SERVER_PORT";
my $src_dir = "/base/apps/teensyBoat";



#----------------------------------
# state
#----------------------------------

my $TRACK_PT_DISTANCE = 100;		# feet
my $TRACK_PT_TIME = 60;				# seconds
my $TRACK_PT_HEADING = 3;			# degrees


my $heading:shared = 180;
my $latitude:shared = 9.334083;
my $longitude:shared = -82.242050;
my $speed_knots:shared = 0;
	# bocas

my $track:shared = shared_clone([]);
my $last_track_lat:shared = 0;
my $last_track_lon:shared = 0;
my $last_track_time:shared = 0;
my $last_heading:shared = 0;


sub clearTBTrack
{
	display(0,0,"clearTBTrack() called");
	$track = shared_clone([]);
	$last_track_time = 0;
}




sub haversine_distance_ft
{
	my ($lat1, $lon1, $lat2, $lon2) = @_;
	my $R = 6371000; # Earth radius in meters

	my $dlat = deg2rad($lat2 - $lat1);
	my $dlon = deg2rad($lon2 - $lon1);

	my $a = sin($dlat/2)**2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dlon/2)**2;
	my $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

	my $meters = $R * $c;
	return $meters * 3.28084; # convert to feet
}

sub addTrackPoint
{
	my $now = time();
	return if !$tb_tracking;
	return if !$latitude || !$longitude;
	
	if (!$last_track_time)
	{
		$last_track_lat = $latitude;
		$last_track_lon = $longitude;
		$last_heading = $heading;
		$last_track_time = $now;
		return;
	}

	my $dt = $now - $last_track_time;
	my $dist_ft = haversine_distance_ft($last_track_lat, $last_track_lon, $latitude, $longitude);
	$speed_knots = ($dist_ft / 6076) / ($dt / 3600);
    my $heading_diff = abs($last_heading - $heading) % 360;
    $heading_diff = 360 - $heading_diff if $heading_diff > 180;

	return if ($dist_ft < 5) && ($heading_diff < 0.5);

	# Normalize inputs
	my $norm_heading = $heading_diff / 180;     # 0 to 1
	my $norm_dist    = $dist_ft / 100;          # 0 to ~1+
	my $norm_time    = $dt / 60;                # 0 to ~1+
	# my $norm_speed = 1 / (1 + exp($speed_knots - 2));
	my $norm_speed   = 1 / ($speed_knots + 0.1);# higher when slow

	# Weighted urgency score
	my $urgency = 0.4 * $norm_heading +
				  0.3 * $norm_dist +
				  0.2 * $norm_time +
				  0.1 * $norm_speed;

	printf("urgency(%0.1f) norm head(%0.2f) dist(%0.2f) time(%0.2f) speed(%0.2f)\n",
		   $urgency,
		   $norm_heading,
		   $norm_dist,
		   $norm_time,
		   $norm_speed);
	printf("   actual head(%0.1f) dist(%0.0f) time(%0.2f) speed(%0.1f)\n",
		   $heading_diff,
		   $dist_ft,
		   $dt,
		   $speed_knots);


	if ($urgency > 1.0)
	{
		printf("  ---> ADD_TRACK_POINT($latitude,$longitude)\n");
		push @$track, shared_clone([$latitude, $longitude]);
		$last_track_lat = $latitude;
		$last_track_lon = $longitude;
		$last_heading = $heading;
		$last_track_time = $now;
	}
}



sub updateTBServer
{
	my ($data) = @_;
	# display_hash(0,0,"updateTBServer",$data);
	$heading = $data->{heading} if defined($data->{heading});
	$latitude = $data->{latitude} if defined($data->{latitude});
	$longitude = $data->{longitude} if defined($data->{longitude});
	addTrackPoint();
}


#-----------------------
# ctor
#-----------------------

sub new
{
    my ($class) = @_;

	# since we do not use a prefs file, we must
	# pass in all the HTTP::ServerBase parameters

	my $no_cache =  shared_clone({
		'cache-control' => 'max-age: 603200',
	});

	my $params = {

		HTTP_DEBUG_SERVER => -1,
			# 0 is nominal debug level showing one line per request and response
		HTTP_DEBUG_REQUEST => 0,
		HTTP_DEBUG_RESPONSE => 0,

		# HTTP_DEBUG_QUIET_RE => '',
			# if the request matches this RE, the request
			# and response debug levels will be bumped by 2
			# so that under normal circumstances, no messages
			# will show for these.
		# HTTP_DEBUG_LOUD_RE => '^.*\.(?!jpg$|png$)[^.]+$',
			# An example that shows urls that DO NOT match .jpt and .png,
			# which shows JS, HTML, etc. And by setting DEBUG_REQUEST and
			# DEBUG_RESPONSE to -1, you only see headers for the debugging
			# at level 1.

		HTTP_MAX_THREADS => 5,
		HTTP_KEEP_ALIVE => 0,
			# In the ebay application, KEEP_ALIVE makes all the difference
			# in the world, not spawning a new thread for all 1000 images.

		HTTP_PORT => $SERVER_PORT,

		# Firefox image caching between invocations only works with HTTPS
		# HTTPS seems to work ok, but I get a number of untraceable
		# red "SSL attempt" failures. Even with normal HTTP, I get a number
		# of untraceable "Message(3397)::read_headers() TIMEOUT(2)"
		# red failures.

		# HTTP_SSL => 1,
		# HTTP_SSL_CERT_FILE => "/dat/Private/ssl/esp32/myIOT.crt",
		# HTTP_SSL_KEY_FILE  => "/dat/Private/ssl/esp32/myIOT.key",
		# HTTP_AUTH_ENCRYPTED => 1,
		# HTTP_AUTH_FILE      => "$base_data_dir/users/local_users.txt",
		# HTTP_AUTH_REALM     => "$owner_name Customs Manager Service",
		# HTTP_USE_GZIP_RESPONSES => 1,
		# HTTP_DEFAULT_HEADERS => {},
        # HTTP_ALLOW_SCRIPT_EXTENSIONS_RE => '',

		HTTP_DOCUMENT_ROOT => "$src_dir/site",
        HTTP_GET_EXT_RE => 'html|js|css|jpg|png|ico',

		# example of setting default headers for GET_EXT_RE extensions

		HTTP_DEFAULT_HEADERS_JPG => $no_cache,
		HTTP_DEFAULT_HEADERS_PNG => $no_cache,
	};

    my $this = $class->SUPER::new($params);

	$this->{stop_service} = 0;

	return $this;

}


#-----------------------------------------
# handle_request
#-----------------------------------------

sub handle_request
{
    my ($this,$client,$request) = @_;
	my $response;

	display(0,0,"request method=$request->{method} uri=$request->{uri}");

	# $request->{uri} = "/order_tracking.html" if $request->{uri} eq "index.html";
	# $request->{uri} = "/favicon.png" if $request->{uri} eq "/favicon.ico";

	my $uri = $request->{uri} || '';
	my $param_text = ($uri =~ s/\?(.*)$//) ? $1 : '';
	my $get_params = $request->{params};


	#-----------------------------------------------------------
	# main code
	#-----------------------------------------------------------

	if ($uri eq '/test')
	{
		my $text = 'this is a test';
		$response = http_ok($request,$text);
	}
	elsif ($uri eq '/position.kml')
	{
		my $kml = kml_header("position.kml");
		$kml .= kml_placemark('position',$latitude,$longitude,$heading);
		$kml .= kml_track();# if @$track;
		$kml .= kml_footer();
		# print "KML=$kml\n";
		$response = http_ok($request,$kml);
		$response->{headers}->{'content-type'} = 'application/vnd.google-earth.kml+xml';
	}

	#------------------------------------------
	# Let the base class handle it
	#------------------------------------------

	else
	{
		$response = $this->SUPER::handle_request($client,$request);
	}
	return $response;

}	# handle_request()






sub kml_track
{
	my $style_id = 'styleTrack';
	my $kml = '';

	# Define style for the track
	$kml .= "<Style id=\"$style_id\">$EOL";
	$kml .= "<LineStyle>$EOL";
	$kml .= "<color>ff00ffff</color>$EOL";  # yellow, transparent
	$kml .= "<width>4</width>$EOL";
	$kml .= "</LineStyle>$EOL";
	$kml .= "</Style>$EOL";

	# Build coordinates string
	my $coord_str = '';
	foreach my $pt (@$track)
	{
		my ($lat, $lon) = @$pt;
		$coord_str .= "$lon,$lat,0 ";
	}
	# always add the current lat and longitude to the end
	$coord_str .= "$longitude,$latitude,0 ";
	
	$coord_str =~ s/\s+$//;  # trim trailing space

	# Wrap in Placemark
	$kml .= "<Placemark>$EOL";
	$kml .= "<name>Track</name>$EOL";
	$kml .= "<visibility>1</visibility>$EOL";
	$kml .= "<styleUrl>#$style_id</styleUrl>$EOL";
	$kml .= "<LineString>$EOL";
	$kml .= "<coordinates>$coord_str</coordinates>$EOL";
	$kml .= "</LineString>$EOL";
	$kml .= "</Placemark>$EOL";

	return $kml;
}



sub kml_placemark
{
	my ($name,$lat,$lon,$heading,$descrip,$timestamp) = @_;

	display(0,0,"Placemark($lat,$lon)");
	
	my $kml = '';

    $kml .= '<Style id="boatStyle">'.$EOL;
    $kml .= "<IconStyle>$EOL";
    $kml .= "<scale>1.2</scale>$EOL";
    $kml .= "<heading>$heading</heading>$EOL";
    $kml .= "<Icon>$EOL";
    $kml .= "<href>http://localhost:9882/boat_icon.png</href>$EOL";
    $kml .= "</Icon>$EOL";
    $kml .= "</IconStyle>$EOL";
	$kml .= "<LabelStyle>$EOL";
    $kml .= "<scale>0</scale>$EOL";
	$kml .= "</LabelStyle>$EOL";
    $kml .= "</Style>$EOL";

	$kml .= "<Placemark>$EOL";
	$kml .= "<name>$name</name>$EOL";
	$kml .= "<visibility>1</visibility>$EOL";
	$kml .= "<description>$descrip</description>$EOL" if $descrip;
	$kml .= "<TimeStamp><when>$timestamp/when></TimeStamp>$EOL" if $timestamp;
	$kml .= "<styleUrl>boatStyle</styleUrl>$EOL";
	$kml .= "<Point>$EOL";
	$kml .= "<coordinates>$lon,$lat,0</coordinates>$EOL";
	$kml .= "</Point>$EOL";
	$kml .= "</Placemark>$EOL";
	return $kml;
}


sub kml_header
{
	my ($name) = @_;
	my $header = '<?xml version="1.0" encoding="UTF-8"?>'.$EOL;
	$header .= '<kml xmlns="http://www.opengis.net/kml/2.2" ';
	$header .= 'xmlns:gx="http://www.google.com/kml/ext/2.2" ';
	$header .= 'xmlns:kml="http://www.opengis.net/kml/2.2" ';
	$header .= 'xmlns:atom="http://www.w3.org/2005/Atom">'.$EOL;
	$header .= "<Document>$EOL";
	$header .= "<name>tbServer $name</name>$EOL";
	return $header;
}


sub kml_footer
{
	return
		"</Document>$EOL".
		"</kml>$EOL";
}


#--------------------------------------------------------
# main
#--------------------------------------------------------

display(0,0,"starting tbServer");
my $http_server = apps::teensyBoat::tbServer->new();
$http_server->start();
display(0,0,"finished starting http_server");


#---------------------------------------------------------
# Virtual NME0183 output port
#---------------------------------------------------------

if (0)
{
	use Win32::SerialPort;
	use POSIX qw(strftime);


	sub format_gprmc {
		my ($lat, $lon, $speed, $heading) = @_;
		my $time_utc = strftime("%H%M%S", gmtime);
		my $date_utc = strftime("%d%m%y", gmtime);

		my ($lat_str, $lat_dir) = decimal_to_nmea_lat($lat);
		my ($lon_str, $lon_dir) = decimal_to_nmea_lon($lon);

		my $sentence = sprintf("GPRMC,%s,A,%s,%s,%s,%s,%s,%s,,,A",
			$time_utc, $lat_str, $lat_dir, $lon_str, $lon_dir, $speed, $heading, $date_utc);

		return '$' . $sentence . '*' . checksum($sentence);
	}

	sub decimal_to_nmea_lat {
		my ($lat) = @_;
		my $dir = $lat >= 0 ? 'N' : 'S';
		$lat = abs($lat);
		my $deg = int($lat);
		my $min = ($lat - $deg) * 60;
		return (sprintf("%02d%07.4f", $deg, $min), $dir);
	}

	sub decimal_to_nmea_lon {
		my ($lon) = @_;
		my $dir = $lon >= 0 ? 'E' : 'W';
		$lon = abs($lon);
		my $deg = int($lon);
		my $min = ($lon - $deg) * 60;
		return (sprintf("%03d%07.4f", $deg, $min), $dir);
	}

	sub checksum {
		my ($sentence) = @_;
		my $sum = 0;
		$sum ^= ord($_) for split //, $sentence;
		return sprintf("%02X", $sum);
	}


	my $com_port = "COM29";  # VSPE write-end
	my $port = Win32::SerialPort->new($com_port);
	if (!$port)
	{
		error("Could not open Virtual Serial port $com_port");
	}
	else
	{
		$port->baudrate(4800);
		$port->databits(8);
		$port->parity("none");
		$port->stopbits(1);
		$port->write_settings();

		my $com_thread = threads->create(\&virtual_com_thread);
		$com_thread->detach();

	}


	sub virtual_com_thread
	{
		while (1)
		{
			if ($tb_tracking)
			{
				my $nmea = format_gprmc($latitude, $longitude, $speed_knots, $heading);
				print "Sending VIRTUAL NMEA: $nmea\n";
				$port->write("$nmea\r\n");
				sleep(1);  # 1 Hz update rate
			}
		}
	}

}	# 0


1;
