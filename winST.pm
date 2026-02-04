#!/usr/bin/perl
#-------------------------------------------------------------------------
# winST.pm
#-------------------------------------------------------------------------


package winST;
use strict;
use warnings;
use Time::HiRes qw(time);
use Wx qw(:everything);
use Wx::Event qw(
	EVT_CLOSE
	EVT_SIZE );
use Pub::Utils;
use Pub::WX::Window;
use tbUtils;
use tbBinary;
use tbConsole;
use tbListCtrl;
use base qw(Pub::WX::Window);


my $TOP_MARGIN = 40;

my $columns = [
	{name => 'count',	width => 7,		always => 1, },
	{name => 'dir',		width => 4, 	},
	{name => 'st_name',	width => 16, 	},
	{name => 'hex',		width => 35,	dynamic => 1, },
	{name => 'descrip',	width => 0, 	dynamic => 1, },
	# The last column has a variable width
];



sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display(0,0,"winST::new() called");

	$this->MyWindow($frame,$book,$id,"Seatalk",$data);

	$this->{counter} = 0;
	$this->{counts} = {};

	$this->{counter_ctrl} = Wx::StaticText->new($this,-1,"",[10,10]);
	Wx::StaticText->new($this, -1, "TTL (sec):",[150,10]);
	$this->{ttl_ctrl}  = Wx::TextCtrl->new($this, -1, "10", [220,8],[50,20]);
	$this->{list_ctrl} = tbListCtrl->new($this,$TOP_MARGIN,$columns,$this->{ttl_ctrl});

	# restore ini file data (zoom_level, ttl, etc) if available

	if ($data)
	{
		display_hash(0,0,"winST::data",$data);
		$this->{list_ctrl}->setZoomLevel($data->{zoom_level}) if $data->{zoom_level};
		$this->{ttl_ctrl}->SetValue($data->{ttl_value}) if $data->{ttl_value};
	}

	EVT_SIZE($this, \&onSize);
	EVT_CLOSE($this,\&onClose);

	$this->initTBCommands();
	return $this;
}


sub initTBCommands
	# called from ctor and when com port opened
{
	my ($this) = @_;
	sendTeensyCommand("B_ST=1");
}


sub onClose
	# turn off binary binary SIM data
{
    my ($this,$event) = @_;
	sendTeensyCommand("B_ST=0");
	$this->SUPER::onClose($event);
}


sub onSize
{
	my ($this,$event) = @_;
	my $sz = $this->GetSize();
	my $width = $sz->GetWidth();
    my $height = $sz->GetHeight();
	$this->{list_ctrl}->SetSize($width,$height-$TOP_MARGIN);
}


sub onActivate
	# Called by Pub::WX::FrameBase when the window is made active
{
	my ($this) = @_;
	display(0,0,"onActivate()");
	$this->Update();
	$this->{list_ctrl}->onSize() if $this->{list_ctrl};
}


sub handleBinaryData
{
	my ($this,$counter,$type,$packet) = @_;
	$this->{counter_ctrl}->SetLabel($this->{counter}++);
	
	my $rec = {};
	my $str = substr($packet,2);
		# skip the overall binary packet length
	my @values = split(/\t/, $str);
	for my $i (1..@$columns-1)
	{
		my $col_info = $columns->[$i];
		my $name = $col_info->{name};
		my $value = $values[$i-1];
		$rec->{$name} = defined($value) ? $value : '';
	}

	# this window is the only one who keeps track
	# of the count-per-message, and it is not part of the
	# binary data
	
	# my $st = substr($rec->{hex},0,2);
	my $key = $rec->{dir}.$rec->{st_name};
	my $counts = $this->{counts};
	$counts->{$key} ||= 0;
	$counts->{$key}++;
	$rec->{count} = $counts->{$key};

	$this->{list_ctrl}->notifyDataChanged($key,$rec);
}


sub notifyDelete
{
	my ($this,$rec) = @_;
	my $key = $rec->{dir}.$rec->{st_name};
	my $counts = $this->{counts};
	delete $counts->{$key};
}


sub getDataForIniFile
{
	my ($this) = @_;
	my $data = {};

	$data->{zoom_level} = $this->{list_ctrl}->{zoom_level};
	$data->{ttl_value} = $this->{ttl_ctrl}->GetValue();
	
	return $data;
}



1;
