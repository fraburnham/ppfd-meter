
use strict;
use warnings;
use IO::Handle;
use Time::HiRes qw(usleep);

my %numbers = (
    0 => [0, 0, 1, 1, 1, 1, 1, 1],
    1 => [0, 0, 0, 0, 0, 1, 1, 0],
    2 => [0, 1, 0, 1, 1, 0, 1, 1],
    3 => [0, 1, 0, 0, 1, 1, 1, 1],
    4 => [0, 1, 1, 0, 0, 1, 1, 0],
    5 => [0, 1, 1, 0, 1, 1, 0, 1],
    6 => [0, 1, 1, 1, 1, 1, 0, 1],
    7 => [0, 0, 0, 0, 0, 1, 1, 1],
    8 => [0, 1, 1, 1, 1, 1, 1, 1],
    9 => [0, 1, 1, 0, 1, 1, 1, 1],
);

sub setOutput {
    my ($pin) = @_;

    open(my $f, ">", "/sys/class/gpio/export") or die "Failed to export pin $!";
    print $f "$pin";
    close $f;

    open(my $f, ">", "/sys/class/gpio/gpio$pin/direction") or die "Failed to set pin direction $!";
    print $f "out";
    close $f;

    open($f, ">", "/sys/class/gpio/gpio$pin/value") or die "Failed to get handle to pin value $!";
    return $f
}
sub freePin {
    my ($pin, $pinF) = @_;

    close $pinF;

    open(my $f, ">", "/sys/class/gpio/unexport") or die "Failed to unexport pin $!";
    print $f "$pin";
    close $f;
}
sub digitalWrite {
    my ($pinF, $value) = @_;

    print $pinF "$value";
    $pinF->flush();
    usleep(1); # hack to keep timing more consistent. Userland gpio is cabbage.
}

my $sdiPin = 67;
my $clkPin = 68;
my $lePin = 44;
my $oePin = 26;

my $sdi = setOutput($sdiPin);
my $clk = setOutput($clkPin);
my $le = setOutput($lePin);
my $oe = setOutput($oePin);

digitalWrite($sdi, 0);
digitalWrite($clk, 0);
digitalWrite($le, 0);
digitalWrite($oe, 1);

sub shiftBit {
    my ($value) = @_;
    digitalWrite($sdi, $value);
    digitalWrite($clk, 1);
    digitalWrite($clk, 0);
    digitalWrite($sdi, 0);
}

sub shiftDigit {
    my ($digit) = @_;

    digitalWrite($oe, 1);
    
    foreach (0..7) {
        shiftBit($numbers{$digit}[$_]);
    }

    digitalWrite($le, 1);
    digitalWrite($le, 0);

    digitalWrite($oe, 0);
}

foreach (0..9) {
    shiftDigit($_);
    sleep(2);
}

sleep(2);

freePin($sdiPin, $sdi);
freePin($clkPin, $clk);
freePin($oePin, $oe);
freePin($lePin, $le);
