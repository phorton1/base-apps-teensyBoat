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
	EVT_CLOSE
	EVT_CHECKBOX
	EVT_BUTTON
	EVT_TEXT_ENTER
	EVT_SET_FOCUS
	EVT_COMBOBOX
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

my $ID_FWDST_1_2		 = 902;
my $ID_FWDST_2_1		 = 903;
my $ID_FWD83_A_B		 = 904;
my $ID_FWD83_B_A		 = 905;

my $ID_E80_FILTER		 = 950;
my $ID_GP8_MODE			 = 960;

my $ID_CTRL_BASE = 1000;	# uses $NUM_CTRLS identifiers

my @gp8_labels = ('OFF','PULSE','ESP32','NEOST','NEO2000');

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

	Wx::Button->new($this,$ID_LOAD_DEFAULTS,"LOAD",[10,10],[60,20]);
	Wx::Button->new($this,$ID_SAVE_DEFAULTS,"SAVE",[10,35],[60,20]);

	$this->{fwd} = 0;
	$this->{e80filter} = 0;
	$this->{gp8_mode} = 0;

	Wx::StaticText->new($this,-1,"GP8 Mode:",[360,5]);
	$this->{gp8_combo} = Wx::ComboBox->new($this,$ID_GP8_MODE,'OFF',[425,2],[80,20],\@gp8_labels,wxCB_READONLY);
	EVT_COMBOBOX($this,$ID_GP8_MODE,\&onGP8ModeCombo);

	my $fwd_x = $LEFT_COL + $COL_WIDTH + 20;
	my $st1_2 = Wx::CheckBox->new($this,$ID_FWDST_1_2,"1->2",[$fwd_x,30]);
	$fwd_x += $COL_WIDTH;
	my $st2_1 = Wx::CheckBox->new($this,$ID_FWDST_2_1,"1<-2",[$fwd_x,30]);
	$fwd_x += $COL_WIDTH;
	my $a_b = Wx::CheckBox->new($this,$ID_FWD83_A_B,"A->B",[$fwd_x,30]);
	my $e80_ctrl = Wx::CheckBox->new($this,	$ID_E80_FILTER,"E80 Filter",[$fwd_x,5]);
	$fwd_x += $COL_WIDTH;
	my $b_a = Wx::CheckBox->new($this,$ID_FWD83_B_A,"A<-B",[$fwd_x,30]);
	EVT_CHECKBOX($this, $ID_FWDST_1_2, \&onForwardChanged);
	EVT_CHECKBOX($this, $ID_FWDST_2_1, \&onForwardChanged);
	EVT_CHECKBOX($this, $ID_FWD83_A_B, \&onForwardChanged);
	EVT_CHECKBOX($this, $ID_FWD83_B_A, \&onForwardChanged);
	EVT_CHECKBOX($this, $ID_E80_FILTER, \&onE80FilterChanged);

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
				$this->{mon_values}->[$i] = 0;
			}
		}
	}

	EVT_BUTTON($this,-1,\&onButton);
	EVT_CLOSE($this,\&onClose);

	$this->initTBCommands();

	return $this;
}



sub initTBCommands
	# called from ctor and when com port opened
{
	my ($this) = @_;
	sendTeensyCommand("B_PROG=1");
	sendTeensyCommand("STATE");
}


sub onClose
	# turn off binary binary SIM data
{
    my ($this,$event) = @_;
	sendTeensyCommand("B_PROG=0");
	$this->SUPER::onClose($event);
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
		my $port_name = portName($port_num);
		my $inst_num = instrumentOf($id);
		my $button_num = $inst_num - $NUM_INSTRUMENTS;
		my $value = $button_num ? 0 : 1;

		display($dbg_win,0,"onButton $port_name($port_num) $BUTTON_NAMES[$button_num] value=$value");

		# turn all the checkboxes on or off

		for (my $i=0; $i<$NUM_INSTRUMENTS; $i++)
		{
			my $box_id = idOf($port_num,$i);
			my $box = $this->FindWindow($box_id);
			$box->SetValue($value);
		}

		# send the command

		my $port_id = portId($port_num);
		$command = "I_$port_id=$value";
	}
	
	sendTeensyCommand($command);
}

sub onGP8ModeCombo
{
	my ($this,$event) = @_;
	my $value = $this->{gp8_combo}->GetValue();
	display(0,0,"onFileDeviceCombo($value)");
	sendTeensyCommand("GP8_MODE=$value");
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

	my $command = "I_$inst_name=$port_mask";
	sendTeensyCommand($command);
}



sub onMonChanged
{
	my ($ctrl,$event) = @_;
	my $id = $event->GetId();
	my $str_value = $ctrl->GetValue() || 0;
	my $this = $ctrl->GetParent();
	my $port_num = portOf($id);
	my $port_id = portId($port_num);

	my $value = $str_value =~ /^0x/ ? hex($str_value) : $str_value;
	my $hex_value = sprintf("0x%02x",$value);

	display($dbg_win,0,"onMonChanged($id) $port_id($port_num) cur=$this->{mon_values}->[$port_num]  str_value($str_value)=$value='$hex_value'");

	$ctrl->SetValue($hex_value) if $str_value ne $hex_value;

	if ($this->{mon_values}->[$port_num] != $value)
	{
		$this->{mon_values}->[$port_num] = $value;
		my $command = "M_$port_id=$value";
		sendTeensyCommand($command);
	}
	$event->Skip();
}


sub onForwardChanged
{
    my ($this, $event) = @_;
    my $id = $event->GetId();
	my $ctrl = $event->GetEventObject();
	my $value = $ctrl->GetValue() || 0;
	my $rel_id = $id - $ID_FWDST_1_2;
	my $mask = 1 << $rel_id;
	my $fwd = $this->{fwd};

	display($dbg_win,0,"onForwardChanged($id)  rel_id($rel_id) mask($mask) value($value) cur fwd($fwd)");

	if ($value)
	{
		$fwd |= $mask;
	}
	else
	{
		$fwd &= ~$mask;
		display($dbg_win,1,"turned off mask new fwd($fwd)");
	}

	$this->{fwd} = $fwd;
	sendTeensyCommand("FWD=$fwd");
}

sub onE80FilterChanged
{
    my ($this, $event) = @_;
	my $ctrl = $event->GetEventObject();
	my $value = $ctrl->GetValue() || 0;
	display($dbg_win,0,"onE80FilterChanged$value)");
	$this->{e80filter} = $value;
	sendTeensyCommand("E80_FILTER=$value");
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
		$this->{mon_values}->[$i] = $value;
	}
	my $fwd = $this->{fwd} = binaryByte($packet,\$offset);
	my $e80filter = $this->{e80filter} = binaryByte($packet,\$offset);
	my $gp8_mode = $this->{gp8_mode} = binaryByte($packet,\$offset);
	my $gp8_selected = $gp8_labels[$this->{gp8_mode}];
	$this->FindWindow($ID_FWDST_1_2)->SetValue($fwd & 1);
	$this->FindWindow($ID_FWDST_2_1)->SetValue($fwd & 2);
	$this->FindWindow($ID_FWD83_A_B)->SetValue($fwd & 4);
	$this->FindWindow($ID_FWD83_B_A)->SetValue($fwd & 8);
	$this->FindWindow($ID_E80_FILTER)->SetValue($e80filter);
	warning(0,0,"ui got gp8_mode($gp8_mode)=$gp8_selected");
	$this->FindWindow($ID_GP8_MODE)->SetValue($gp8_selected);
}



1;
