#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbResources.pm
#-------------------------------------------------------------------------

package tbResources;
use strict;
use warnings;
use threads;
use threads::shared;
use Pub::WX::Resources;
use tbUtils;

BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw (
        $resources

		$WIN_PROG
        $WIN_BOAT
		$WIN_SEATALK
    );
}



# derived class decides if wants viewNotebook
# commands added to the view menu, by setting
# the 'command_id' member on the notebook info.

our ($WIN_PROG,
	 $WIN_BOAT,
	 $WIN_SEATALK) = (10000..11000);


# Pane data that allows looking up of notebook for windows
# This is a bit archaic and the first field is not used

my %pane_data = (
	$WIN_PROG		=> ['Unused String1',		'content'	],
	$WIN_BOAT		=> ['Unused String1',		'content'	],
	$WIN_SEATALK	=> ['Unused String2',		'content'	],
);


# Command data for this application.
# Notice the merging that takes place
# with the base appResources

my %command_data = (%{$resources->{command_data}},
	$WIN_PROG     => ['Prog', 		'Open the Program Control window'],
	$WIN_BOAT     => ['Boat', 		'Open the Boat window'],
	$WIN_SEATALK  => ['Seatalk',	'Open the Seatalk window'],
);


# Notebook data includes an array "in order",
# and a lookup by id for notebooks to be opened by
# command id's

my %notebook_data = (
	content  => {
        name => 'content',
        row => 1,
        pos => 1,
        position => '',
        title => 'Content Notebook' },
);


my @notebooks = (
    $notebook_data{content});


# lookup of name by id for those with command_ids
# prh - could be generated on fly in appFrame.pm

my %notebook_name = (
);


# Menus

my @main_menu = (
	'file_menu,&File',
	'view_menu,&View',
);

my @file_menu = ();

my @view_menu = (
	$WIN_PROG,
	$WIN_BOAT,
	$WIN_SEATALK,
	$ID_SEPARATOR,
);


# Merge and reset the single public object

$resources = { %$resources,
    app_title       => $appName,
    # temp_dir        => '/base/apps/minimum/temp',
    # ini_file        => '/base/apps/minimum/data/minimum.ini',
    # logfile         => '/base/apps/minimum/data/minimum.log',

    command_data    => \%command_data,
    notebooks       => \@notebooks,
    notebook_data   => \%notebook_data,
    notebook_name   => \%notebook_name,
    pane_data       => \%pane_data,
    main_menu       => \@main_menu,
    file_menu       => \@file_menu,
	view_menu       => \@view_menu

};




1;
