#!/usr/bin/perl
#-------------------------------------------------------------------------
# winST.pm
#-------------------------------------------------------------------------


package apps::teensyBoat::winST;
use strict;
use warnings;
use Time::HiRes qw(time);
use Wx qw(:everything);
use Wx::Event qw(
	EVT_PAINT
	EVT_IDLE
	EVT_SIZE );
use Pub::Utils;
use Pub::WX::Window;
use apps::teensyBoat::tbUtils;
use apps::teensyBoat::tbBinary;
use base qw(Wx::ScrolledWindow MyWX::Window);

my $CHANGE_TIMEOUT = 2;
my $TOP_MARGIN = 50;
my $LINE_HEIGHT = 20;


my $slots = {};
# my $ctrls = [];


my $redraw_all = 0;

my $frame_counter_ctrl;
my $st_counter_ctrl;
my $st_counter = 0;

my $font_fixed = Wx::Font->new(12,wxFONTFAMILY_MODERN,wxFONTSTYLE_NORMAL,wxFONTWEIGHT_BOLD);


sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display(0,0,"winST::new() called");
	$this->MyWindow($frame,$book,$id,"Seatalk");

	$frame_counter_ctrl = Wx::StaticText->new($this,-1,"",[10,10]);
	$st_counter_ctrl = Wx::StaticText->new($this,-1,"",[50,10]);

	EVT_IDLE($this, \&onIdle);
	EVT_SIZE($this, \&onSize);

	$this->SetVirtualSize([2500,$TOP_MARGIN]);
	$this->SetScrollRate(20,$LINE_HEIGHT);

	return $this;
}

sub onSize
{
	my ($this,$event) = @_;
	$redraw_all = 1;
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

	# my $offset = $SHOW_OFFSET;

	# my $data = substr($packet,$offset);

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

		my $num_sts = @sts;
		$this->SetVirtualSize([2500,$TOP_MARGIN + $num_sts * $LINE_HEIGHT]);
	}

	$this->doPaint($found);
}


my $CHAR_WIDTH;


sub drawChanges
{
	my ($dc,$x,$y,$new,$old) = @_;
	my $old_len = length($old);
	for (my $i=0; $i<length($new); $i++)
	{
		my $n = substr($new,$i,1);
		my $o = $i < $old_len ? substr($old,$i,1) : '';
		my $color = $n eq $o ? wxBLACK : wxRED;
		$dc->SetTextForeground($color);
		$dc->DrawText($n,$x + $i * $CHAR_WIDTH,$y);
	}
}


my $last_x = 0;
my $last_y = 0;

sub doPaint
{
	my ($this, $found) = @_;

	my ($start_x, $start_y) = $this->CalcUnscrolledPosition(0,0);
	if ($last_x != $start_x || $last_y != $start_y)
	{
		$last_x = $start_x;
		$last_y = $start_y;
		$redraw_all = 1;
	}


	my $dc = Wx::ClientDC->new($this);
	$dc->SetPen(wxLIGHT_GREY_PEN);
	$dc->SetBrush(wxWHITE_BRUSH);
	$dc->SetFont($font_fixed);
	$dc->SetTextBackground(wxWHITE);
	$dc->SetBackgroundMode(wxSOLID);
	$CHAR_WIDTH = $dc->GetCharWidth();

	my @sts = sort keys %$slots;
	for my $st (@sts)
	{
		my $slot = $slots->{$st};
		my $changed = $slot->{changed};
		if ($redraw_all || !$found || $changed == 3 || $changed == 1)
		{
			my $num = $slot->{num};
			my $count = pad($slot->{count},6);
			my $name = $slot->{name};
			my $hex = $slot->{hex};
			my $data = $slot->{data};
			my $old_hex = $slot->{old_hex} || '';
			my $old_data = $slot->{old_data} || '';

			my $x = 5 - $start_x;
			my $y = $TOP_MARGIN + $num * $LINE_HEIGHT - $start_y;

			# $dc->DrawRectangle(5,$y-2,2500,$LINE_HEIGHT+3);

			$dc->SetTextForeground(wxBLACK);
			$dc->DrawText($count,$x,$y);
			$x += 6 * $CHAR_WIDTH;

			$dc->DrawText($slot->{dir},$x,$y);
			$x += 4 * $CHAR_WIDTH;

			$dc->DrawText($name,$x,$y);
			$x += (length($name) + 1) * $CHAR_WIDTH;

			if ($changed == 1 || ($redraw_all && !$slot->{changed}))
			{
				$dc->DrawText($hex,$x,$y);
				$x += (length($hex) + 1) * $CHAR_WIDTH;
				$dc->DrawText($data,$x,$y);
				$slot->{changed} = 0;
			}
			elsif ($changed == 3 || $redraw_all)
			{
				drawChanges($dc,$x,$y,$hex,$old_hex);
				$x += (length($hex) + 1) * $CHAR_WIDTH;
				drawChanges($dc,$x,$y,$data,$old_data);
				$slot->{changed} = 2;
			}
		} 
	}

	$redraw_all = 0;

}	# onPaint()





sub onIdle
{
	my ($this,$event) = @_;
	my $any = 0;
	my $now = time();
	for my $st (keys %$slots)
	{
		my $slot = $slots->{$st};
		if ($slot->{changed}==2 && $now-$slot->{time} >= $CHANGE_TIMEOUT)
		{
			$slot->{changed} = 1;
			$slot->{old_msg} = $slot->{msg};
			$any = 1;
		}
	}
	# $this->Refresh() if $any;

	$event->RequestMore();
}


1;
