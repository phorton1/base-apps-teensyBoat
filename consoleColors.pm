package apps::teensyBoat::consoleColors;
use strict;
use warnings;

BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(

		colorAttr

		$color_black
	    $color_blue
	    $color_green
	    $color_cyan
	    $color_red
	    $color_magenta
	    $color_brown
	    $color_light_gray
	    $color_gray
	    $color_light_blue
	    $color_light_green
	    $color_light_cyan
	    $color_light_red
	    $color_light_magenta
	    $color_yellow
	    $color_white
	);
}



#---------------------------------------
# Console color attributes
#---------------------------------------
# low order nibble of $attr = foreground color
# high order nibble of $attr = background color
# by default the color is left as $COLOR_CONSOLE
# these are the windows colors which are not in same order as ansi colors

our $color_black            = 0x00;
our $color_blue             = 0x01;
our $color_green            = 0x02;
our $color_cyan             = 0x03;
our $color_red              = 0x04;
our $color_magenta          = 0x05;
our $color_brown            = 0x06;
our $color_light_gray       = 0x07;
our $color_gray             = 0x08;
our $color_light_blue       = 0x09;
our $color_light_green      = 0x0A;
our $color_light_cyan       = 0x0B;
our $color_light_red        = 0x0C;
our $color_light_magenta    = 0x0D;
our $color_yellow           = 0x0E;
our $color_white            = 0x0F;

our $COLOR_CONSOLE = $color_light_gray;


sub colorAttr
{
	my ($ansi_color) = @_;
	my $is_bg =
		($ansi_color>=40 && $ansi_color<=47) ||
		($ansi_color>=100 && $ansi_color<=107) ? 1 : 0;
	$ansi_color -= 10 if $is_bg;

	my $attr =

		# ansi standards mapped to windows color
		# these numbers + 10 are background colors

		$ansi_color == 30  ?  $color_black 	     	:
		$ansi_color == 31  ?  $color_red 	     	:
		$ansi_color == 32  ?  $color_green 	     	:
		$ansi_color == 33  ?  $color_brown 	 		:
		$ansi_color == 34  ?  $color_blue 	     	:
		$ansi_color == 35  ?  $color_magenta 	 	:
		$ansi_color == 36  ?  $color_cyan 	     	:
		$ansi_color == 37  ?  $color_light_gray 	:

		$ansi_color == 90  ?  $color_gray  	        :
		$ansi_color == 91  ?  $color_light_red 	 	:
		$ansi_color == 92  ?  $color_light_green 	:
		$ansi_color == 93  ?  $color_yellow 		:
		$ansi_color == 94  ?  $color_light_blue  	:
		$ansi_color == 95  ?  $color_light_magenta 	:
		$ansi_color == 96  ?  $color_light_cyan 	:
		$ansi_color == 97  ?  $color_white  		: 0;

	$attr <<= 4 if $is_bg;
	return $attr;

}


1;
