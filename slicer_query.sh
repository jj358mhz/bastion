#!/usr/bin/env bash
#Copymiddle John Hooker VDMS December 2020
#scripts assumes the slicer server names are of this architechture:
#      slcexxx.yyy   xxx- 3 digital slicer number yyy pop name example slce012.fxn
echo "you need to log into one of the slicers at least once then log out in order for this script to work"
#echo "to check state of a sequence of slicers and verify any changes by logging certain items"
#echo "Enter port_id for the curl"
#read -p "Post ID (typically 65009): " portid
#Continue to let the user enter pops and slicer sequences until the user gets tired by entering 0
while true
do
   read -p "Pop examples (fxa, fxb, fxc) 0 entered here exits the script): " pop
   if [ $pop == '0' ]
   then
	exit 1
   fi
   read -p "Enter Start of sequence 3 digit slicer number (000-999): " start
   read -p "Enter End of sequence 3 digit slicer number (000-999): " end
   for i in `seq -w $start $end`
   do
#get the number of slicers on the server by counting the .conf files in /etc/uplynk folder (assuming that's where they are placed)
    confCount=`./slce_ssh.sh root@slce${i}.$pop 'ls -1 /etc/uplynk/*.conf | wc -l' | awk '{print $NF}'`
    lastport=$((65009+(10*(${confCount}-1))))
    echo "root@slce${i}.$pop"
    for j in `seq -w 65009 10 $lastport`
    do
       result0=`./slce_ssh.sh root@slce${i}.$pop 'curl -s localhost:'${j}'/state' | grep state_name`
       echo "slicer port: "${j} "state: "$result0
    done
#   get all the other stuff
    result1=`./slce_ssh.sh root@slce${i}.$pop 'ls -l /opt/uplynk/latest'`
    result2=`./slce_ssh.sh root@slce${i}.$pop 'ls -l /etc/uplynk/*conf'`
    result3=`./slce_ssh.sh root@slce${i}.$pop 'ps -ef | grep status2fox | grep -v grep'`
    result4=`./slce_ssh.sh root@slce${i}.$pop 'cat /opt/uplynk/plugins/scte.py' | grep 'PLUGIN_VERSION ='`
    result5=`./slce_ssh.sh root@slce${i}.$pop 'df /var' | grep [0-9]% | awk '{ print $6}' | sed 's/\%//g'`
    result6=`./slce_ssh.sh root@slce${i}.$pop 'du -sh /var/EdgeCast/logs/uplynk'`
#   echo all the rest of the stuff
    echo "Version released: "$result1
    echo "Configuration File: "$result2
    echo "Status2Fox up: "$result3
    echo "SCTE Plugin Version: "$result4
    echo "/var filesystem disk usage: "$result5"%"
    echo "Log file disk space consumed: "$result6
    echo ""
  done
done
