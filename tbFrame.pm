#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbFrame.pm
#-------------------------------------------------------------------------

package apps::teensyBoat::tbFrame;
use strict;
use warnings;
use threads;
use threads::shared;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_IDLE
	EVT_MENU);
use Time::HiRes qw(time sleep);
use Pub::Utils;
use Pub::WX::Frame;
use Win32::SerialPort;
use Win32::Console;
use apps::teensyBoat::tbResources;
use apps::teensyBoat::tbConsole;
use apps::teensyBoat::tbServer;
use apps::teensyBoat::tbBinary;
use apps::teensyBoat::winBoat;
use apps::teensyBoat::winST;

use base qw(Pub::WX::Frame);

my $dbg_binary = 1;


#-------------------------------------------
# nmea0183 experiment
#-------------------------------------------

my $nmea_port ;

if (0)
{
	my $nmea_port_str = "COM29";  # VSPE write-end
	my $nmea_port = Win32::SerialPort->new($nmea_port_str);
	if (!$nmea_port)
	{
		error("Could not open Virtual Serial port $nmea_port_str");
	}
	else
	{
		$nmea_port->baudrate(115200);	# 4800);
		$nmea_port->databits(8);
		$nmea_port->parity("none");
		$nmea_port->stopbits(1);
		$nmea_port->write_settings();
	}
}



#-----------------------------------------------------------
# frame
#----------------------------------------------------------

sub new
{
	my ($class, $parent) = @_;
	my $this = $class->SUPER::new($parent);

	EVT_MENU($this, $WIN_BOAT, \&onCommand);
    EVT_IDLE($this, \&onIdle);

	my $data = undef;
	$this->createPane($WIN_BOAT,$this->{book},$data,"test237");
	$this->createPane($WIN_SEATALK,$this->{book},$data,"test237");

	# startConsole();
	
	return $this;
}



my $counter= 0;



sub onIdle
{
    my ($this,$event) = @_;

	if (@$binary_queue)
	{
		$counter++;
		my $binary_data = shift @$binary_queue;
		my $type = unpack("S",$binary_data);		# little endian uint16_t
		my $packet = substr($binary_data,2);
		my $len = length($binary_data);
		display($dbg_binary,0,"Frame got binary_packet type($type) len=$len)");
		display_bytes($dbg_binary+1,0,"packet($len)",$packet);

		if ($type == $BINARY_TYPE_BOAT)
		{
			my $boat_window = $this->findPane($WIN_BOAT);
			$boat_window->handleBinaryData($counter,$type,$packet) if $boat_window;
		}
		elsif ($type == $BINARY_TYPE_ST)
		{
			my $st_window = $this->findPane($WIN_SEATALK);
			$st_window->handleBinaryData($counter,$type,$packet) if $st_window;
		}
		elsif ($type == $BINARY_TYPE_0183)
		{
			if ($nmea_port)
			{
				my $LEN_SIZE = 4;
				my $nmea_msg = substr($binary_data,$LEN_SIZE);	# skip the length word; the rest is text
				display(0,1,"NMEA_FAKE($counter) -->$nmea_msg");
				$nmea_port->write($nmea_msg."\r\n");
				sleep(0.01);
			}
		}
	}

	$event->RequestMore(1);
}



sub createPane
	# factory method must be implemented if derived
    # classes want their windows restored on opening.
    # The example could be much more complex with
    # config_strs on the xyz_window, instances, etc.
{
	my ($this,$id,$book,$data) = @_;
	return error("No id in createPane()") if (!$id);
    $book ||= $this->{book};
	display(0,0,"minimumFrame::createPane($id) book="._def($book)."  data="._def($data));
	return apps::teensyBoat::winBoat->new($this,$book,$id,"test236 $id") if $id == $WIN_BOAT;
	return apps::teensyBoat::winST->new($this,$book,$id,"test236 $id") if $id == $WIN_SEATALK;
    return $this->SUPER::createPane($id,$book,$data,"test237");
}


sub onCommand
{
    my ($this,$event) = @_;
    my $id = $event->GetId();
	# $port->write("x10\r\n") if $port && $id == $COMMAND1;
	# $port->write("x0\r\n") if $port && $id == $COMMAND2;

    #	my $pane = $this->findPane($id);
	#	display(0,0,"$appName onCommand($id) pane="._def($pane));
    #	if (!$pane)
    #	{
    #	    my $book = $this->{book};
	#		$pane = apps::teensyBoat::tbWin->new($this,$book,$id,"command($id)");
    #	}
}




1;
