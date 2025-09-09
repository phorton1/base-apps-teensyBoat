#!/usr/bin/perl
#-------------------------------------------------------------------------
# a minimal full featured application
#-------------------------------------------------------------------------

package resources;
use strict;
use warnings;
#use Wx qw(wxAUI_NB_BOTTOM);
#use Wx::AUI;
use Pub::WX::Resources;
use Pub::WX::AppConfig;

# My::Utils::USE_WIN_CONSOLE_COLORS();


$ini_file = "/junk/minimum.ini";


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw (
        $resources
        $COMMAND1
        $COMMAND2
        $COMMAND3
    );
}

# derived class decides if wants viewNotebook
# commands added to the view menu, by setting
# the 'command_id' member on the notebook info.

our ($COMMAND1,
     $COMMAND2,
     $COMMAND3 )= (10000..11000);


# Pane data that allows looking up of notebook for windows
# Sheesh, have to add the monitor to get it to open & close

my %pane_data = (
	$COMMAND1	=> ['Command1',		'content'	],
	$COMMAND2	=> ['Command2',		'output'	],
	$COMMAND3	=> ['Command3 this text not used', 'content'	]
);


# Command data for this application.
# Notice the merging that takes place
# with the base appResources

my %command_data = (%{$resources->{command_data}},
	$COMMAND1     => ['Command1', 'Do something interesting1'],
	$COMMAND2     => ['Command2', 'Do something interesting2'],
	$COMMAND3     => ['Command3', 'Do something interesting3']
);


# Notebook data includes an array "in order",
# and a lookup by id for notebooks to be opened by
# command id's

my %notebook_data = (
	content  => {
        name => 'content',
        row => 1,
        pos => 1,
        position => '',
        title => 'Content Notebook' },
);


my @notebooks = (
    $notebook_data{content});


# lookup of name by id for those with command_ids
# prh - could be generated on fly in appFrame.pm

my %notebook_name = (
);


# Menus

my @main_menu = (
    'view_menu,&View',
    'menu1,&Menu1',
    'menu2,&Menu2' );

my @menu1 = (
	$COMMAND1,
    $ID_SEPARATOR,
	$COMMAND2
);

my @menu2 = (
	$COMMAND3,
);


# Merge and reset the single public object

$resources = { %$resources,
    app_title       => 'minimum',
    temp_dir        => '/base/apps/minimum/temp',
    ini_file        => '/base/apps/minimum/data/minimum.ini',
    logfile         => '/base/apps/minimum/data/minimum.log',

    command_data    => \%command_data,
    notebooks       => \@notebooks,
    notebook_data   => \%notebook_data,
    notebook_name   => \%notebook_name,
    pane_data       => \%pane_data,
    main_menu       => \@main_menu,
    menu1           => \@menu1,
    menu2           => \@menu2

};


#-----------------------------------------
# an example window
#-----------------------------------------

package xyz_window;
use strict;
use warnings;
use Wx qw(:everything);
use Pub::Utils;
use Pub::WX::Window;
# use MyMS::IE;
use base qw(Wx::Window MyWX::Window);

sub new
{
	my ($class,$frame,$book,$id,$xyz_junk) = @_;
	my $this = $class->SUPER::new($book,$id);
	display(0,0,"xyz_window::new($id,$xyz_junk) called");
	$this->MyWindow($frame,$book,$id,"$xyz_junk xyz_window");

    # $this->{browser} = MyMS::IE->new($this, -1, [10,60],[300,300]);
    # $this->{browser}->LoadString("<b>THIS IS A TEST $xyz_junk</b>");

	return $this;
}


#----------------------------------------------
# The main frame, most of the functionality
#----------------------------------------------

package minimumFrame;
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
use base qw(Pub::WX::Frame);

my $USE_LOW_THREAD = 1;


use bat::console_Colors;
Pub::Utils::initUtils();
my $con = Win32::Console->new(STD_OUTPUT_HANDLE);
my $in = Win32::Console->new(STD_INPUT_HANDLE);
$in->Mode(ENABLE_MOUSE_INPUT | ENABLE_WINDOW_INPUT );
$con->Attr($COLOR_CONSOLE);

sub new
{
	my ($class, $parent) = @_;
	my $this = $class->SUPER::new($parent);

	EVT_MENU($this, $COMMAND1, \&onCommand);
	EVT_MENU($this, $COMMAND2, \&onCommand);
	EVT_MENU($this, $COMMAND3, \&onCommand);
    EVT_IDLE($this, \&onIdle) if !$USE_LOW_THREAD;
;

	return $this;
}



#------------------------------------------------
# low level
#------------------------------------------------

my $COM_PORT = 14;
my $BAUD_RATE = 115200;

my $port;
my $port_check_time = 0;
my $connect_fail_reported = 0;


sub initComPort
{
    display(0,0,"initComPort($COM_PORT,$BAUD_RATE");

    my $port = Win32::SerialPort->new("COM$COM_PORT",1);

    if ($port)
    {
		display(0,0,"Win32::SerialPort(COM_PORT) created");

        # This code modifes Win32::SerialPort to allow higher baudrates

        $port->{'_L_BAUD'}{78440} = 78440;
        $port->{'_L_BAUD'}{230400} = 230400;
        $port->{'_L_BAUD'}{460800} = 460800;
        $port->{'_L_BAUD'}{921600} = 921600;
        $port->{'_L_BAUD'}{1843200} = 1843200;

        $port->baudrate($BAUD_RATE);
        $port->databits(8);
        $port->parity("none");
        $port->stopbits(1);

        # $port->buffers(8192, 8192);
        $port->buffers(60000,8192);

        $port->read_interval(100);    # max time between read char (milliseconds)
        $port->read_char_time(5);     # avg time between read char
        $port->read_const_time(100);  # total = (avg * bytes) + const
        $port->write_char_time(5);
        $port->write_const_time(100);

        $port->handshake("none");   # "none", "rts", "xoff", "dtr".
			# handshaking needed to be turned off for uploading binary files
            # or else sending 0's, for instance, would freeze

		# $port->dtr_active(1);
        # $port->binary(1);

        if (!$port->write_settings())
        {
            warning(0,0,"Could not call $port->write_settings()");
        }

		$port->binary(1);	# probably not needed

		# identify ESP32 weirdness where nobody can
		# set the baud rate to 115200 after pgm upload

		# display_hash(0,0,"port",$port);

		my $actual_baud = $port->{BAUD};
		if ($actual_baud != $BAUD_RATE)
		{
			warning(0,0,"!!! COM$COM_PORT ACTUAL_BAUD($actual_baud) <> BAUD_RATE($BAUD_RATE) !!!");
		}

		display(0,0,"COM$COM_PORT connected at baud($BAUD_RATE)");
    }
	else
	{
		warning(0,0,"could not create Win32::SerialPort($COM_PORT)");
	}
    return $port;
}





sub getChar
{
    my (@event) = @_;
    if ($event[0] &&
        $event[0] == 1 &&       # key event
        $event[1] == 1 &&       # key down
        $event[5])              # char
    {
        return chr($event[5]);
    }
    return undef;
}


sub isEventCtrlC
    # my ($type,$key_down,$repeat_count,$key_code,$scan_code,$char,$key_state) = @event;
    # my ($$type,posx,$posy,$button,$key_state,$event_flags) = @event;
{
    my (@event) = @_;
    if ($event[0] &&
        $event[0] == 1 &&      # key event
        $event[5] == 3)        # char = 0x03
    {
        print "ctrl-C pressed ...\n";
        return 1;
    }
    return 0;
}


sub exitConsole
{
	if ($port)
	{
		$port->close();
		$port = undef;
	}
		kill 6,$$;
}



sub low_level
{
	my $now = time();
	if ($port)
	{
		$port_check_time = $now;
		my ($BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags) = $port->status();
		if (!defined($BlockingFlags))
		{
			display(0,0,"COM$COM_PORT disconnected");
			$port = undef;
		}
		elsif ($InBytes)
		{
			my ($bytes,$buf) = $port->read($InBytes);
			print $buf if $bytes;
			#display(0,0,"got($bytes) bytes len=".length($buf));
			#display_bytes(0,0,"buf",$buf);
		}
	}
	elsif (!$port && $now > $port_check_time + 3)
	{
		$port_check_time = $now;
		$port = initComPort();
	}


    if ($in->GetEvents())
    {
        my @event = $in->Input();
        # print "got event '@event'\n" if @event;
        if (@event && isEventCtrlC(@event))			# CTRL-C
        {
			exitConsole(1);
        }

        my $char = getChar(@event);

		if (defined($char))
		{
			if ($con && ord($char) == 4)            # CTRL-D
			{
				$con->Cls();    # manually clear the screen
			}


			# send console-in chars to $port or $sock

			elsif ($port)
			{
				# print "write ".($port?"PORT":$sock?"SOCK":"NULL")." chr(".ord($char).")\n";

				$port->write($char);

				if (ord($char) == 13)
				{
					if (1) 	# $echo || $crlf)
					{
						$port->write(chr(10)); #   if $crlf;
						print "\r\n";;
					}
				}
				elsif (1)	# $echo)
				{
					if (ord($char)==8)
					{
						print $char;
						print " ";
						print $char;
					}
					elsif (ord($char) >= 32)
					{
						print $char;
					}
				}
			}
		}
    }
}


sub low_thread
{
	while (1)
	{
		low_level();
		sleep(0.01);
	}
}



if ($USE_LOW_THREAD)
{
    my $low_thread = threads->create(\&low_thread);
    $low_thread->detach();
}



#----------------------------------------------------
# event driven
#----------------------------------------------------

my $counter = 0;

sub onIdle
		# only hooked up if !$USE_LOW_THREAD
{
    my ($this,$event) = @_;
	# display(0,0,"onIdle($counter)");
	$counter++;


	low_level();	# if !$USE_LOW_THREAD;

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
	if ($id >= $COMMAND1 && $id <= $COMMAND3)
	{
        return xyz_window->new($this,$book,$id,"test236 $id");
    }
    return $this->SUPER::createPane($id,$book,$data,"test237");
}


sub onCommand
{
    my ($this,$event) = @_;
    my $id = $event->GetId();
	$port->write("x10\r\n") if $port && $id == $COMMAND1;
	$port->write("x0\r\n") if $port && $id == $COMMAND2;

    my $pane = $this->findPane($id);
	display(0,0,"minimumFrame::onCommand($id) pane="._def($pane));
    if (!$pane)
    {
        my $book = $this->{book};
		$pane = xyz_window->new($this,$book,$id,"command($id)");
    }
}



#----------------------------------------------------
# CREATE AND RUN THE APPLICATION
#----------------------------------------------------
# This chunk of code, particularly must be at the
# end of some perl script to cause the app to run

package minimumApp;
use strict;
use warnings;
use Pub::Utils;
use Pub::WX::Resources;
use Pub::WX::Main;
use base 'Wx::App';

my $frame;

sub OnInit
{
	$frame = minimumFrame->new();
	if (!$frame)
	{
		error("unable to create frame");
		return undef;
	}

	$frame->Show( 1 );
	display(0,0,"$$resources{app_title} started");
	return 1;
}

my $app = minimumApp->new();
Pub::WX::Main::run($app);


display(0,0,"ending minimum.pm frame=$frame");
$frame->DESTROY() if $frame;
$frame = undef;
display(0,0,"finished minimum.pm");



1;
