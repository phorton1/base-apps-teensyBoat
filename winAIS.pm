#!/usr/bin/perl
#-------------------------------------------------------------------------
# winAIS.pm
#-------------------------------------------------------------------------
# The virtual AIS targets window.
#
# Behaves like a real AIS plotter: it holds a table of contacts keyed by
# MMSI and updates them as (aggregated) BINARY_TYPE_AIS packets arrive.
# Each packet only carries whichever vboat(s) actually transmitted that
# burst, so contacts accumulate over time and are aged out when they have
# not been heard from for $CONTACT_TIMEOUT seconds (a vboat that cycled
# out of range).  A vboat on a COLLIDE course is shown in red.


package winAIS;
use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_CLOSE
	EVT_SIZE );
use Time::HiRes qw(time);
use Pub::Utils;
use Pub::WX::Window;
use tbUtils;
use tbBinary;
use tbConsole;
use base qw(Pub::WX::Window);

my $dbg_win = 0;

my $CONTACT_TIMEOUT = 120;		# seconds since last heard before a contact drops
my $SHOW_DEGREE_MINUTES = 1;

my @columns = (
	{ name=>'MMSI',		width=>80  },
	{ name=>'Name',		width=>150 },
	{ name=>'Type',		width=>45  },
	{ name=>'Lat',		width=>95  },
	{ name=>'Lon',		width=>95  },
	{ name=>'COG',		width=>50  },
	{ name=>'SOG',		width=>50  },
	{ name=>'Rng(NM)',	width=>65  },
	{ name=>'Brg',		width=>50  },
	{ name=>'Msg',		width=>50  },
	{ name=>'Age',		width=>50  },
);

my @msg_names = ('', 'POS', 'NAME', 'STAT');	# indexed by AIS_MSG_* value


sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display($dbg_win,0,"winAIS::new() called");
	$this->MyWindow($frame,$book,$id,"AIS",$data);

	my $list = Wx::ListCtrl->new($this,-1,[0,0],[-1,-1],
		wxLC_REPORT | wxLC_SINGLE_SEL);

	my $col = 0;
	for my $c (@columns)
	{
		$list->InsertColumn($col,$c->{name});
		$list->SetColumnWidth($col,$c->{width});
		$col++;
	}

	$this->{list} = $list;
	$this->{contacts} = {};		# mmsi -> contact hash

	EVT_SIZE($this,\&onSize);
	EVT_CLOSE($this,\&onClose);

	$this->initTBCommands();

	return $this;
}


sub sizeList
	# size the list control to fill the window's client area
{
	my ($this) = @_;
	return if !$this->{list};
	my $sz = $this->GetClientSize();
	$this->{list}->SetSize(0,0,$sz->GetWidth(),$sz->GetHeight());
}


sub onSize
{
	my ($this,$event) = @_;
	$this->sizeList();
	$event->Skip();
}


sub onActivate
	# Called by Pub::WX::FrameBase when the window is made active.
	# EVT_SIZE does not fire on construction, so (as the other windows do)
	# we size the list here to fill the window when it first opens.
{
	my ($this) = @_;
	$this->Update();
	$this->sizeList();
}


sub initTBCommands
	# called from ctor and when the com port opens;
	# tells teensyBoat.ino to send the aggregated AIS binary packet
{
	my ($this) = @_;
	sendTeensyCommand("B_AIS=1");
}


sub onClose
	# turn off the AIS binary packet
{
	my ($this,$event) = @_;
	sendTeensyCommand("B_AIS=0");
	$this->SUPER::onClose($event);
}


sub handleBinaryData
{
	my ($this,$counter,$type,$packet) = @_;

	my $offset = 0;
	my $count = binaryByte($packet,\$offset);
	my $now = time();

	for (my $i = 0; $i < $count; $i++)
	{
		my $mmsi	= binaryUint32($packet,\$offset);
		my $name	= binaryFixStr($packet,\$offset,20);
		my $lat		= binaryDouble($packet,\$offset);
		my $lon		= binaryDouble($packet,\$offset);
		my $cog		= binaryFloat($packet,\$offset);
		my $sog		= binaryFloat($packet,\$offset);
		my $hdg		= binaryFloat($packet,\$offset);
		my $rng		= binaryFloat($packet,\$offset);
		my $brg		= binaryFloat($packet,\$offset);
		my $stype	= binaryByte($packet,\$offset);
		my $collide	= binaryByte($packet,\$offset);
		my $msgtype	= binaryByte($packet,\$offset);

		my $c = $this->{contacts}{$mmsi} ||= {};
		$c->{mmsi}		= $mmsi;
		$c->{name}		= $name;
		$c->{lat}		= $lat;
		$c->{lon}		= $lon;
		$c->{cog}		= $cog;
		$c->{sog}		= $sog;
		$c->{hdg}		= $hdg;
		$c->{rng}		= $rng;
		$c->{brg}		= $brg;
		$c->{stype}		= $stype;
		$c->{collide}	= $collide;
		$c->{msgtype}	= $msgtype;
		$c->{time}		= $now;
	}

	$this->refresh($now);
}


sub refresh
	# prune aged contacts and rebuild the list (sorted by range)
{
	my ($this,$now) = @_;
	my $contacts = $this->{contacts};

	for my $mmsi (keys %$contacts)
	{
		delete $contacts->{$mmsi}
			if ($now - $contacts->{$mmsi}{time}) > $CONTACT_TIMEOUT;
	}

	my $list = $this->{list};
	$list->DeleteAllItems();

	my @sorted = sort { $a->{rng} <=> $b->{rng} } values %$contacts;
	my $row = 0;
	for my $c (@sorted)
	{
		my $latstr = $SHOW_DEGREE_MINUTES ? degreeMinutes($c->{lat}) : round($c->{lat},5);
		my $lonstr = $SHOW_DEGREE_MINUTES ? degreeMinutes($c->{lon}) : round($c->{lon},5);

		$list->InsertStringItem($row,"$c->{mmsi}");
		$list->SetItem($row,1,$c->{name});
		$list->SetItem($row,2,"$c->{stype}");
		$list->SetItem($row,3,$latstr);
		$list->SetItem($row,4,$lonstr);
		$list->SetItem($row,5,round($c->{cog},0));
		$list->SetItem($row,6,round($c->{sog},1));
		$list->SetItem($row,7,round($c->{rng},2));
		$list->SetItem($row,8,round($c->{brg},0));
		$list->SetItem($row,9,$msg_names[$c->{msgtype}] || '');
		$list->SetItem($row,10,int($now - $c->{time})."s");

		$list->SetItemTextColour($row,wxRED) if $c->{collide};
		$row++;
	}
}



1;
