#!/bin/sh
cd /tmp
echo $1 > /tmp/host
echo $2 > /tmp/port
java -jar ./apache-jmeter-5.4.1/bin/ApacheJMeter.jar -t teastore_browse_nogui.jmx -Jhostname $1 -Jport $2 -JnumUser 10 -JrampUp 1 -l mylogfile.log -n



