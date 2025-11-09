#!/usr/bin/perl
#-------------------------------------------------------------------------
# tbBinary.pm
#-------------------------------------------------------------------------
# binary unpacking routes for teensyBoat.pm

package tbBinary;
use strict;
use warnings;
use Pub::Utils;
use tbUtils;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(
		$BINARY_TYPE_PROG
		$BINARY_TYPE_BOAT
		$BINARY_TYPE_ST1
		$BINARY_TYPE_ST2
		$BINARY_TYPE_0183A
		$BINARY_TYPE_0183B
		$BINARY_TYPE_2000

		binaryByte
		binaryInt16
		binaryUint16
		binaryInt32
		binaryUint32
		binaryFloat
		binaryDouble
		binaryFixStr
		binaryVarStr
	);
}


our $BINARY_TYPE_PROG 	= 1;
our $BINARY_TYPE_BOAT 	= 2;
our $BINARY_TYPE_ST1	= 10;
our $BINARY_TYPE_ST2	= 11;
our $BINARY_TYPE_0183A 	= 20;
our $BINARY_TYPE_0183B 	= 21;
our $BINARY_TYPE_2000 	= 30;



sub binaryByte
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	$$poffset += 1;
	return unpack('C',substr($buf,$offset,1));
}

sub binaryInt16
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	$$poffset += 2;
	return unpack('s',substr($buf,$offset,2));
}

sub binaryUint16
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	$$poffset += 2;
	return unpack('S',substr($buf,$offset,2));
}

sub binaryInt32
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	$$poffset += 4;
	return unpack('l',substr($buf,$offset,4));
}

sub binaryUint32
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	$$poffset += 4;
	return unpack('L',substr($buf,$offset,4));
}

sub binaryFloat		# teensy and perl floats are 32 bits
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	$$poffset += 4;
	return unpack('f',substr($buf,$offset,4));
}

sub binaryDouble	# teensy and perl doubles are 64 bits
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	$$poffset += 8;
	return unpack('d',substr($buf,$offset,8));
}

sub binaryFixStr
{
	my ($buf, $poffset, $fixed_len) = @_;
	my $offset = $$poffset;
	$$poffset += 1 + $fixed_len;
	my $len = unpack('C',substr($buf,$offset++,1));
	return unpack('A*',substr($buf,$offset,$len));
}

sub binaryVarStr
{
	my ($buf, $poffset) = @_;
	my $offset = $$poffset;
	my $len = unpack('S',substr($buf,$offset,2));
	$offset += 2;
	$$poffset = $offset + $len;
	return unpack('A*',substr($buf,$offset,$len));
}


1;
