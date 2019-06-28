#!/usr/bin/perl

system("i2cset -y 1 0x2a 0x00 0x00");
system("i2cset -y 1 0x2a 0x01 0x30");
system("i2cset -y 1 0x2a 0x00 0x86");
# do validation

while(!(hex(`i2cget -y 1 0x2a 0x00`) & 0x20)) {
    # wait for data ready
}

$high = hex(`i2cget -y 1 0x2a 0x12`);
$mid = hex(`i2cget -y 1 0x2a 0x13`);
$low = hex(`i2cget -y 1 0x2a 0x14`);

$adc_val = ($high << 16) + ($mid << 8) + $low;

print("Adc val: ", $adc_val, "\n");

$mV = $adc_val * (2900/2**24);
$umol = 1.6 * $mV;

print("mV: ", $mV, "\n");
print("umol/m2/s: ", $umol, "\n");
