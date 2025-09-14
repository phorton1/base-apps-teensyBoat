#!/usr/bin/perl
#-------------------------------------------------------------------------
# winBoat.pm
#-------------------------------------------------------------------------
# The main TB window, can't be closed


package apps::teensyBoat::winBoat;
use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_CLOSE );
use Pub::Utils;
use Pub::WX::Window;
use apps::teensyBoat::tbUtils;
use apps::teensyBoat::tbBinary;
use base qw(Wx::Window MyWX::Window);

my $counter_ctrl;

my $SHOW_DEGREE_MINUTES = 1;

my $LABEL_COL = 10;
my $DATA_COL  = 110;
my $DATA_ROW  = 40;
my $ROW_HEIGHT  = 20;
my $COL_WIDTH = 190;


my $boat_data = [
	# in packing order

	{ row=>0,	col=>0,		name=>'running',			type=>'Byte' },
	{ row=>1,	col=>0,		name=>'autopilot',			type=>'Byte' },
	{ row=>2,	col=>0,		name=>'routing',			type=>'Byte' },
	{ row=>9,	col=>0,		name=>'arrived',			type=>'Byte' },
	{ row=>4,	col=>0,		name=>'start_wp',   		type=>'Byte',		},
	{ row=>5,	col=>0,		name=>'name',				type=>'FixStr',		fxn_param=>8 },		# fixed length 8
	{ row=>6,	col=>0,		name=>'target_wp',   		type=>'Byte',		},
	{ row=>7,	col=>0,		name=>'name',				type=>'FixStr',		fxn_param=>8 },		# fixed length 8
	{ row=>3,	col=>1,		name=>'depth',				type=>'Float',		prec=>1,	},
	{ row=>4,	col=>1,		name=>'sog',		 		type=>'Float',		prec=>1,	},
	{ row=>5,	col=>1,		name=>'cog',				type=>'Float',		prec=>1,	},
	{ row=>6,	col=>1,		name=>'wind_angle',       	type=>'Float',		prec=>1,	},
	{ row=>7,	col=>1,		name=>'wind_speed',       	type=>'Float',		prec=>1,	},
	{ row=>0,	col=>1,		name=>'latitude',         	type=>'Double',		latlon=>1,	},
	{ row=>1,	col=>1,		name=>'longitude',        	type=>'Double',		latlon=>1,	},
	{ row=>9,	col=>1,		name=>'app_wind_angle',   	type=>'Float',		prec=>1,	},
	{ row=>10,	col=>1,		name=>'app_wind_speed',   	type=>'Float',		prec=>1,	},
	{ row=>0,	col=>2,		name=>'rpm',              	type=>'Uint16',		prec=>0,	},
	{ row=>1,	col=>2,		name=>'oil_pressure',     	type=>'Uint16',		prec=>0,	},
	{ row=>2,	col=>2,		name=>'oil_temp',         	type=>'Uint16',		prec=>0,	},
	{ row=>3,	col=>2,		name=>'coolant_temp',     	type=>'Uint16',		prec=>0,	},
	{ row=>4,	col=>2,		name=>'alt_voltage',      	type=>'Float',		prec=>1,	},
	{ row=>6,	col=>2,		name=>'fuel_rate',        	type=>'Float',		prec=>1,	},
	{ row=>7,	col=>2,		name=>'fuel_level1',      	type=>'Float',		prec=>1,	},
	{ row=>8,	col=>2,		name=>'fuel_level2',      	type=>'Float',		prec=>1,	},
	{ row=>0,	col=>3,		name=>'genset',           	type=>'Byte',		},
	{ row=>1,	col=>3,		name=>'gen_rpm',          	type=>'Uint16',		prec=>0,	},
	{ row=>2,	col=>3,		name=>'gen_oil_pressure', 	type=>'Uint16',		prec=>0,	},
	{ row=>3,	col=>3,		name=>'gen_cool_temp',    	type=>'Uint16',		prec=>0,	},
	{ row=>4,	col=>3,		name=>'gen_voltage',      	type=>'Float',		prec=>1,	},
	{ row=>5,	col=>3,		name=>'gen_freq',         	type=>'Byte',		prec=>0,	},
	{ row=>-1.5,col=>1,		name=>'update_num',       	type=>'Uint32',		},
	{ row=>8,	col=>0,		name=>'closest',		    type=>'Uint16',		},

	{ row=>10,	col=>0,		name=>'head_to_wp',   		type=>'Float',		prec=>1,	},
	{ row=>11,	col=>0,		name=>'dist_to_wp',   		type=>'Float',		prec=>2,	},
	{ row=>10,  col=>2,		name=>'date',				type=>'FixStr',		fxn_param=>20 },

];



sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display(0,0,"winBoat::new() called");
	$this->MyWindow($frame,$book,$id,"Boat");

	$counter_ctrl = Wx::StaticText->new($this,-1,"",[10,10]);

	for my $data (@$boat_data)
	{
		my $y = $DATA_ROW + $data->{row} * $ROW_HEIGHT;
		my $label_x = $LABEL_COL + $data->{col} * $COL_WIDTH;
		my $data_x = $DATA_COL + $data->{col} * $COL_WIDTH;

		Wx::StaticText->new($this,-1,$data->{name},[$label_x,$y]);
		$data->{ctrl} = Wx::StaticText->new($this,-1,"",[$data_x,$y]);
		$data->{last_value} = '';
	}

    # $this->{browser} = MyMS::IE->new($this, -1, [10,60],[300,300]);
    # $this->{browser}->LoadString("<b>THIS IS A TEST $xyz_junk</b>");

	# EVT_CLOSE($this,\&onClose);
    #
	# my $style = $this->GetWindowStyle();
	# $this->SetWindowStyle($style & (~wxCLOSE_BOX));
	# $this->Refresh();

	return $this;
}


# sub closeOK
# {
# 	my ($this,$more_dirty) = @_;
# 	return 0;
# }

#
# sub onClose
# 		# only hooked up if !$USE_LOW_THREAD
# {
#     my ($this,$event) = @_;
# 	$event->Veto();
# }


sub handleBinaryData
{
	my ($this,$counter,$type,$packet) = @_;
	# display(0,0,"handleBinaryData($counter) len=".length($binary_data));
	# display_bytes(0,0,"packet",$packet);

	my $show_data = unpack("H*",$packet);
	$counter_ctrl->SetLabel("packet($counter)");

	my $offset = 0;

	for my $data (@$boat_data)
	{
		my $name = $data->{name};
		
		my $fxn_name = "binary$data->{type}";
		my $fxn = \&{$fxn_name};
		# my $dbg_offset = $offset;
		my $value = $fxn->($packet,\$offset,$data->{fxn_param});
		# display(0,1,pad($name,20)." offset($dbg_offset) fxn=$fxn_name value=$value");
		
		if ($data->{latlon})
		{
			$value = $SHOW_DEGREE_MINUTES ?
				degreeMinutes($value) :
				round($value,6);
		}
		elsif (defined($data->{prec}))
		{
			$value = round($value,$data->{prec})
		}

		if ($data->{last_value} eq $value)
		{
			if ($data->{changed})
			{
				$data->{changed} = 0;
				$data->{ctrl}->SetForegroundColour(wxBLACK);
				$data->{ctrl}->SetLabel($value);
			}
		}
		else
		{
			$data->{changed} = 1;
			$data->{ctrl}->SetForegroundColour(wxRED);
			$data->{ctrl}->SetLabel($value);
			$data->{last_value} = $value;
		}
	}


}



1;
