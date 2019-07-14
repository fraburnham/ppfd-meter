#!/usr/bin/perl

use strict;
use warnings;
use IO::Handle;
use Time::HiRes qw(usleep);

my ($bus) = @ARGV;

if(not defined $bus) {
    die "Must have bus\n";
}

system("i2cset -y $bus 0x2a 0x00 0x00");
system("i2cset -y $bus 0x2a 0x01 0x30");
system("i2cset -y $bus 0x2a 0x00 0x86");
# do validation

sub trim {
    my ($val) = @_;
    $val =~ s/^\s+|\s+$//g;
    return $val;
}

while(!(hex(trim(`i2cget -y $bus 0x2a 0x00`)) & 0x20)) {
    usleep(10);
    # wait for data ready
}

my $high = hex(trim(`i2cget -y $bus 0x2a 0x12`));
my $mid = hex(trim(`i2cget -y $bus 0x2a 0x13`));
my $low = hex(trim(`i2cget -y $bus 0x2a 0x14`));

my $adc_val = ($high << 16) + ($mid << 8) + $low;

print("Adc val: ", $adc_val, "\n");

my $mV = $adc_val * (2900/2**24);
my $umol = 1.6 * $mV;

print("umol: ", $umol, "\n");

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
    "blank" => [0, 0, 0, 0, 0, 0, 0, 0],
);

sub setOutput {
    my ($pin) = @_;

    open(my $ef, ">", "/sys/class/gpio/export") or die "Failed to export pin $!";
    print $ef "$pin";
    close $ef;

    open(my $df, ">", "/sys/class/gpio/gpio$pin/direction") or die "Failed to set pin direction $!";
    print $df "out";
    close $df;

    open(my $vf, ">", "/sys/class/gpio/gpio$pin/value") or die "Failed to get handle to pin value $!";
    return $vf
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

    foreach (0..7) {
        shiftBit($numbers{$digit}[$_]);
    }
}
sub shiftNumber {
    my ($number) = @_;

    my $numberStarted;

    for (my $x = 1000; $x >= 1; $x = $x/10) {
        my $digit = int($number / $x);
        $number = $number - ($digit * $x);

        if(!$numberStarted && $digit == 0) {
            shiftDigit("blank");
        } elsif (!$numberStarted && $digit > 0) {
            $numberStarted = 1;
            shiftDigit($digit);
        } else {
            shiftDigit($digit);
        }
    }
}

if($umol > 4000) {
    $umol = 0;
}

digitalWrite($oe, 1);

shiftNumber(int($umol));

digitalWrite($le, 1);
digitalWrite($le, 0);
digitalWrite($oe, 0);
