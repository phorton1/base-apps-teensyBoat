#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbWin.pm
#-------------------------------------------------------------------------
# The main TB window, can't be closed


package apps::teensyBoat::tbWin;
use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_CLOSE );
use Pub::Utils;
use Pub::WX::Window;
use base qw(Wx::Window MyWX::Window);

my $counter_ctrl;
my $data_ctrl;


sub new
{
	my ($class,$frame,$book,$id,$data) = @_;
	my $this = $class->SUPER::new($book,$id);
	display(0,0,"tbWin::new() called");
	$this->MyWindow($frame,$book,$id,"Main");

	$counter_ctrl = Wx::StaticText->new($this,-1,"",[10,10]);
	$data_ctrl = Wx::StaticText->new($this,-1,"",[10,30]);

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
	my ($this,$counter,$binary_data) = @_;
	# display(0,0,"handleBinaryData($counter) len=".length($binary_data));
	my $show_data = unpack("H*",$binary_data);
	$counter_ctrl->SetLabel($counter);
	$data_ctrl->SetLabel($show_data);

}



1;
