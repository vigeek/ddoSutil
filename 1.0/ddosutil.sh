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

PROGRAM="FWBuilder"

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

PROGRAM="DShield"

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

PROGRAM="geoIP"

ddosutil_geoip () {
if [ $GEOIP_BLOCK = "1" ] ; then

	if [ $USE_MIRROR -eq 1 ] ; then
		GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIPCountryCSV.zip' -z GeoIPCountryCSV.zip 
http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip)
	else
		GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIPCountryCSV.zip' -z GeoIPCountryCSV.zip http://vigeek.net/files/GeoIPCountryCSV.zip)
	fi
	    if [ $GET_SUCCESS -eq 0 ] ; then
			 log "Local version of GeoIP list current, no download required."
	    else
			 log "Local version outdated, downloaded latest GeoIP list total transfer: $GET_SUCCESS"
	    fi
	fi
	
	# Trim spaces if any from our csv list
	SAVE_FILE="ddosutil-geoip.lst"
	# Check if our chain exists, if not, create it.
	$IP_TABLES -L ddoSutil &> /dev/null
		if [ $? -eq 0 ] ; then
			$IP_TABLES -N ddoSutil
	   fi
	   
	# Build our list.
	# Add for loop (trim space and csv from geo_list)
	zcat GeoIPCountryCSV.zip | grep -i "$COUNTRY_NAME" | cut -d "," -f1,2 | sed 's/,/-/g' | tr -d '"' > $SAVE_FILE
	    if [ -f $SAVE_FILE ] ; then
			 if [ $(cat $SAVE_FILE | wc -l) -eq 0 ] ; then
				log "Error: no geoIP list built, is this correct: $COUNTRY_NAME"
	       else
				log "Completed building geoIP list for $COUNTRY_NAME total records $(cat $COUNTRY_NAME | wc -l)"
	            echo -en "\e[1;31mdSutil:\033[0m working, please wait."
	            for i in `cat $SAVE_FILE`; do
	              $IP_TABLES -A ddoSutil -s 0/0 -d 0/0 -m iprange --src-range $i -j DROP
	              let COUNTER+=1
						 if [ $(( $COUNTER % 2 )) -eq 0 ]; then
							echo -n "."
	                fi
					done
					ask_them "Begin blocking connections from $COUNTRY_NAME?"
	                if ($USER_ACTION) ; then
	                    $IP_TABLES -I INPUT -j $SAVE_FILE
	                    $IP_TABLES -I FORWARD -j $SAVE_FILE
	                fi
	       fi
		fi
fi
}

