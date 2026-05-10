use strict;
use warnings;

my @files = (
    "C:/base/apps/teensyBoat/docs/readme.md",
    "C:/base/apps/teensyBoat/docs/architecture.md",
    "C:/base/apps/teensyBoat/docs/user_interface.md",
    "C:/base/apps/teensyBoat/docs/integration.md",
);

for my $path (@files) {
    # Read raw bytes -- no layer so we see exact bytes on disk
    open(my $fh, '<:raw', $path) or die "Cannot open $path: $!";
    my $c = do { local $/; <$fh> };
    close $fh;

    my $orig = $c;
    # Remove double CR: \r\r\n -> \r\n
    $c =~ s/\r\r\n/\r\n/g;
    my $status = ($orig ne $c) ? "fixed" : "unchanged";

    open(my $out, '>:raw', $path) or die "Cannot write $path: $!";
    print $out $c;
    close $out;
    print "$status: $path\n";
}

print "Done.\n";
