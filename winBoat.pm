#!/usr/bin/perl
#-------------------------------------------------------------------------
# winBoat.pm
#-------------------------------------------------------------------------
# The Boat (simulator) window.
# Shows and allows modifications to the state of the boat simulator.


package winBoat;
use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_CLOSE );
use Pub::Utils;
use Pub::WX::Window;
use tbUtils;
use tbBinary;
use tbServer;
use base qw(Pub::WX::Window);

my $dbg_win = 0;


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
	{ row=>3,	col=>0,		name=>'arrived',			type=>'Byte' },
	{ row=>4,	col=>0,		name=>'route_name',			type=>'FixStr',		fxn_param=>16 },	# fixed length 16

	{ row=>6,	col=>0,		name=>'trip_on',			type=>'Byte' },
	{ row=>7,	col=>0,		name=>'trip_dist',			type=>'Float', 		prec=>2},
	{ row=>8,	col=>0,		name=>'log_total',			type=>'Float', 		prec=>1},

	{ row=>10,	col=>0,		name=>'start_wp',   		type=>'Byte',		},
	{ row=>11,	col=>0,		name=>'start_name',			type=>'FixStr',		fxn_param=>8 },		# fixed length 8
	{ row=>12,	col=>0,		name=>'target_wp',   		type=>'Byte',		},
	{ row=>13,	col=>0,		name=>'target_name',		type=>'FixStr',		fxn_param=>8 },		# fixed length 8
	{ row=>14,	col=>0,		name=>'head_to_wp',   		type=>'Float',		prec=>1,	},
	{ row=>15,	col=>0,		name=>'dist_to_wp',   		type=>'Float',		prec=>4,	},

	{ row=>17,	col=>0,		name=>'desired_heading',	type=>'Float',		prec=>1,	},

	{ row=>0,	col=>1,		name=>'depth',				type=>'Float',		prec=>1,	},
	{ row=>1,	col=>1,		name=>'heading',		 	type=>'Float',		prec=>1,	},
	{ row=>2,	col=>1,		name=>'water_speed',		type=>'Float',		prec=>1,	},
	{ row=>3,	col=>1,		name=>'current_set',		type=>'Float',		prec=>1,	},
	{ row=>4,	col=>1,		name=>'current_drift',		type=>'Float',		prec=>1,	},
	{ row=>5,	col=>1,		name=>'wind_angle',       	type=>'Float',		prec=>1,	},
	{ row=>6,	col=>1,		name=>'wind_speed',       	type=>'Float',		prec=>1,	},
	{ row=>7,	col=>1,		name=>'latitude',         	type=>'Double',		latlon=>1,	},
	{ row=>8,	col=>1,		name=>'longitude',        	type=>'Double',		latlon=>1,	},

	{ row=>10,	col=>1,		name=>'sog',		 		type=>'Float',		prec=>1,	},
	{ row=>11,	col=>1,		name=>'cog',				type=>'Float',		prec=>1,	},
	{ row=>12,	col=>1,		name=>'app_wind_angle',   	type=>'Float',		prec=>1,	},
	{ row=>13,	col=>1,		name=>'app_wind_speed',   	type=>'Float',		prec=>1,	},
	{ row=>14,	col=>1,		name=>'estimated_set',   	type=>'Float',		prec=>4,	},
	{ row=>15,	col=>1,		name=>'estimated_drift',   	type=>'Float',		prec=>4,	},
	{ row=>16,	col=>1,		name=>'cross_track_error',  type=>'Float',		prec=>4,	},
	{ row=>17,	col=>1,		name=>'closest',		    type=>'Uint16',		},

	{ row=>0,	col=>2,		name=>'rpm',              	type=>'Uint16',		prec=>0,	},
	{ row=>1,	col=>2,		name=>'boost_pressure',     type=>'Float',		prec=>1,	},
	{ row=>2,	col=>2,		name=>'oil_pressure',     	type=>'Float',		prec=>1,	},
	{ row=>3,	col=>2,		name=>'oil_temp',         	type=>'Float',		prec=>1,	},
	{ row=>4,	col=>2,		name=>'coolant_temp',     	type=>'Float',		prec=>1,	},
	{ row=>5,	col=>2,		name=>'alt_voltage',      	type=>'Float',		prec=>1,	},
	{ row=>6,	col=>2,		name=>'fuel_rate',        	type=>'Float',		prec=>1,	},
	{ row=>7,	col=>2,		name=>'fuel_level1',      	type=>'Float',		prec=>2,	},
	{ row=>8,	col=>2,		name=>'fuel_level2',      	type=>'Float',		prec=>2,	},

	{ row=>10,	col=>2,		name=>'genset',           	type=>'Byte',		},
	{ row=>11,	col=>2,		name=>'gen_rpm',          	type=>'Float',		prec=>0,	},
	{ row=>12,	col=>2,		name=>'gen_oil_pressure', 	type=>'Float',		prec=>1,	},
	{ row=>13,	col=>2,		name=>'gen_cool_temp',    	type=>'Float',		prec=>1,	},
	{ row=>14,	col=>2,		name=>'gen_voltage',      	type=>'Float',		prec=>1,	},
	{ row=>15,	col=>2,		name=>'gen_freq',         	type=>'Byte',		prec=>0,	},

	{ row=>-1.5,col=>1,		name=>'update_num',       	type=>'Uint32',		},

	{ row=>-1.5,  col=>2,	name=>'date',				type=>'FixStr',		fxn_param=>20 },

];

my $boat_fields = {};
for my $rec (@$boat_data)
{
	$boat_fields->{$rec->{name}} = $rec;
}



sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display($dbg_win,0,"winBoat::new() called");
	$this->MyWindow($frame,$book,$id,"Boat",$data);

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
	# display($dbg_win,0,"handleBinaryData($counter) len=".length($binary_data));
	# display_bytes($dbg_win+1,0,"packet",$packet);

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
		# display($dbg_win+1,1,pad($name,20)." offset($dbg_offset) fxn=$fxn_name value=$value");
		
		$data->{raw_value} = $value;

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

	updateTBServer({
		'heading' => $boat_fields->{cog}->{raw_value},
		'latitude' => $boat_fields->{latitude}->{raw_value},
		'longitude' => $boat_fields->{longitude}->{raw_value},
	}) if $WITH_TB_SERVER;

}



1;
