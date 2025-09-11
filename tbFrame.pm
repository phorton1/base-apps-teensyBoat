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
use apps::teensyBoat::tbWin;
use apps::teensyBoat::tbConsole;
use base qw(Pub::WX::Frame);


sub new
{
	my ($class, $parent) = @_;
	my $this = $class->SUPER::new($parent);

	EVT_MENU($this, $TB_WINDOW, \&onCommand);
    EVT_IDLE($this, \&onIdle);

	my $data = undef;
	$this->createPane($TB_WINDOW,$this->{book},$data,"test237");

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
		# display(0,0,"Frame got binary_data len=".length($binary_data));
		my $main_window = $this->findPane($TB_WINDOW);
		$main_window->handleBinaryData($counter,$binary_data) if $main_window;
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
	if ($id >= $TB_WINDOW && $id <= $TB_WINDOW)
	{
        return apps::teensyBoat::tbWin->new($this,$book,$id,"test236 $id");
    }
    return $this->SUPER::createPane($id,$book,$data,"test237");
}


sub onCommand
{
    my ($this,$event) = @_;
    my $id = $event->GetId();
	# $port->write("x10\r\n") if $port && $id == $COMMAND1;
	# $port->write("x0\r\n") if $port && $id == $COMMAND2;

    my $pane = $this->findPane($id);
	display(0,0,"$appName onCommand($id) pane="._def($pane));
    if (!$pane)
    {
        my $book = $this->{book};
		$pane = apps::teensyBoat::tbWin->new($this,$book,$id,"command($id)");
    }
}



1;
