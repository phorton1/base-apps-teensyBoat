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
	EVT_SIZE );
use Pub::Utils;
use Pub::WX::Window;
use tbUtils;
use tbBinary;
use tbListCtrl;
use base qw(Pub::WX::Window);

my $CHANGE_TIMEOUT = 2;
my $TOP_MARGIN = 40;
my $LINE_HEIGHT = 20;

my $LEN_SIZE = 2;
my $COUNT_SIZE = 7;
my $DIR_STR_SIZE = 3;
my $ST_NAME_SIZE = 12 + 3;
my $HEX_SIZE = 27;
my $MAX_INST_NAME = 10;


my $slots = {};
my $columns = [
	{	name => 'count',
		always => 1,
		width => $COUNT_SIZE, },
	{	name => 'dir',
		width => $DIR_STR_SIZE + 1, },
	{	name => 'name',
		width => $ST_NAME_SIZE + 1, },
	{	name => 'hex',
		dynamic => 1,
		width => $HEX_SIZE + 1, },
	{	name => 'data',
	    dynamic => 1,
		width => 10, },
];


my $frame_counter_ctrl;
my $st_counter_ctrl;
my $st_counter = 0;

my $font_fixed = Wx::Font->new(12,wxFONTFAMILY_MODERN,wxFONTSTYLE_NORMAL,wxFONTWEIGHT_BOLD);


sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display(0,0,"winST::new() called");
	$this->MyWindow($frame,$book,$id,"Seatalk",$data);

	$slots = {};

	$frame_counter_ctrl = Wx::StaticText->new($this,-1,"",[10,10]);
	$st_counter_ctrl = Wx::StaticText->new($this,-1,"",[50,10]);
	$this->{list_ctrl} = tbListCtrl->new($this,$TOP_MARGIN,$columns,$slots);

	EVT_SIZE($this, \&onSize);

	return $this;
}


sub onSize
{
	my ($this,$event) = @_;
	my $sz = $this->GetSize();
	my $width = $sz->GetWidth();
    my $height = $sz->GetHeight();
	$this->{list_ctrl}->SetSize($width,$height-$TOP_MARGIN);
}


sub handleBinaryData
{
	my ($this,$counter,$type,$packet) = @_;
	$frame_counter_ctrl->SetLabel($counter);
	$st_counter_ctrl->SetLabel($st_counter++);

	my $LEN_SIZE = 2;
	my $COUNT_SIZE = 7;
	my $DIR_STR_SIZE = 3;
	my $ST_NAME_SIZE = 12 + 3;
	my $HEX_SIZE = 27;
	my $MAX_INST_NAME = 10;

	my $offset = $LEN_SIZE + $COUNT_SIZE;
	my $dir = substr($packet,$offset,$DIR_STR_SIZE);
	$offset += $DIR_STR_SIZE + 1;;
	my $name = substr($packet,$offset,$ST_NAME_SIZE);
	$offset += $ST_NAME_SIZE + 1;
	my $hex = substr($packet,$offset,$HEX_SIZE);
	$offset += $HEX_SIZE + 1;
	my $inst = substr($packet,$offset,$MAX_INST_NAME);
	$offset += $MAX_INST_NAME + 1;
	my $data = substr($packet,$offset);
	my $st = substr($hex,0,2);

	my $found = $slots->{$st};
	if ($found)
	{
		$found->{count}++;
		if ($found->{hex} ne $hex || $found->{dir} ne $dir)
		{
			$found->{changed} = 3;
			$found->{time} = time();
			$found->{dir} = $dir;
			$found->{old_hex} = $found->{hex};
			$found->{old_data} = $found->{data};
			$found->{hex} = $hex;
			$found->{data} = $data;
		}
	}
	else
	{
		$slots->{$st} = {
			dir => $dir,
			count => 1,
			changed => 3,
			time => time(),
			name => $name,
			hex => $hex,
			inst => $inst,
			data => $data, };

		my $num = 0;
		my @sts = sort keys %$slots;
		for my $st (@sts)
		{
			$slots->{$st}->{num} = $num++;
		}
	}

	$this->{list_ctrl}->notifyDataChanged($st);
}


sub onActivate
	# Called by Pub::WX::FrameBase when the window is made active
{
	my ($this) = @_;
	display(0,0,"onActivate()");
	$this->Update();

	# The list control's onSize() method invalidates
	# the entire screen (sets the update rec to the
	# whole client area)
	
	$this->{list_ctrl}->onSize() if $this->{list_ctrl};
}


1;
