#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbFrame.pm
#-------------------------------------------------------------------------

package tbFrame;
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
use tbUtils;
use tbResources;
use tbConsole;
use tbBinary;
use winProg;
use winBoatSim;
use winST;
use base qw(Pub::WX::Frame);


my $dbg_frame = 1;
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

	Pub::WX::Frame::setHowRestore(
		# $RESTORE_MAIN_RECT);
		$RESTORE_ALL);

	my $this = $class->SUPER::new($parent);

	EVT_MENU($this, $WIN_PROG, \&onCommand);
	EVT_MENU($this, $WIN_BOAT_SIM, \&onCommand);
	EVT_MENU($this, $WIN_SEATALK, \&onCommand);
    EVT_IDLE($this, \&onIdle);

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

		if ($type == $BINARY_TYPE_PROG)
		{
			my $prog_window = $this->findPane($WIN_PROG);
			$prog_window->handleBinaryData($counter,$type,$packet) if $prog_window;
		}
		elsif ($type == $BINARY_TYPE_SIM)
		{
			my $boat_sim = $this->findPane($WIN_BOAT_SIM);
			$boat_sim->handleBinaryData($counter,$type,$packet) if $boat_sim;
		}
		elsif ($type == $BINARY_TYPE_ST1 || $type == $BINARY_TYPE_ST2)
		{
			my $st_window = $this->findPane($WIN_SEATALK);
			$st_window->handleBinaryData($counter,$type,$packet) if $st_window;
		}
		elsif ($type == $BINARY_TYPE_0183A)
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
{
	my ($this,$id,$book,$data) = @_;
	return error("No id in createPane()") if (!$id);
    $book ||= $this->{book};
	display($dbg_frame,0,"tbFrame::createPane($id) book="._def($book)."  data="._def($data));
	return winProg->new($this,$book,$id,$data) if $id == $WIN_PROG;
	return winBoatSim->new($this,$book,$id,$data) if $id == $WIN_BOAT_SIM;
	return winST->new($this,$book,$id,$data) if $id == $WIN_SEATALK;
    return $this->SUPER::createPane($id,$book,$data);
}



sub onCommand
{
    my ($this,$event) = @_;
    my $id = $event->GetId();
	if ($id == $WIN_PROG ||
		$id == $WIN_BOAT_SIM ||
		$id == $WIN_SEATALK)
	{
    	my $pane = $this->findPane($id);
		display($dbg_frame,0,"$appName onCommand($id) pane="._def($pane));
    	$this->createPane($id) if !$pane;
	}
}



1;
