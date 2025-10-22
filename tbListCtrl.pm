#-------------------------------------------
# apps::gitMUI::tbListCtrl
#-------------------------------------------
# Custom listCtrl for use in teensyBoat uses a
# fixed size font and allows a number of columns
# of specific widths. Columns can be designated
# as "dynamic" in which case the control handles
# highlighting changing characters in red, and
# reverting them back to black after a given time.
#
# The data is provided as a hash of records by some
# unique key, where each record is a hash with name=>value
# pairs.  This object will add fields to that record
# for state management.



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
	EVT_SCROLLWIN );
use Pub::Utils;
use base qw(Wx::ScrolledWindow);


my $ROW_HEIGHT  = 20;
my $CHANGE_TIMEOUT = 3;


my $dbg_ctrl = 0;		# life cycle
my $dbg_draw = 1;		# drawing
my $dbg_data = 1;		# data


my $font_fixed = Wx::Font->new(12,wxFONTFAMILY_MODERN,wxFONTSTYLE_NORMAL,wxFONTWEIGHT_BOLD);
our $color_change_bg = Wx::Colour->new(0xE0, 0xB0, 0xE0);		# link: staged or unstaged changes
our $color_red     	 = Wx::Colour->new(0x90, 0x00, 0x00);


sub new
{
    my ($class,$parent,$TOP_MARGIN,$columns,$data) = @_;
		# columns is an array of hashes with
		#     width => width in characters of the column
		#	  name => the name of the field within the data record for this column
		#     dynamic => 0/1 whether to highlight character changes

	display($dbg_ctrl,0,"new tbListCtrl($TOP_MARGIN)");

	my $sz = $parent->GetSize();
	my $width = $sz->GetWidth();
	my $height = $sz->GetHeight() - $TOP_MARGIN;
    my $this = $class->SUPER::new($parent,-1,[0,$TOP_MARGIN],[$width,$height]);
	bless $this,$class;

    $this->{parent} = $parent;
	$this->{frame} = $parent->{frame};
	$this->{columns} = $columns;
	$this->{data} = $data;
	$this->{update_rect} = Wx::Rect->new(0,0,$width,$height);
	$this->{scroll_pos} = 0;

	my $dc = Wx::ClientDC->new($this);
	$dc->SetFont($font_fixed);
	my $CHAR_WIDTH = $this->{CHAR_WIDTH} = $dc->GetCharWidth();
	display($dbg_ctrl+1,1,"CHAR_WIDTH=$CHAR_WIDTH");

	my $xpos = 0;
	for my $col_info (@$columns)
	{
		my $char_width = $col_info->{width};
		my $col_width = $char_width * $CHAR_WIDTH;
		$col_info->{rect} = Wx::Rect->new($xpos,0,$col_width,$ROW_HEIGHT);
		$xpos += $col_width;
	}

	$this->SetVirtualSize([$width,$height]);
	$this->SetScrollRate(0,$ROW_HEIGHT);
	$this->SetBackgroundColour(wxWHITE);
	$this->SetBackgroundStyle(wxBG_STYLE_CUSTOM);
		# This is important or else WX clears the client region
		# before calling onPaint.


	EVT_SIZE($this,\&onSize);
	EVT_IDLE($this,\&onIdle);
	EVT_PAINT($this,\&onPaint);
	EVT_SCROLLWIN($this, \&onScroll);

	return $this;
}



sub onSize
	# This method also called explicitly to invalidate
	# the entire screen and redraw it.
{
	my ($this,$event) = @_;
	my $sz = $this->GetSize();
	my $width = $sz->GetWidth();
	my $height = $sz->GetHeight();

	display($dbg_ctrl+1,0,"onSize()");
	$this->{update_rect} = Wx::Rect->new(0,$this->{scroll_pos} * $ROW_HEIGHT,$width,$height);
	$this->Update();
}


sub onScroll
{
    my ($this, $event) = @_;

    my $sz = $this->GetSize();
    my $width = $sz->GetWidth();
    my $height = $sz->GetHeight();
    my $pos = $event->GetPosition();             # Scroll position in scroll units
    my $orientation = $event->GetOrientation();  # wxVERTICAL or wxHORIZONTAL
    return if $orientation != wxVERTICAL;

	$this->{scroll_pos} = $pos;
    display($dbg_draw,1,"Scroll event: orientation=$orientation, pos=$pos");

	my $new_rect = Wx::Rect->new(0, $pos * $ROW_HEIGHT, $width, $height);
    $this->{update_rect} = $this->{update_rect}->Union($new_rect);
    $this->Refresh();
}


sub onIdle
	# On idle checks if change_time has timed out,
	# and if so, clears it, sets the last_values to
	# the current values, and adds the record(s) to
	# the update region
{
	my ($this,$event) = @_;
	my $any = 0;
	my $now = time();
	my $data = $this->{data};

	my $sz = $this->GetSize();
	my $width = $sz->GetWidth();
	my $rect = Wx::Rect->new(0,0,$width,$ROW_HEIGHT);

	for my $key (keys %$data)
	{
		my $rec = $data->{$key};
		my $row = $rec->{row};
		next if !defined($row);		# hasn't been drawn yet
		if ($rec->{change_time} && $now-$rec->{change_time} >= $CHANGE_TIMEOUT)
		{
			for my $col_info (@{$this->{columns}})
			{
				if ($col_info->{dynamic})
				{
					my $field_name = $col_info->{name};
					my $last_field = "last_$field_name";
					$rec->{$last_field} = $rec->{$field_name};
				}
			}

			$rect->SetY($row * $ROW_HEIGHT);
			$this->{update_rect} = $this->{update_rect}->Union($rect);
			$rec->{change_time} = 0;
			$any = 1;
		}
	}

	$this->Refresh() if $any;
	$event->RequestMore();
}


sub notifyDataChanged
	# Notify if the data changed, providing
	# the hash key for the record that changed.
	#
	# Note that Refresh(rect) doesn't work; $dc->GetUpdateRegion()->GetBox()
	# always returns the full client area.  So we had to implement
	# our own 'update_rect' scheme.
	#
	# Note furthermore that we will effectively always call Refresh
	# if this method is called since there is an 'always' field in all
	# usages of this object.
{
	my ($this,$key) = @_;
	display($dbg_data,0,"notifyDataChanged($key)");

	my $rec = $this->{data}->{$key};
	my $row = $rec->{row};

	if (defined($row))
	{
		for my $col_info (@{$this->{columns}})
		{
			my $changed = 0;

			# We set change_time on any dynamic fields have not been
			# drawn with the latest changes

			if ($col_info->{dynamic})
			{
				my $field_name = $col_info->{name};
				my $drawn_field = "drawn_$field_name";
				my $value = $rec->{$field_name};
				my $drawn = $rec->{$drawn_field} || '';
				$changed = $value ne $drawn;
				$rec->{change_time} = time() if $changed;
			}

			# Add add any changed dynamic fields, or the always "count"
			# field to the update region ...

			if ($changed || $col_info->{always})
			{
				my $rect = $col_info->{rect};
				$rect->SetY($rec->{row} * $ROW_HEIGHT);
				display_rect($dbg_data+2,0,"refresh",$rect) if !$changed;
				$this->{update_rect} = $this->{update_rect}->Union($rect);
				$this->Refresh($rect);
			}
		}
	}
	else
	{
		display($dbg_data,1,"NEW RECORD");
		$rec->{change_time} = time();
		$this->Refresh();

		my $sz = $this->GetSize();
		my $width = $sz->GetWidth();
		my $num_recs = keys %{$this->{data}};
		my $height = $num_recs * $ROW_HEIGHT;
		$this->SetVirtualSize([$width,$height]);
		$this->{update_rect} = Wx::Rect->new(0,0,$width,$height);
	}
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
	my $data = $this->{data};
	my $num_recs = scalar(keys %$data);
	display($dbg_draw,0,"onPaint($width,$height) num_recs($num_recs)");

	# DoPrepaeDC prepares the DC to paint in unscrolled coordinates

	my $dc = Wx::PaintDC->new($this);
	$this->DoPrepareDC($dc);

	# get update rectangle in unscrolled coords
	#
	# old code:
	# my $region = $this->GetUpdateRegion();
	# my $box = $this->{update_rect};	  # $region->GetBox();
	# my ($xstart,$ystart) = $this->CalcUnscrolledPosition($box->x,$box->y);
	# my $update_rect = Wx::Rect->new($xstart,$ystart,$box->width,$box->height);
	# display_rect($dbg_draw,1,"onPaint() bottom=$bottom update_rect=",$update_rect);
	#
	# our update_rect is already in unscrolled coords so just use it
	# and clear it for the next call

	my $update_rect = $this->{update_rect};
	$this->{update_rect} = Wx::Rect->new(0,0,0,0);
	my $bottom = $update_rect->GetBottom();

	$dc->SetFont($font_fixed);
	$dc->SetPen(wxWHITE_PEN);
	$dc->SetBrush(wxWHITE_BRUSH);
	$dc->SetBackgroundMode(wxSOLID);
		# needed for colored backgrounds
	$dc->DrawRectangle($update_rect->x,$update_rect->y,$update_rect->width,$update_rect->height);
		# draw the background; needed with BG_STYLE_CUSTOM

	# Draw the Records

	my $row = 0;
	my $ypos = 0;
	my $item_rect = Wx::Rect->new(0,0,$width,$ROW_HEIGHT);
	for my $key (sort keys %$data)
	{
		my $rec = $data->{$key};
		$rec->{row} = $row++;
		
		$item_rect->SetY($ypos);
		$this->drawRec($dc,$update_rect,$item_rect,$key,$rec)
			if $update_rect->Intersects($item_rect);

		$ypos += $ROW_HEIGHT;
		last if $ypos >= $bottom;
	}

}	# onPaint()



sub drawRec
{
	my ($this,$dc,$update_rect,$item_rect,$key,$rec) = @_;
	display_rect($dbg_draw+1,0,"drawRec($key) item_rect",$item_rect);

	my $xpos = 0;
	my $ypos = $item_rect->y;
	my $columns = $this->{columns};
	my $num_cols = @$columns;

	for (my $col_num=0; $col_num<$num_cols; $col_num++)
	{
		my $col_info = $columns->[$col_num];
		my $field_rect = $col_info->{rect};
		$field_rect->SetY($ypos);
		next if !$update_rect->Intersects($field_rect);

		my $width = $col_info->{width} * $this->{CHAR_WIDTH};
		my $dynamic = $col_info->{dynamic} ? 1 : 0;
		my $field_name = $col_info->{name};
		my $value = $rec->{$field_name};

		if ($dynamic && $rec->{change_time})
		{
			$this->drawChanges($dc,$xpos,$ypos,$rec,$field_name,$value);
		}
		else
		{
			display($dbg_draw+2,1,"drawField($xpos,$ypos,$field_name)=$value");
			$dc->SetTextForeground(wxBLACK);
			$dc->SetTextBackground(wxWHITE);
			$dc->DrawText($value,$xpos,$ypos);
		}

		$xpos += $width;
	}
}


sub drawChanges
{
	my ($this,$dc,$xpos,$ypos,$rec,$field_name,$value) = @_;
	my $len = length($value);
	my $CHAR_WIDTH = $this->{CHAR_WIDTH};
	my $last_field = "last_$field_name";
	my $last_value = $rec->{$last_field} || '';
	my $last_len = length($last_value);
	my $drawn_field = "drawn_$field_name";

	display($dbg_draw+2,0,"drawChanges($xpos,$ypos,$field_name)=$value last_value($last_value)");

	for (my $i=0; $i<$len; $i++)
	{
		my $new = substr($value,$i,1);
		my $old = $i < $last_len ? substr($last_value,$i,1) : '';
		my $changed = $new eq $old ? 0 : 1;
		$dc->SetTextForeground($changed ? wxWHITE : wxBLACK);
		$dc->SetTextBackground($changed ? $color_red  : wxWHITE);
			# requires BackgroundMode(wxSOLID)
		$dc->DrawText($new,$xpos,$ypos);
		$xpos += $CHAR_WIDTH;
	}

	$rec->{$drawn_field} = $value;

}



1;