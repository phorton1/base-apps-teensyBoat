#!/usr/bin/perl
#-------------------------------------------------------------------------
# the console for the teensyBoat.pm application
#-------------------------------------------------------------------------

package apps::teensyBoat::tbConsole;
use strict;
use warnings;
use threads;
use threads::shared;
use Time::HiRes qw(time sleep);
use Win32::Console;
use Win32::SerialPort;
use Win32::Process::List;
use Pub::Utils;
use apps::teensyBoat::tbUtils;
use apps::teensyBoat::consoleColors;

my $SET_DATE_AUTOMATICALLY = 1;


our $COM_PORT:shared = 14;
our $BAUD_RATE:shared = 115200;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(
		$COM_PORT
		$BAUD_RATE
		$binary_queue
	);
}

our $binary_queue:shared = shared_clone([]);

my $port;
my $port_check_time = 0;
my $in_arduino_build:shared = 0;




my $in_binary:shared  = 0;
	# 1 = next byte is low order of len
	# 2 = next bye is high order of len
	# 3 = in length portion
my $binary_time:shared = 0;
my $binary_len:shared = 0;
my $binary_got:shared = 0;
my $binary_data:shared = '';


my $in_ansi:shared = 0;
	# 1 = next byte is ansi_type
my $ansi_time:shared = 0;
my $ansi_type:shared = 0;
my $ansi_attr:shared = 0;
my $ansi_buf:shared = '';



my $in = Win32::Console->new(STD_INPUT_HANDLE);
$in->Mode(ENABLE_MOUSE_INPUT | ENABLE_WINDOW_INPUT );
$CONSOLE->Attr($DISPLAY_COLOR_NONE);

my $console_thread = threads->create(\&console_thread);
$console_thread->detach();

my $arduino_thread = threads->create(\&arduino_thread);
$arduino_thread->detach();


#------------------------------------
# utilities
#------------------------------------

sub consoleError
{
	my ($msg) = @_;
	$CONSOLE->Attr($DISPLAY_COLOR_ERROR);
	print "console Error: $msg\n";
	$CONSOLE->Attr($DISPLAY_COLOR_NONE);
}

sub consoleWarning
{
	my ($msg) = @_;
	$CONSOLE->Attr($DISPLAY_COLOR_WARNING);
	print "console Warning: $msg\n";
	$CONSOLE->Attr($DISPLAY_COLOR_NONE);
}

sub consoleMsg
{
	my ($msg) = @_;
	$CONSOLE->Attr($DISPLAY_COLOR_NONE);
	print "console: $msg\n";
}

sub consoleAttn
{
	my ($msg) = @_;
	$CONSOLE->Attr($DISPLAY_COLOR_LOG);
	print "console: $msg\n";
	$CONSOLE->Attr($DISPLAY_COLOR_NONE);
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


sub isEventCtrlC
    # my ($type,$key_down,$repeat_count,$key_code,$scan_code,$char,$key_state) = @event;
    # my ($$type,posx,$posy,$button,$key_state,$event_flags) = @event;
{
    my (@event) = @_;
    if ($event[0] &&
        $event[0] == 1 &&      # key event
        $event[5] == 3)        # char = 0x03
    {
        consoleAttn("ctrl-C pressed ...");
        return 1;
    }
    return 0;
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


#---------------------------------
# initComPort()
#---------------------------------

sub initComPort
{
    consoleMsg("initComPort($COM_PORT,$BAUD_RATE)");

    my $port = Win32::SerialPort->new("COM$COM_PORT",1);

    if ($port)
    {
		consoleMsg("Win32::SerialPort(COM_PORT) created");

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
            consoleError("Could not call $port->write_settings()");
        }

		$port->binary(1);	# probably not needed

		# identify ESP32 weirdness where nobody can
		# set the baud rate to 115200 after pgm upload

		# display_hash(0,0,"port",$port);

		my $actual_baud = $port->{BAUD};
		if ($actual_baud != $BAUD_RATE)
		{
			consoleWarning("!!! COM$COM_PORT ACTUAL_BAUD($actual_baud) <> BAUD_RATE($BAUD_RATE) !!!");
		}

		consoleMsg("COM$COM_PORT connected at baud($BAUD_RATE)");
    }
	else
	{
		consoleError("could not create Win32::SerialPort($COM_PORT)");
	}
    return $port;
}



#--------------------------------------
# arduino_thread
#--------------------------------------

sub arduino_thread
	# watch for a process indicating an Arduino build is happening
	# and disconnect the comm port if it is
{
    while (1)
	{
		my $found = 0;
		my $pl = Win32::Process::List->new();
		my %processes = $pl->GetProcesses();

		# print "PROCESS::LIST\n";
		foreach my $pid (sort {$processes{$a} cmp $processes{$b}} keys %processes )
		{
			my $name = $processes{$pid};
			# print "$name\n" if $name;
			if ($name =~ /arduino-builder\.exe|esptool\.exe/)
			{
				# print "Found process $name\n";
				$found = 1;
				last;
			}
		}

        if ($found && !$in_arduino_build)
        {
            $in_arduino_build = 1;
            consoleAttn("in_arduino_build=$in_arduino_build");
        }
        elsif ($in_arduino_build && !$found)
        {
			consoleAttn("in_arduino_build=0 ... sleeping for 2 seconds");
            sleep(2);
            $in_arduino_build = 0;
        }

        sleep(1);
    }
}



#--------------------------------------------
# console_thread
#--------------------------------------------

sub console_thread
{
	while (1)
	{
		console_loop();
		sleep(0.01);
	}
}


sub console_loop
{
	if ($in_arduino_build && $port)
    {
        consoleAttn("COM$COM_PORT closed for Arduino Build");
        $port->close();
        $port = undef;
    }


	my $now = time();
	if ($port)
	{
		$port_check_time = $now;
		my ($BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags) = $port->status();
		if (!defined($BlockingFlags))
		{
			consoleAttn("COM$COM_PORT disconnected");
			initInParser();
			$port = undef;
		}
		elsif ($InBytes)
		{
			my ($bytes,$buf) = $port->read($InBytes);
			handleComBytes($buf) if $bytes;
			#display(0,0,"got($bytes) bytes len=".length($buf));
			#display_bytes(0,0,"buf",$buf);
		}
		else
		{
			checkInTimeout();
		}
	}
	elsif (!$in_arduino_build && !$port && $now > $port_check_time + 3)
	{
		$port_check_time = $now;
		$port = initComPort();

		# $SET_DATE_AUTOMATICALLY
		$port->write("DT=".now(1,1)."\r\n") if $port && $SET_DATE_AUTOMATICALLY;
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
			if (ord($char) == 4)            # CTRL-D
			{
				$CONSOLE->Cls();    # manually clear the screen
			}
			else
			{
				# weird behavior
				# character doesn't show until we send the \r\n.
				# so, for time being, each character is on its own line
				# and a return will show a blank line
				
				print "$char\r\n";

				# $CONSOLE->Write($char."\r\n");
				# $CONSOLE->Write("\r\n") if ord($char) == 0x13;
				#$CONSOLE->Display();

				# send console-in chars to $port

				if ($port)
				{
					$port->write($char);
					$port->write(chr(10)) if ord($char) == 13;
				}
			}
		}
    }
}



#---------------------------------
# handle input from com port
#---------------------------------
# 0x02 = binary buffer followed by 2 byte length
# 	which can come in the middle of regular debugging output
#   and assumed to be contiquous, including a checksum.
#   otherwise, We assume it's regular text output with terminating \r\n
#   and which may contain ansi codes in the middle
# My ansi format is somewhat standard
#   Escape Sequences start with esc followed by a "type" character
#   The type character '[' is a a color sequence
#		colors 30-37 and 90-97 are foreground colors
#		colors 40-47 and 100-107 are background colors
#   	The [ sequence is terminated by an 'm'
#   If there's a semicolon, there will be a second color.


sub initBinaryParser
{
	$in_binary  = 0;
	$binary_time = 0;
	$binary_len = 0;
	$binary_got = 0;
	$binary_data = '';
}

sub initAnsiParser
{
	$in_ansi = 0;
	$ansi_type = 0;
	$ansi_attr= 0;
	$ansi_buf = '';
}

sub initInParser
{
	initBinaryParser();
	initAnsiParser();
}

sub checkInTimeout
{
	my $now = time();
	if ($in_binary && $now-$binary_time > 0.5)
	{
		consoleError("binaryParser timeout!");
		initBinaryParser();
	}
	if ($in_ansi && $now-$ansi_time > 0.5)
	{
		consoleError("ansiParser timeout!");
		initAnsiParser();
	}
}



sub handleComBytes
{
	my ($buf) = @_;
	my $len = length($buf);
	my $now = time();

	# display_bytes(0,0,"buf($len)",$buf);

	for (my $i=0; $i<$len; $i++)
	{
		my $char = substr($buf,$i,1);

		if ($in_binary == 1)
		{
			$binary_len = ord($char);
			$in_binary++;
			$binary_time = $now;
		}
		elsif ($in_binary == 2)
		{
			$binary_len += ord($char) << 8;
			$in_binary++;
			$binary_time = $now;
			# print "binary_len=$binary_len\n";
		}
		elsif ($in_binary == 3)
		{
			$binary_data .= $char;
			$binary_got++;
			$binary_time = $now;
			if ($binary_got == $binary_len)
			{
				# print "binary_got=$binary_len=".length($binary_data)."\n";
				# display_bytes(0,0,"binary_data($binary_len)",$binary_data);
				push @$binary_queue,$binary_data;
				initBinaryParser();
			}
		}
		elsif (ord($char) == 0x02)
		{
			$in_binary = 1;
			$binary_time = $now;
		}
		elsif (ord($char) == 0x1b)
		{
			$in_ansi = 1;
			$ansi_time = $now;
		}
		elsif ($in_ansi == 1)
		{
			$ansi_type = $char;
			if ($ansi_type ne '[')
			{
				consoleError("Unsupported Ansi Type: $ansi_type");
				initAnsiParser();
			}
			else
			{
				$ansi_time = $now;
				$in_ansi++;
			}
		}
		elsif ($in_ansi == 2)
		{
			if ($char eq ';' || $char eq 'm')
			{
				# print "ansi_buf=$ansi_buf\n";
				$ansi_attr |= colorAttr($ansi_buf);
				$ansi_buf = '';
			}
			else
			{
				$ansi_buf .= $char;
			}
			if ($char eq 'm')
			{
				$CONSOLE->Attr($ansi_attr);
				$in_ansi = 3;
			}
		}
		elsif ($char eq "\n")
		{
			print $char;
			if ($in_ansi)
			{
				$CONSOLE->Attr($DISPLAY_COLOR_NONE);
				initAnsiParser();
			}
		}
		else
		{
			print $char;
		}
	}

	return;





	my $attr;

	# display_bytes(0,0,"buf",$buf);
	
	for my $line (split(/\r\n/,$buf))
	{
		if ($line =~ s/\x1b\[(\d+)m//)
		{
			my $color = $1;
			# print "setting color($color)\n";
			$attr = colorAttr($color);
		}
		elsif ($line =~ s/\x1b\[(\d+);(\d+)m//)
		{
			my ($fg,$bg) = ($1,$2);
			$bg -= 10;
			# print "setting color($fg,$bg)\n";
			$attr = colorAttr($bg)<<4 | colorAttr($fg);
		}
		elsif ($line =~ s/\x1b\[[23]J//)
		{
			$CONSOLE->Cls();
		}

		if (length($line))
		{
			$CONSOLE->Attr($attr) if $attr;
			print $line."\r\n";
			$CONSOLE->Attr($DISPLAY_COLOR_NONE) if $attr;
		}
	}
}



1;
