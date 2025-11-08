#!/usr/bin/perl
#-------------------------------------------------------------------------
# winProg.pm
#-------------------------------------------------------------------------
# The Program Control window allows for
#
# - assignment of virtual instruments to zero or more of the protocols
# - possibly general control of the monitoring and binary output from teensyBoat
#
# Initial implementation
#
#	Three protocol columns of instrument checkboxes
#   with all_on and all_off buttons at the top.

package winProg;
use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_CHECKBOX
	EVT_BUTTON
	EVT_TEXT_ENTER
	EVT_SET_FOCUS
	EVT_KILL_FOCUS );
use Pub::Utils;
use Pub::WX::Window;
use tbUtils;
use tbBinary;
use tbConsole;
use base qw(Wx::Panel Pub::WX::Window);


my $dbg_win = 0;


my $TOP_MARGIN = 50;
my $LINE_HEIGHT = 25;

my $LEFT_COL = 20;
my $COL_WIDTH = 80;

my $NUM_PORT_BUTTONS = 2;
	# number of extra buttons per port
my $INST_NUM_ALL_ON  = $NUM_INSTRUMENTS;
my $INST_NUM_ALL_OFF = $NUM_INSTRUMENTS+1;
my $PORT_MON_ON 	 = $NUM_INSTRUMENTS+2;
my $NUM_PORT_CTRLS 	 = $NUM_INSTRUMENTS + $NUM_PORT_BUTTONS + 1;


my @BUTTON_NAMES = ( 'all_on', 'all_off' );

my $ID_LOAD_DEFAULTS = 900;
my $ID_SAVE_DEFAULTS = 901;
my $ID_FWD_A_B		 = 902;
my $ID_FWD_B_A		 = 903;


my $ID_CTRL_BASE = 1000;	# uses $NUM_CTRLS identifiers


my $font_fixed = Wx::Font->new(12,wxFONTFAMILY_MODERN,wxFONTSTYLE_NORMAL,wxFONTWEIGHT_BOLD);


sub idOf
{
	my ($port_num, $inst_num) = @_;
	return $port_num * $NUM_PORT_CTRLS + $inst_num;
}

sub portOf
{
	my ($id) = @_;
	return int($id / $NUM_PORT_CTRLS);
}

sub instrumentOf
{
	my ($id) = @_;
	return $id % $NUM_PORT_CTRLS;
}





sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display($dbg_win,0,"winProg::new() called");
	$this->MyWindow($frame,$book,$id,"Prog",$data);

	# default buttons

	Wx::Button->new($this,$ID_LOAD_DEFAULTS,"LOAD",[20,20], [60,20]);
	Wx::Button->new($this,$ID_SAVE_DEFAULTS,"SAVE",[100,20],[60,20]);

	my $fwd_x = $LEFT_COL + 2 * $COL_WIDTH + 20;
	my $a_b = Wx::CheckBox->new($this,$ID_FWD_A_B,"A->B",[$fwd_x,20]);
	$fwd_x += $COL_WIDTH;
	my $b_a = Wx::CheckBox->new($this,$ID_FWD_B_A,"A<-B",[$fwd_x,20]);
	EVT_CHECKBOX($this, $ID_FWD_A_B, \&onForwardChanged);
	EVT_CHECKBOX($this, $ID_FWD_B_A, \&onForwardChanged);

	# column headers

	for (my $i=0; $i<$NUM_BOAT_PORTS; $i++)
	{
		my $name = portName($i);
		my $x = $LEFT_COL + (1 + $i) * $COL_WIDTH;
		Wx::StaticText->new($this,-1,$name,[$x,$TOP_MARGIN],[$COL_WIDTH,$LINE_HEIGHT],
			wxALIGN_CENTRE_HORIZONTAL);
	}

	# instrument names

	for (my $i=0; $i<$NUM_INSTRUMENTS; $i++)
	{
		my $name = instrumentName($i);
		my $y = $TOP_MARGIN + (1 + $i) * $LINE_HEIGHT;
		Wx::StaticText->new($this,-1,$name,[$LEFT_COL,$y]);
	}

	# "MONITOR" row label

	Wx::StaticText->new($this,-1,'MONITOR',[$LEFT_COL,
		$TOP_MARGIN + (1 + $NUM_INSTRUMENTS + $NUM_PORT_BUTTONS) * $LINE_HEIGHT]);

	# checkboxes

	for (my $i=0; $i<$NUM_BOAT_PORTS; $i++)
	{
		for (my $j=0; $j<$NUM_INSTRUMENTS; $j++)
		{
			my $id = idOf($i,$j);
			my $x = $LEFT_COL + (1 + $i) * $COL_WIDTH + ($COL_WIDTH/2 - 10);
			my $y = $TOP_MARGIN + (1 + $j) * $LINE_HEIGHT;
			my $box = Wx::CheckBox->new($this,$id,"  ",[$x,$y]);
			EVT_CHECKBOX($this,$id,\&onCheckBox);
		}
	}

	# extra controls
	# done in this order for tab order

	$this->{mon_values} = [];

	for (my $j=0; $j<$NUM_PORT_BUTTONS+1; $j++)
	{
		for (my $i=0; $i<$NUM_BOAT_PORTS; $i++)
		{
			my $pseudo_inst_num = $j + $NUM_INSTRUMENTS;
			my $name = $BUTTON_NAMES[$j];

			my $id = idOf($i,$pseudo_inst_num);
			my $x = $LEFT_COL + (1 + $i) * $COL_WIDTH + 10;
			my $y = $TOP_MARGIN + (1 + $pseudo_inst_num) * $LINE_HEIGHT;
			if ($j < $NUM_PORT_BUTTONS)
			{
				my $button = Wx::Button->new($this,$id,$name,[$x,$y],[60,20]);
			}
			else
			{
				my $mon_ctrl = Wx::TextCtrl->new($this, $id, '0x00', [$x+12, $y], [36, 20], wxTE_PROCESS_ENTER);
				EVT_KILL_FOCUS($mon_ctrl, \&onMonChanged);
				EVT_TEXT_ENTER($mon_ctrl,$id, \&onMonChanged);
				$this->{mon_values}->[$i] = '0x00';
			}
		}
	}

	EVT_BUTTON($this,-1,\&onButton);

	sendTeensyCommand("STATE");

	return $this;
}



sub onButton
{
	my ($this,$event) = @_;
	my $id = $event->GetId();
	my $command;

	if ($id == 	$ID_LOAD_DEFAULTS)
	{
		display($dbg_win,0,"onButton(LOAD)");
		$command = "LOAD";
	}
	elsif ($id == 	$ID_SAVE_DEFAULTS)
	{
		display($dbg_win,0,"onButton(SAVE)");
		$command = "SAVE";
	}
	else
	{
		my $port_num = portOf($id);
		my $port_name = portName($id);
		my $inst_num = instrumentOf($id);
		my $button_num = $inst_num - $NUM_INSTRUMENTS;
		my $value = $button_num ? 0 : 1;

		display($dbg_win,0,"onButton $port_name($port_num) @BUTTON_NAMES($button_num)");

		# turn all the checkboxes on or off

		for (my $i=0; $i<$NUM_INSTRUMENTS; $i++)
		{
			my $box_id = idOf($port_num,$i);
			my $box = $this->FindWindow($box_id);
			$box->SetValue($value);
		}

		# send the command

		my $port_id = portId($port_num);
		$value += $NO_ECHO_TO_PERL;	# don't echo
		$command = "I_$port_id=$value";
	}
	
	sendTeensyCommand($command);
}



sub onCheckBox
{
	my ($this,$event) = @_;
	my $id = $event->GetId();
	my $checked = $event->IsChecked() || 0;

	my $port_num = portOf($id);
	my $port_id = portId($port_num);
	my $port_name = portName($port_num);
	my $inst_num = instrumentOf($id);
	my $inst_name = instrumentName($inst_num);
	display($dbg_win,0,"onCheckBox($id) $port_name($port_num)=$port_id $inst_name($inst_num) checked=$checked");

	# the "i_{inst_name}=XX" command currntly expects a portwise binary XX
	# we build the binary number here.

	my $port_mask = 0;
	for (my $i=0; $i<$NUM_BOAT_PORTS; $i++)
	{
		my $box_id = idOf($i,$inst_num);
		my $box = $this->FindWindow($box_id);
		$port_mask |= (1 << $i) if $box->GetValue();
	}

	$port_mask += $NO_ECHO_TO_PERL;	# don't echo
	my $command = "I_$inst_name=$port_mask";
	sendTeensyCommand($command);
}



sub onMonChanged
{
	my ($ctrl,$event) = @_;
	my $id = $event->GetId();
	my $value = $ctrl->GetValue() || 0;
	my $this = $ctrl->GetParent();

	my $port_num = portOf($id);
	my $port_id = portId($port_num);

	display($dbg_win,0,"onMonChanged($id) $port_id($port_num) cur=$this->{mon_values}->[$port_num]  value=$value");

	if ($this->{mon_values}->[$port_num] ne $value)
	{
		my $actual_value = $value =~ /^0x/ ? hex($value) : $value;
		my $hex_value = sprintf("0x%02x",$value);
		$this->{mon_values}->[$port_num] = $hex_value;
		$ctrl->SetValue($hex_value) if $hex_value ne $value;
		my $command = "M_$port_id=$actual_value";
		sendTeensyCommand($command);
	}
	$event->Skip();
}


sub onForwardChanged
{
    my ($this, $event) = @_;
    my $id = $event->GetId();

    my $a_b = $this->FindWindow($ID_FWD_A_B);
    my $b_a = $this->FindWindow($ID_FWD_B_A);

    if ($id == $ID_FWD_A_B && $a_b->GetValue)
	{
        $b_a->SetValue(0);
        sendTeensyCommand("FWD=1");
    }
    elsif ($id == $ID_FWD_B_A && $b_a->GetValue)
	{
        $a_b->SetValue(0);
        sendTeensyCommand("FWD=2");
    }
    elsif (!$a_b->GetValue && !$b_a->GetValue)
	{
        sendTeensyCommand("FWD=0");
    }
}



sub handleBinaryData
{
	my ($this,$counter,$type,$packet) = @_;
	# display(0,0,"handleBinaryData($counter) len=".length($binary_data));
	display_bytes($dbg_win+1,0,"packet",$packet);

	my $offset = 0;
	for (my $i=0; $i<$NUM_INSTRUMENTS; $i++)
	{
		my $mask = binaryByte($packet,\$offset);
		for (my $j=0; $j<$NUM_BOAT_PORTS; $j++)
		{
			my $box_id = idOf($j,$i);
			my $box = $this->FindWindow($box_id);
			my $value = $mask & (1 << $j) ? 1 : 0;
			$box->SetValue($value);
		}
	}
	for (my $i=0; $i<$NUM_BOAT_PORTS; $i++)
	{
		my $value = binaryByte($packet,\$offset);
		my $text_id = idOf($i,$PORT_MON_ON);
		my $text_ctrl = $this->FindWindow($text_id);
		my $hex_value = sprintf("0x%02x",$value);
		$text_ctrl->SetValue($hex_value);
		$this->{mon_values}->[$i] = $hex_value;
	}
	my $fwd = binaryByte($packet,\$offset);
    my $a_b = $this->FindWindow($ID_FWD_A_B);
    my $b_a = $this->FindWindow($ID_FWD_B_A);
	$a_b->SetValue($fwd & 1);
	$b_a->SetValue($fwd & 2);
}



1;
