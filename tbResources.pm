#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbResources.pm
#-------------------------------------------------------------------------

package apps::teensyBoat::tbResources;
use strict;
use warnings;
use threads;
use threads::shared;
use Pub::WX::Resources;
use Pub::WX::AppConfig;

# My::Utils::USE_WIN_CONSOLE_COLORS();


$ini_file = "/junk/minimum.ini";


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw (
		$appName
        $resources
        $TB_WINDOW
    );
}

our $appName = "teensyBoat";

# derived class decides if wants viewNotebook
# commands added to the view menu, by setting
# the 'command_id' member on the notebook info.

our ($TB_WINDOW, )= (10000..11000);


# Pane data that allows looking up of notebook for windows
# Sheesh, have to add the monitor to get it to open & close

my %pane_data = (
	$TB_WINDOW	=> ['Command1',		'content'	],
	#	$COMMAND2	=> ['Command2',		'output'	],
	#	$COMMAND3	=> ['Command3 this text not used', 'content'	]
);


# Command data for this application.
# Notice the merging that takes place
# with the base appResources

my %command_data = (%{$resources->{command_data}},
	$TB_WINDOW     => ['Main', 'Open the main teensyBoat window'],
	# $COMMAND2     => ['Command2', 'Do something interesting2'],
	# $COMMAND3     => ['Command3', 'Do something interesting3']
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
	$TB_WINDOW,
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
