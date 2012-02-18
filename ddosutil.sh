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
PROGRAM="main"

# Which iptables.
IP_TABLES=`which iptables`
IP_TABLES_SAVE=`which iptables-save`

# Source the config.
if [ -f "ddosutil.conf" ] ; then
	. ./ddosutil.conf
else
	echo -e "Unable to read the configuration file"
	exit $FAILED
fi


################################################
# General Functions & Init
################################################

eecho () {
    echo -e "\e[1;31mddoSutil:\033[0m $1"
}

log () {
    if [ -n "$VERBOSE" ] ; then eecho "$1" ; fi
echo "$(date +%m-%d-%Y\ %H:%M:%S) | [$PROGRAM] | $1" >> $LOG_FILE
}

# Create initial log entry
log "ddoSutil has kicked off"

# See if CSF/LFD is running.
CSFD=`pidof lfd`
	if [ -n "$CSFD" ] ; then
		log "CSF [lfd] daemon detected"
		eecho "The CSF [lfd] daemon is currently running..."
		eecho "If using the ddoSutil firewall this may overwrite our rules"
		eecho "The CSF [lfd] daemon can be temporarily disabled:  csf --disable"
	fi

# See if APF is installed.
APFD=`pidof apfd`
	if [ -n "$APFD" ] ; then
		log "APF [apfd] daemon detected"
		eecho "The APF [apfd] daemon is currently running..."
		eecho "If using the ddoSutil firewall this may overwrite our rules"
		eecho "APF can be temporarily disabled by stopping the service"
	fi

# Whatever the current rules are attempt to back them up.
if [ ! -f iptables.back ] ; then
	log "saving current iptable rules to iptables.back"
	$IP_TABLES_SAVE > iptables.back
fi	

################################################
# Firewall Builder 
################################################

PROGRAM="FWBuilder"

if [ $FW_BUILDER -eq "1" ] ; then
	log "firewall builder is enabled, building rules."

	# Flush the current rules.
	$IP_TABLES -F &> /dev/null
		if [ $? -eq $FAILED ] ; then
			log "Unable to clear iptable rules."
			return $FAILED
		fi
	# Prepare baseline rules
	$IP_TABLES -F -t nat
	$IP_TABLES -F -t mangle	
	$IP_TABLES -F -t filter
	$IP_TABLES -X
	# We should now have a cleared out policy, let's create a chain.
	$IP_TABLES -N $CHAIN &> /dev/null
		if [ $? -eq $FAILED ] ; then
			log "Unable to create iptable rules"
			return $FAILED
		fi
	# Accept All Out
	$IP_TABLES -P OUTPUT ACCEPT
	# Accept All In (we will block after our rules.)
	$IP_TABLES -P INPUT ACCEPT
	# Accept lo
	$IP_TABLES -A INPUT -i lo -j ACCEPT
	log "flushed the firewall and created baseline policy"
	# Drop INVALID packets
	if [ $DROP_INVALID -eq "1" ] ; then $IP_TABLES -A INPUT -m state --state INVALID -j DROP ; fi
	# Accept all in Established Related State
	$IP_TABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	# Only accept new connections in SYN state.
	$IP_TABLES -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
	# Drop fragmented packets.
	if [ $DROP_FRAGMENTED -eq "1" ] ; then $IP_TABLES -A INPUT -f -j DROP ; fi
	# Drop Xmas packets
	if [ $DROP_XMAS -eq "1" ] ; then $IP_TABLES -A INPUT -p tcp --tcp-flags ALL ALL -j DROP ; fi
	# Drop NULL packets
	if [ $DROP_NULL -eq "1" ] ; then $IP_TABLES -A INPUT -p tcp --tcp-flags ALL NONE -j DROP ; fi
	log "enabled baseline drop rules for undesirable packets"

	# Begin building a simple firewall
	for IFACE in ${IFACE_LIST//,/ } ; do
		log "Opening requested ports on [$IFACE]"
		
		for tcpin in ${TCP_IN//,/ } ; do
			$IP_TABLES -A INPUT -p tcp -i $IFACE --dport $tcpin -m state --state NEW -j ACCEPT
		done

		for tcpin in ${UDP_IN//,/ } ; do
			$IP_TABLES -A INPUT -p udp -i $IFACE--dport $tcpin -m state --state NEW -j ACCEPT
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
 log "enabling dshield block list"
	wget -q -O 'dshield.lst' http://feeds.dshield.org/block.txt
		if [ ! -f dshield.lst ] ; then
			eecho "Error downloading dshield list"
			return $FAILURE
		fi
	$IP_TABLES -N $PROGRAM
	for dlist in `cat dshield.lst | grep ^[0-9] | awk '{print $1,$3}' | sed '{s| |/|g}'` ; do
		$IP_TABLES -A $PROGRAM -s $dlist -j DROP
	done
		$IP_TABLES -A $PROGRAM -j RETURN
                $IP_TABLES -I INPUT 1 -j $PROGRAM
fi

################################################
# Abuse.ch ZeusTracker Blocker 
# Maintains a list of known botnets
################################################

PROGRAM="ZeusBlock"

if [ $ZEUS_BLOCK="1" ] ; then
 log "enabling zeus block list"
	wget -q -O 'zeustrack.lst' --no-check-certificate https://zeustracker.abuse.ch/blocklist.php?download=ipblocklist
		if [ ! -f zeustrack.lst ] ; then
			eecho "Error downloading zeus tracker list"
			return $FAILURE
		fi
	# Begin creating list.
	$IP_TABLES -N $PROGRAM
	for dlist in `cat zeustrack.lst | grep -v '#'` ; do
        $IP_TABLES -A $PROGRAM -s $dlist -j DROP
	done
		$IP_TABLES -A $PROGRAM -j RETURN
		$IP_TABLES -I INPUT 1 -j $PROGRAM
fi

################################################
# viGeek ddoSutil Blocking 
# We maintain a small botnet list.
################################################

PROGRAM="viGeek"

if [ $VIGEEK_BLOCK="1" ] ; then
 log "enabling viGeek block list"
	wget -q -O 'vigeek.lst' http://vigeek.net/projects/ddoSutil/vigeek.txt
		if [ ! -f vigeek.lst ] ; then
			eecho "Error downloading dshield list"
		return $FAILURE
		fi
	# Begin creaitng list
	$IP_TABLES -N $PROGRAM
	for dlist in `cat vigeek.lst | grep -v '#'` ; do
        $IP_TABLES -A $PROGRAM -s $dlist -j DROP
	done
		$IP_TABLES -A $PROGRAM -j RETURN
                $IP_TABLES -I INPUT 1 -j $PROGRAM

fi

##############################################################
# IANA Blocking
##############################################################

PROGRAM="IANA"

if [ $IANA_BLOCK -eq "1" ] ; then
 log "blocking IANA reserved ip ranges"
	$IP_TABLES -N $PROGRAM
	#
	$IP_TABLES -A $PROGRAM -s 0.0.0.0/7 -j DROP
	$IP_TABLES -A $PROGRAM -s 2.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 5.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 14.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 23.0.0.0/8 -j DROP   
	$IP_TABLES -A $PROGRAM -s 27.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 31.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 36.0.0.0/7 -j DROP
	$IP_TABLES -A $PROGRAM -s 39.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 42.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 46.0.0.0/8 -j DROP 
	$IP_TABLES -A $PROGRAM -s 49.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 50.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 100.0.0.0/6 -j DROP
	$IP_TABLES -A $PROGRAM -s 104.0.0.0/6 -j DROP
	$IP_TABLES -A $PROGRAM -s 175.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 176.0.0.0/7 -j DROP
	$IP_TABLES -A $PROGRAM -s 179.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 181.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 182.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 185.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 223.0.0.0/8 -j DROP
	$IP_TABLES -A $PROGRAM -s 240.0.0.0/4 -j DROP
	#
	$IP_TABLES -A $PROGRAM -j RETURN
	# BLOCK it
        $IP_TABLES -I INPUT 1 -j $PROGRAM

fi

################################################
# Cymru Bogon Blocker 
################################################

PROGRAM="bogon"

if [ $BOGON_BLOCK="1" ] ; then
 log "enabling team-cymru.org bogon block list"
	wget -q -O 'bogon.lst' http://www.team-cymru.org/Services/Bogons/bogon-bn-nonagg.txt
		if [ ! -f bogon.lst ] ; then
			eecho "Error downloading bogon list"
		return $FAILURE
		fi
	# Begin creaitng list
	$IP_TABLES -N $PROGRAM
	for dlist in `cat bogon.lst | grep -v '#'` ; do
        $IP_TABLES -A $PROGRAM -s $dlist -j DROP
	done
		$IP_TABLES -A $PROGRAM -j RETURN
		$IP_TABLES -I INPUT 1 -j $PROGRAM
fi

################################################
# GeoIP Blocker 
################################################

PROGRAM="geoIP"

ddosutil_geoip () {
if [ $GEOIP_BLOCK = "1" ] ; then
 log "enabling geoIP blocking"
	if [ $USE_MIRROR -eq 1 ] ; then
		GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIP.zip' -z GeoIP.zip http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip)
	else
		GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIP.zip' -z GeoIP.zip http://vigeek.net/files/GeoIPCountryCSV.zip)
	fi
		if [ $GET_SUCCESS -eq 0 ] ; then
			log "Local version of GeoIP list current, no download required."
		else
			log "Local version outdated, downloaded latest GeoIP list total transfer: $GET_SUCCESS"
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
zcat GeoIP.zip | grep -i "$COUNTRY_NAME" | cut -d "," -f1,2 | sed 's/,/-/g' | tr -d '"' > $SAVE_FILE
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


################################################
# Connection Limiting 
################################################

PROGRAM="ConnLimit"

if [ $CONN_LIMIT -eq "1" ] ; then

	$IP_TABLES -N $PROGRAM &> /dev/null
	if [ $? -eq $FAILED ] ; then
		# The chain exists, so we will just add to it....
		log "chain exists, adding connection limiting to it."
	fi
	
	for CPORT in ${LIMIT_PORTS//,/ } ; do
		$IP_TABLES -A $PROGRAM -p tcp --syn --dport $CPORT -m connlimit --connlimit-above $CONN_MAX -j REJECT
	done
# Make it active.
$IP_TABLES -A $PROGRAM -j RETURN
$IP_TABLES -I INPUT 1 -j $PROGRAM


fi



################################################
# SYN Flood Protection				 
################################################

PROGRAM="SYNProtect"

if [ $SYN_LIMIT -eq "1" ] ; then

	$IP_TABLES -N $PROGRAM &> /dev/null
		if [ $? -eq $FAILED ] ; then
			# The chain exists, so we will just add to it....
			log "chain exists, adding SYN flood blocking to existing chain."
		fi

	for CPORT in ${LIMIT_PORTS//,/ } ; do
		$IP_TABLES -A $PROGRAM -p tcp --syn --dport $CPORT -m connlimit --connlimit-above $CONN_MAX -j REJECT
	done
	
$IP_TABLES -A $PROGRAM -j RETURN
$IP_TABLES -I INPUT 1 -j $PROGRAM

fi

# SYN Cookies.
if [ $SYN_COOKIES -eq "1" ] ; then echo 1 > /proc/sys/net/ipv4/tcp_syncookies ; fi

# Set SYN Retries limitations.
if [ $SYN_RETRIES -eq "1" ] ; then
	echo $SYN_ACK_RETRY > /proc/sys/net/ipv4/tcp_synack_retries
	echo $SYN_RETRY > /proc/sys/net/ipv4/tcp_syn_retries
fi

################################################
# Timeout Reductions + others.				 
################################################

if [ $TIMEOUT_REDUCE -eq "1" ] ; then
	echo 15 > /proc/sys/net/ipv4/tcp_fin_timeout
	echo 1800 > /proc/sys/net/ipv4/tcp_keepalive_time
	echo 0 > /proc/sys/net/ipv4/tcp_sack
	echo 0 > /proc/sys/net/ipv4/tcp_window_scaling
	# Slightly reduce the default tcp_retries.
	echo 3 > /proc/sys/net/ipv4/tcp_retries1
	echo 10 > /proc/sys/net/ipv4/tcp_retries2
fi

# Set back log queue, first verify our new value is greater than old.
CUR_VALUE=`cat /proc/sys/net/ipv4/tcp_max_syn_backlog`
if [ $CUR_VALUE -gt $BACKLOG_QUEUE ] ; then
	eecho "Desired backlog value $BACKLOG_QUEUE is less than $CUR_VALUE"
else
	echo -e $BACKLOG_QUEUE > /proc/sys/net/ipv4/tcp_max_syn_backlog
fi

################################################
# Basic spoof protection.				 
################################################

PROGRAM="SPOOFprotect"

if [ $SPOOF_PROTECT -eq "1" ] ; then

	# Ancient host.conf modifications.
	if [ -z "$(grep 'order hosts,bind' /etc/host.conf)" ] ; then
		echo -e "order hosts,bind" >> /etc/host.conf
	fi
	
	if [ -z "$(grep 'multi on' /etc/host.conf)" ] ; then
		echo -e "multi on" >> /etc/host.conf
	fi
	
	if [ -z "$(grep 'nospoof on' /etc/host.conf)" ] ; then
		echo -e "nospoof on" >> /etc/host.conf
	fi
	
	if [ -z "$(grep 'spoofalert on' /etc/host.conf)" ] ; then
		echo -e "spoofalert on" >> /etc/host.conf
	fi
	
	# Enable reverse path filter on all interfaces.
	for rpf in /proc/sys/net/ipv4/conf/*/rp_filter; do
		echo 1 > $rpf
	done

fi

################################################
# Finish IPTable rules.
################################################

# Final DROP Rules on inbound.

$IP_TABLES -A INPUT -j DROP
