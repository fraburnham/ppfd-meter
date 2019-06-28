#!/bin/bash

# enable adc
echo "Enabling ADC"
echo cape-bone-iio > /sys/devices/bone_capemgr.*/slots
# find AIN6 file
analog=$(find /sys -iname "ain6")
scale_const=$(perl -e "print 2.5/1.8")
while [[ true ]];
do
    mV=$(cat $analog) # the 1800 is 1.8V idiot...
    ppfd=$(perl -e "print ($mV*$scale_const)*1.6")
    echo "$ppfd umol/m2/s"
    sleep 0.1s
done
