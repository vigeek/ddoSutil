#!/bin/bash
################################################
# ddoSutil 1.0 russ@vigeek.net 
################################################

# Const
FAILED=1
SUCCESS=0

# Chain name.
CHAIN="ddoSutil"

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
echo "$(date +%m-%d-%Y\ %H:%M:%S) | $PROGRAM | $1" >> $LOG_FILE
}

# Add some color.
eecho () {
    echo -e "\e[1;31mddoSutil:\033[0m $1"
}

################################################
# Firewall Builder 
################################################

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

# Begin building a simple firewall
for IFACE in ${IFACE_LIST//,/ } ; do

$IP_TABLES -A $CHAIN -i $IFACE -m state --state ESTABLISHED, RELATED -j ACCEPT

for tcpin ${TCP_IN//,/ } ; do
$IP_TABLES -A $CHAIN -p tcp -i $IFACE --dport $tcpin -m state --state NEW -j ACCEPT
done

for tcpin ${UDP_IN//,/ } ; do
$IP_TABLES -A $CHAIN -p udp -i $IFACE--dport $tcpin -m state --state NEW -j ACCEPT
done
done

# We add our final lines at the end of the script to enforce blocking.

fi

################################################
# DShield Blocker 
# Maintains a list of suspicious networks
################################################

PROGRAM="DShield"

if [ $DSHIELD_BLOCK="1" ] ; then
wget -q -O 'dshield.lst' http://feeds.dshield.org/block.txt
if [ ! -f dshield.lst ] ; then
eecho "Error downloading dshield list"
return $FAILURE
fi


fi

################################################
# Abuse.ch ZeusTracker Blocker 
# Maintains a list of known botnets
################################################

PROGRAM="ZeusBlock"

if [ $ZEUS_BLOCK="1" ] ; then
wget -q -O 'zeustrack.lst' --no-check-certificate https://zeustracker.abuse.ch/blocklist.php?download=ipblocklist
if [ ! -f zeustrack.lst ] ; then
eecho "Error downloading zeus tracker list"
return $FAILURE
fi


fi

################################################
# viGeek ddoSutil Blocking 
# We maintain a small botnet list.
################################################

PROGRAM="viGeek"

if [ $VIGEEK_BLOCK="1" ] ; then
wget -q -O 'vigeek.lst' http://vigeek.net/projects/ddoSutil/vigeek.txt
if [ ! -f vigeek.lst ] ; then
eecho "Error downloading dshield list"
return $FAILURE
fi


fi

###################################
# GeoIP Blocker #
###################################

PROGRAM="geoIP"

ddosutil_geoip () {
if [ $GEOIP_BLOCK = "1" ] ; then

if [ $USE_MIRROR -eq 1 ] ; then
GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIPCountryCSV.zip' -z GeoIPCountryCSV.zip \
http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip)
else
GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIPCountryCSV.zip' -z GeoIPCountryCSV.zip \
http://vigeek.net/files/GeoIPCountryCSV.zip)
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


###################################
# Connection Limiting 
###################################

if [ $CONN_LIMIT -eq "1" ] ; then

$IP_TABLES -N $CHAIN &> /dev/null
if [ $? -eq $FAILED ] ; then
# The chain exists, so we will just add to it....
log "chain exists, adding connection limiting to it."
fi

for CPORT in ${LIMIT_PORTS//,/ } ; do
$IP_TABLES -A $CHAIN -p tcp --syn --dport $CPORT -m connlimit --connlimit-above $CONN_MAX -j REJECT
done
fi



