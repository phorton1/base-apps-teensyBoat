use strict;
use warnings;

sub patch {
    my ($path, @subs) = @_;
    open(my $fh, '<:raw', $path) or die "Cannot open $path: $!";
    my $c = do { local $/; <$fh> };
    close $fh;
    my $orig = $c;
    for my $sub (@subs) { $sub->(\$c); }
    if ($orig eq $c) { print "UNCHANGED: $path\n"; return; }
    open(my $out, '>:raw', $path) or die "Cannot write $path: $!";
    print $out $c;
    close $out;
    print "Updated:   $path\n";
}

# --- readme.md: insert Prog screenshot after the first intro paragraph ---
patch("C:/base/apps/teensyBoat/docs/readme.md",
    sub {
        my $c = shift;
        $$c =~ s{(configuration, and an HTTP API for remote control and automation\.)(\r\n\r\n)}{$1$2![teensyBoat.pm -- Prog window](images/teensyBoat_Prog.jpg)$2};
    }
);

# --- user_interface.md: three insertions ---
patch("C:/base/apps/teensyBoat/docs/user_interface.md",

    # 1. Prog section: replace ASCII-art matrix code block with screenshot
    sub {
        my $c = shift;
        $$c =~ s{```\r\n              SEATALK1.*?```}{![teensyBoat.pm -- Prog window](images/teensyBoat_Prog.jpg)}s;
    },

    # 2. BoatSim section: insert Sim screenshot + red note above "The window is organized"
    sub {
        my $c = shift;
        my $img = "![teensyBoat.pm -- BoatSim window](images/teensyBoat_Sim.jpg)\r\n\r\n"
                . "Field values that changed since the previous packet are shown in **red**.\r\n"
                . "With 50+ fields updating at 1 Hz, the red highlighting is the primary way\r\n"
                . "to see at a glance what is actively moving in the simulation.\r\n\r\n";
        $$c =~ s{(The window is organized in three columns:)}{$img$1};
    },

    # 3. Seatalk section: insert ST screenshot + red note after activation sentence
    sub {
        my $c = shift;
        my $img = "\r\n\r\n![teensyBoat.pm -- Seatalk window](images/teensyBoat_ST.jpg)\r\n\r\n"
                . "Individual bytes within each datagram's **hex** column that changed since\r\n"
                . "the last receipt of that message type are highlighted with a **red** background.\r\n"
                . "This makes it easy to see which bytes within a specific datagram are varying\r\n"
                . "across successive messages, without having to compare raw hex by eye.\r\n";
        $$c =~ s{(It is activated by `B_ST=1` on open and `B_ST=0` on close\.)}{$1$img};
    }
);

print "Done.\n";
