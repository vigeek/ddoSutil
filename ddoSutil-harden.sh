#!/bin/sh
# dSutil-harden.sh v0.2
# Harden is part of dSutil by Russ@viGeek.net
# This is a separate script usable outside of the dSutil package.
# Uses kernel filtering and iptables.

# Desired log location, default is current working directory.
LOG_FILE="$(pwd)/dSutil-harden.log"

# Location of sysctl.conf (usually /etc/sysctl.conf)
SYSCTL_FILE="/etc/sysctl.conf"

# Settings become active instantly, however if this set to 1, we also add them to sysctl making them alive on reboot.
MAKE_PERM="1"

# Verbose... 0 to disable.
VERBOSE="1"

# IPTABLES Binary
IP_TABLES=`which iptables`
# IPTables configuration file
IPT_SAVE="/etc/sysconfig/iptables"

# No need to edit anything below this line.
TMP_OUT="/tmp/dSutil-out.txt"
# Constants
FUNCTION_SUCCESS="0"
FUNCTION_FAILURE="1"

# Simple logging function
log () {
    if [ $VERBOSE -eq "1" ] ; then echo -e "\033[1m$(date +%H:%M:%S) $1\033[0m" ; fi
    echo -e "$(date +%m-%d-%Y\ %H:%M:%S) | $1" >> $LOG_FILE
}
# We call this function when we need to know the users desired action
ask_them () {
    echo -n "$1 (yes/no):"
    read ACTION
    # We use awk to change our string to lower case.    
    ACTION=$(echo $ACTION | awk '{print tolower($0)}')
      case $ACTION in
        yes)
            USER_ACTION="1"
        ;;
        no)
            USER_ACTION="0"
        ;;
        *)
            USER_ACTION="none"
            log "Invalid option given, expecting yes or no"
        ;;
    esac
}

# We verify if the backup files exist, if they do, we do nothing.
backup_files () {
    if [ ! -f $SYSCTL_FILE ] ; then
        cp $SYSCTL_FILE $(pwd)sysctl.orig
        log "Backed up $SYSCTL_FILE to $(pwd)sysctl.orig"
    fi
    
    if [ ! -f $IPT_SAVE ] ; then
        cp $IPT_SAVE $(pwd)iptables.orig
        log "Backed up $IPT_SAVE to $(pwd)iptables.orig"
    fi
}

# We determine if the value exists, if so, we replace with sed.  Otherwise we simply add it..
replace_value () {
    if [ -n "$(cat $SYSCTL_FILE | grep $1 | cut -d"=" -f1)" ] ; then
        sed -i "s/^.*$1.*$/$2/" $SYSCTL_FILE
        log "Set value:  $2 in:  $SYSCTL_FILE"
    else
        echo -e "\n$2" >> $SYSCTL_FILE
        log "Added value: $2 in:  $SYSCTL_FILE"
    fi
}

# Accepts three variables.
# VAR1 = the proc location
# VAR2 = The sysctl variable
# VAR3 The ask me name (what we ask the user)
take_action () {
VAR1=$1
VAR2=$2
VAR3=$3
    SUCCESS=`awk '{print}' $VAR1`
      if [ $SUCCESS -eq 1 ] ; then
        ask_them "$VAR3 already enabled, disable?"
            if [ $USER_ACTION -eq "1" ] ; then
                echo 0 > $VAR1 ; log "Disabled(0):  $VAR1"
                if [ $MAKE_PERM -eq "1" ] ; then replace_value "$VAR2" "$VAR2 = 0" ; fi
            fi
      else
        ask_them "$VAR3 disabled, enable?"
            if [ $USER_ACTION -eq "1" ] ; then
                echo 1 > $VAR1 ; log "Enabled(1):  $VAR1"
                if [ $MAKE_PERM -eq "1" ]; then replace_value "$VAR2" "$VAR2 = 1" ; fi
            fi
      fi
}
# Same function, lazyness prevails.  This one simply reverses the enabling variable 0/1
# Accepts three variables.
# VAR1 = the proc location
# VAR2 = The sysctl variable
# VAR3 The ask me name (what we ask the user)
take_action2 () {
VAR1=$1
VAR2=$2
VAR3=$3
    SUCCESS=`awk '{print}' $VAR1`
      if [ $SUCCESS -eq 0 ] ; then
        ask_them "$VAR3 already enabled, disable?"
            if [ $USER_ACTION -eq "1" ] ; then
                echo 1 > $VAR1 ; log "Disabled(1):  $VAR1"
                if [ $MAKE_PERM -eq "1" ] ; then replace_value "$VAR2" "$VAR2 = 0" ; fi
            fi
      else
        ask_them "$VAR3 disabled, enable?"
            if [ $USER_ACTION -eq "1" ] ; then
                echo 0 > $VAR1 ; log "Enabled(0):  $VAR1"
                if [ $MAKE_PERM -eq "1" ] ; then replace_value "$VAR2" "$VAR2 = 1" ; fi
            fi
      fi
}

# We call this is we need to loop through multiple configurations.
# Variable ($1) - Location of proc file
# Variable ($2) - Added text to ask the user.
# Variable ($3) - Which take action function to call one or two.
action_loop() {
    for i in $1 ; do
        ACTION1="net.ipv4.conf.$(echo -e $i | cut -d"/" -f7).$(echo -e $i | cut -d"/" -f8)"
        ACTION2="$2 [$(echo -e $i | cut -d"/" -f7)]"
        if [ $3 -eq 2 ] ; then take_action2 "$i" "$ACTION1" "$ACTION2" ; fi
        if [ $3 -eq 1 ] ; then take_action "$i" "$ACTION1" "$ACTION2" ; fi
    done
}

# Limit connections (iptables)
# This will limit the amount of connections per IP address, often useful for various attacks.
limit_connections () {
    ask_them "Do you want to limit web server (port 80) connections per IP?"
        if [ $USER_ACTION -eq "1" ] ; then
            echo -n "How many connections to allow per IP on port 80?:"
            read LIMIT
            log "Limit connections integer provided:  $LIMIT"
                if [ -z $(echo $LIMIT | grep "^[0-9]*$") ] ; then
                    echo "Non integer value provided, exiting function"
                    return $FUNCTION_FAILURE
                fi
            $IP_TABLES -A INPUT -p tcp --syn --dport 80 -m connlimit --connlimit-above $LIMIT -j REJECT --reject-with tcp-reset
             
        fi
}

limit_connections () {
    ask_them "Do you wish to globally hard cap the amount of SYN packets per IP?"
        if [ $USER_ACTION -eq "1" ] ; then
            echo -n "How many SYN packets to allow per IP?:"
            read LIMIT
            log "SYN connection hard cap integer provided:  $LIMIT"
                if [ -z $(echo $LIMIT | grep "^[0-9]*$") ] ; then
                    echo "Non integer value provided, exiting function"
                    return $FUNCTION_FAILURE
                fi
            iptables -A INPUT -p tcp --syn -m iplimit --iplimit-above $LIMIT -j REJECT --reject-with tcp-rese
             
        fi
}

trap_cleanup () {
    if [ -f $TMP_OUT ] ; then rm -rf $TMP_OUT ; fi
    log "$(basename 0) has finished"
}

# Backup files
backup_files

# Take initial action
take_action "/proc/sys/net/ipv4/tcp_syncookies" "net.ipv4.tcp_syncookies" "SYN filtering"
take_action "/proc/sys/net/ipv4/ip_forward" "net.ipv4.ip_forward" "TCP Forwarding"

# ICMP Filtering
take_action "/proc/sys/net/ipv4/icmp_echo_ignore_all" "net.ipv4.icmp_echo_ignore_all" "ICMP Filtering"
take_action "/proc/sys/net/ipv4/icmp_echo_ignore_broadcasts" "net.ipv4.icmp_echo_ignore_broadcasts" "ICMP Broadcast Filtering"

# Our action loops
action_loop "/proc/sys/net/ipv4/conf/*/accept_source_route" "Accept Redirect Protection" "2"
action_loop "/proc/sys/net/ipv4/conf/*/accept_redirects" "Accept Redirect Protection" "2"
action_loop "/proc/sys/net/ipv4/conf/*/send_redirects" "Send Redirect Protection" "2"
action_loop "/proc/sys/net/ipv4/conf/*/rp_filter" "Send Redirect Protection" "1"

# Exit add trap handlers.
trap_cleanup


