#-------------------------------------------
# apps::gitMUI::tbListCtrl
#-------------------------------------------
# Custom listCtrl for uses a fixed size font and
# allows a number of columns of specific widths
# with the last one being variable.
#
# Columns can be designated as "dynamic" in which
# case the control handles highlighting changing
# characters in red, and reverting them back to
# black after a given time.

package tbListCtrl;
use strict;
use warnings;
use threads;
use threads::shared;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_SIZE
	EVT_PAINT
	EVT_IDLE
	EVT_SCROLLWIN
	EVT_MOUSEWHEEL );
use Pub::Utils;
use base qw(Wx::ScrolledWindow);


my $DELTA_COUNT = 4;
	# number of one second onIdle cycles the changes
	# will remain red

my $dbg_ctrl = 0;		# life cycle
my $dbg_draw = 1;		# drawing
my $dbg_data = 1;		# data

my @fonts = map { Wx::Font->new($_, wxFONTFAMILY_MODERN, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_BOLD) } (3..36);

our $color_change_bg = Wx::Colour->new(0xE0, 0xB0, 0xE0);		# link: staged or unstaged changes
our $color_red     	 = Wx::Colour->new(0x90, 0x00, 0x00);


sub new
{
    my ($class,$parent,$TOP_MARGIN,$columns,$ttl_ctrl) = @_;

	display($dbg_ctrl,0,"new tbListCtrl($TOP_MARGIN)");

	my $sz = $parent->GetSize();
	my $width = $sz->GetWidth();
	my $height = $sz->GetHeight() - $TOP_MARGIN;
    my $this = $class->SUPER::new($parent,-1,[0,$TOP_MARGIN],[$width,$height]);
	bless $this,$class;

    $this->{parent} = $parent;
	$this->{frame} = $parent->{frame};
	$this->{columns} = $columns;
	$this->{ttl_ctrl} = $ttl_ctrl;
	$this->{scroll_pos} = 0;
	$this->{scroll_x} = 0;

	$this->{PAGE_LINES} = 0;		# height in lines of text
	$this->{LINE_CHARS} = 0;		# width in characters of all but last (-1) columns
	$this->{LAST_COL_CHARS} = 0;	# width in characters of largest last field

	$this->{data_set} = {};
	$this->{redraw_all} = 1;

	$this->setZoomLevel(10);		# 10 points

	$this->SetBackgroundColour(wxWHITE);
	$this->SetBackgroundStyle(wxBG_STYLE_CUSTOM);
		# This is important or else WX clears the client region
		# before calling onPaint.

	EVT_SIZE($this,\&onSize);
	EVT_IDLE($this,\&onIdle);
	EVT_PAINT($this,\&onPaint);
	EVT_SCROLLWIN($this, \&onScroll);
	EVT_MOUSEWHEEL($this, \&onMouseWheel);

	return $this;
}




sub onSize
	# This method also called explicitly to invalidate
	# the entire screen and redraw it.
{
	my ($this,$event) = @_;
	display($dbg_ctrl+1,0,"onSize()");
	$this->{redraw_all} = 1;
    $this->Refresh();
}



sub onScroll
{
    my ($this, $event) = @_;
	my $pos = $event->GetPosition();             # Scroll position in scroll units
    my $orientation = $event->GetOrientation();  # wxVERTICAL or wxHORIZONTAL
	$this->{scroll_pos} = $pos if $orientation == wxVERTICAL;
	$this->{scroll_x}   = $pos if $orientation == wxHORIZONTAL;
	$this->{scroll_pos} = $pos;
    display($dbg_draw,1,"Scroll event: orientation=$orientation, pos=$pos");
	$this->{redraw_all} = 1;
    $this->Refresh();
}


sub onMouseWheel
{
	my ($this, $event) = @_;
    if ($event->GetWheelRotation &&
		$event->ControlDown())
	{
        my $delta = $event->GetWheelRotation();
		$this->setZoomLevel($this->{zoom_level} + ($delta > 0 ? 1 : -1))
    }
	else
	{
		$event->Skip;
	}
}



#-------------------------------------------------------------
# Calculators for event handling
#-----------------------------------------------------------


sub setColumnRects
{
	my ($this) = @_;
	my $xpos = 0;
	my $line_chars = 0;
	for my $col_info (@{$this->{columns}})
	{
		my $char_width = $col_info->{width} || $this->{LAST_COL_CHARS};
		my $col_width = $char_width * $this->{CHAR_WIDTH};
		$col_info->{rect} = Wx::Rect->new($xpos,0,$col_width,$this->{LINE_HEIGHT});
		$line_chars += $char_width;
		$xpos += $col_width;
	}
	display($dbg_ctrl+1,0,"setColumneRect() LINE_CHARS <= $line_chars");
	$this->{LINE_CHARS} = $line_chars;
}


sub setZoomLevel
{
	my ($this,$level) = @_;
	$level = 0 if $level < 0;
	$level = @fonts-1 if $level > @fonts-1;
	$this->{zoom_level} = $level;

	my $dc = Wx::ClientDC->new($this);
	$dc->SetFont($fonts[$level]);

	$this->{CHAR_WIDTH} = $dc->GetCharWidth();
	$this->{LINE_HEIGHT} = $dc->GetCharHeight();
	$this->{LINE_HEIGHT} = int($this->{LINE_HEIGHT} * 1.11);

	$this->setColumnRects();
	$this->SetScrollRate($this->{CHAR_WIDTH},$this->{LINE_HEIGHT});
	$this->setPageHeight($this->{PAGE_LINES});
	$this->{redraw_all} = 1;
	$this->Refresh();
}


sub setPageHeight
{
	my ($this,$num_lines) = @_;
	$this->{PAGE_LINES} = $num_lines;
	my $width = $this->{LINE_CHARS} * $this->{CHAR_WIDTH};
	my $height = $this->{PAGE_LINES} * $this->{LINE_HEIGHT};

	# debugging

	my $sz = $this->GetSize();
	my $wwidth = $sz->GetWidth();
	display($dbg_ctrl+1,0,"setPageHeight() LINE_CHARS=$this->{LINE_CHARS} CHAR_WIDTH=$this->{CHAR_WIDTH} width($width) height($height)  window_width=$wwidth");

	$this->SetVirtualSize([$width,$height]);
}


#-----------------------------------------------
# onPaint
#-----------------------------------------------

sub onPaint
{
	my ($this, $event) = @_;
 	my $sz = $this->GetSize();
    my $width = $sz->GetWidth();
	my $height = $sz->GetHeight();
	my $data_set = $this->{data_set};
	my $num_recs = scalar(keys %$data_set);
	display($dbg_draw,0,"onPaint($width) num_recs($num_recs)");

	# DoPrepaeDC prepares the DC to paint in unscrolled coordinates

	my $dc = Wx::PaintDC->new($this);
	$this->DoPrepareDC($dc);

	$dc->SetFont($fonts[$this->{zoom_level}]);
	$dc->SetPen(wxWHITE_PEN);
	$dc->SetBrush(wxWHITE_BRUSH);
	$dc->SetBackgroundMode(wxSOLID);
		# needed for colored backgrounds
	$dc->DrawRectangle(0,0,$width,$height)
		if $this->{redraw_all};
		# draw the background; needed with BG_STYLE_CUSTOM

	# Draw the Records

	my $row = 0;
	my $ypos = 0;
	for my $key (sort keys %$data_set)
	{
		my $data = $data_set->{$key};
		$data->{row} = $row++;
		$this->drawRec($dc,$ypos,$data,$key);

		$ypos += $this->{LINE_HEIGHT};
		# last if $ypos >= $bottom;
	}
	$this->{redraw_all} = 0;
}



sub drawRec
{
	my ($this,$dc,$ypos,$data,$key) = @_;

	my $columns = $this->{columns};
	my $num_cols = @$columns;

	for (my $col_num=0; $col_num<$num_cols; $col_num++)
	{
		my $col_info = $columns->[$col_num];
		my $name = $col_info->{name};
		next if !$this->{redraw_all} && !$data->{dirty}->{$name};

		my $base_rect = $col_info->{rect};
		my $xpos = $base_rect->x;
		$dc->DrawRectangle($xpos,$ypos,$base_rect->width,$base_rect->height)
			if !$this->{redraw_all};
		
		if ($col_info->{dynamic})
		{
			$this->drawChanges($dc,$xpos,$ypos,$data,$name);
		}
		else
		{
			my $rec = $data->{rec};
			my $value = $rec->{$name};
			display($dbg_draw+2,1,"drawField($xpos,$ypos,$name)=$value");
			$dc->SetTextForeground(wxBLACK);
			$dc->SetTextBackground(wxWHITE);;
			$dc->DrawText($value,$xpos,$ypos);
		}

	}
	$data->{dirty} = {};
}


sub drawChanges
{
	my ($this,$dc,$xpos,$ypos,$data,$name) = @_;
	my $rec = $data->{rec};
	my $value = $rec->{$name};
	my $len = length($value);
	my @delta = unpack('C*',$data->{"delta_$name"});
	my $CHAR_WIDTH = $this->{CHAR_WIDTH};

	display($dbg_draw+2,0,"drawChanges($xpos,$ypos,$name)=$value");

	for (my $i=0; $i<$len; $i++)
	{
		my $highlight = $delta[$i];
		$dc->SetTextForeground($highlight ? wxWHITE : wxBLACK);
		$dc->SetTextBackground($highlight ? $color_red  : wxWHITE);
			# requires BackgroundMode(wxSOLID)
		my $char = substr($value,$i,1);
		$dc->DrawText($char,$xpos,$ypos);
		$xpos += $CHAR_WIDTH;
	}
}




#-------------------------------------------------------------
# onIdle and notifyDataChanged() can modify the data
#-------------------------------------------------------------



sub notifyDataChanged
	# Notify if the data changed, providing
	# the hash key for the record that changed.
	#
	# Note that Refresh(rect) doesn't work; $dc->GetUpdateRegion()->GetBox()
	# always returns the full client area.  So we $this->{redraw} and
	# $data->{dirty} to update selectively
{
	my ($this,$key,$rec) = @_;
	display($dbg_data,0,"notifyDataChanged($key)");

	my $data_set = $this->{data_set};
	my $data = $data_set->{$key};

	if ($data)
	{
		$data->{rec} = $rec;
		$data->{last_update} = time();
		for my $col_info (@{$this->{columns}})
		{
			my $name = $col_info->{name};
			my $dyn_changed = 0;
			if ($col_info->{dynamic})
			{
				my $changed = 0;
				my $value = $rec->{$name};
				my $last_value = $data->{"last_$name"} || '';
				my $last_len = length($last_value);
				my @delta = unpack('C*',$data->{"delta_$name"});
				my $len = length($value);		# assuming it never changes
				
				for my $i (0..$len-1)
				{
					my $v = substr($value,$i,1);
					my $l = $i<$last_len ? substr($last_value,$i,1) : '';
					if ($l ne $v)
					{
						$changed = 1;
						$delta[$i] = $DELTA_COUNT;
					}
				}


				if ($changed)
				{
					$dyn_changed = 1;
					$data->{"last_$name"} = $value;
					$data->{"delta_$name"} = pack('C*',@delta);
				}
			}

			$data->{dirty}->{$name} = 1
				if ($dyn_changed || $col_info->{always})
		}
	}
	else
	{
		my $row = scalar(keys %$data_set);
		display($dbg_data,1,"NEW RECORD($key)=row($row)");

		my $data = {
			rec	=> $rec,
			row	=> $row,
			dirty => {},
			last_update => time(), };
		$data_set->{$key} = $data;

		my $name;
		my $columns = $this->{columns};
		for my $col_info (@$columns)
		{
			$name = $col_info->{name};
			if ($col_info->{dynamic})
			{
				my $value = $rec->{$name};
				$data->{"last_$name"} = $value;
				$data->{"delta_$name"} = pack('C*',($DELTA_COUNT) x length($value));
			}
		}

		my $last_value = $rec->{$$columns[-1]->{name}};
		my $len = length($last_value);
		if ($len > $this->{LAST_COL_CHARS})
		{
			$this->{LAST_COL_CHARS} = $len;
			$this->setColumnRects();
		}

		my $num_recs = keys %{$this->{data}};
		$this->setPageHeight($num_recs);
		$this->{redraw_all} = 1;
	}
	$this->Refresh();
}



sub onIdle
	# On idle checks if a record has gone stale,
	# and if so, deletes it, and decrements the delta
	# counters for any dynamic fields acting as a one second counter.
	# the current values, and adds the record(s) to
	# the update region
{
	my ($this,$event) = @_;
	$event->RequestMore();
	$this->{last_idle_time} ||= 0;

	my $now = int(time());	# JIC Time::HiRes
	return if $now == $this->{last_idle_time};
	$this->{last_idle_time} = $now;

	# prune stale records

	my $any_deletes = 0;
	my $data_set = $this->{data_set};
	my $ttl_ctrl = $this->{ttl_ctrl};
	if ($ttl_ctrl)
	{
		my $ttl = $this->{ttl_ctrl}->GetValue();
		if ($ttl !~ /^\d+$/)
		{
			$ttl = 10;
			$this->{ttl_ctrl}->SetValue($ttl);
		}

		for my $key (keys %$data_set)
		{
			my $data = $data_set->{$key};
			if ($now - $data->{last_update} > $ttl)
			{
				warning($dbg_ctrl+1,1,"deleting data($key)");
				$this->{parent}->notifyDelete($data->{rec});
				delete $data_set->{$key};
				$any_deletes++;
			}
		}
	}

	# reset and rebuild the LAST_COL_CHARS if any $any_deletes

	my $columns = $this->{columns};
	my $last_field = $$columns[-1]->{name};
	$this->{LAST_COL_CHARS} = 0 if $any_deletes;

	# turn off highlighting of changed records

	my $any_changes = 0;
	for my $key (keys %$data_set)
	{
		my $data = $data_set->{$key};

		# set new largest LAST_COL_CHARS

		if ($any_deletes)
		{
			my $rec = $data->{rec};
			my $value = $rec->{$last_field};
			my $len = length($value);
			if ($len > $this->{LAST_COL_CHARS})
			{
				$this->{LAST_COL_CHARS} = $len;
				display($dbg_ctrl+1,1,"setting LAST_COL_CHARS($value) = $len",0,$UTILS_COLOR_LIGHT_CYAN);
			}
		}

		# turn off the highlighting

		my $dyn_changed = 0;
		for my $col_info (@{$this->{columns}})
		{
			if ($col_info->{dynamic})
			{
				my $changed = 0;
				my $name = $col_info->{name};
				my @delta = unpack('C*',$data->{"delta_$name"});
				for my $i (0..@delta-1)
				{
					if ($delta[$i])
					{
						$delta[$i]--;
						$changed = 1;
					}
				}
				if ($changed)
				{
					$dyn_changed = 1;
					$data->{"delta_$name"} = pack('C*',@delta);
					$data->{dirty}->{$name} = 1;
				}
			}
		}

		if ($dyn_changed)
		{
			$any_changes++;
		}
	}

	if ($any_deletes)
	{
		display($dbg_ctrl+1,0,"deletes",0,$UTILS_COLOR_BROWN);
		$this->setColumnRects();
		$this->setPageHeight(scalar(keys %$data_set));
		$this->{redraw_all} = 1;
		$this->Refresh();
	}
	elsif ($any_changes)
	{
		display($dbg_ctrl+1,0,"changes",0,$UTILS_COLOR_BROWN);
		$this->Refresh();
	}
}


1;