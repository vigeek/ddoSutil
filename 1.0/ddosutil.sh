#!/bin/bash
###################################
#	ddoSutil 1.0 russ@vigeek.net   # 
###################################

# Const
FAILED=1
SUCCESS=0

# This holds a string for logging to identify which utility is logging what.
PROGRAM=""

# Which iptables.
IP_TABLES=`which iptables`

# Source the config.
	if [ -f "ddosutil.conf" ]
		. ./ddosutil.conf
	else
		echo -e "Unable to read the configuration file"
		exit $FAILED
	fi

# Global Functions

# Simple logging function
log () {
    if [ -n "$VERBOSE" ] ; then eecho "$1" ; fi
    echo "$(date +%m-%d-%Y\ %H:%M:%S) | $PROGRAM | $1" >> ./data/logs/$LOG_FILE
}

# Add some color.
eecho () {
    echo -e "\e[1;31mddoSutil:\033[0m $1"
}

###################################
# Firewall Builder					 #
###################################

if [ $FW_BUILDER -eq "1" ] ; then

# Flush the current rules.
$IP_TABLES -F &> /dev/null
	if [ $? -eq $FAILED ] ; then
		log "Unable to clear iptable rules."
		return $FAILED
	fi
# We should now have a cleared out policy, let's create a chain.
$IP_TABLES -N ddoSutil &> /dev/null
	if [ $? -eq $FAILED ] ; then
		log "Unable to create iptable rules"
		return $FAILED
	fi


fi

###################################
# DShield Blocker						 #
###################################

if [ $DSHIELD_BLOCK="1" ] ; then
	wget -q -O 'dshield.txt' http://feeds.dshield.org/block.txt
		if [ ! -f dshield.txt ] ; then
			eecho "Error downloading dshield list"
			return $FAILURE
		fi


fi

###################################
# GeoIP Blocker						 #
###################################

if [ $GEOIP_BLOCK = "1" ] ; then


fi
