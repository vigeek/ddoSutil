#!/usr/bin/env bash
# ddoSutil-harden.sh v0.3
# Harden is part of ddoSutil by Russ@viGeek.net
# This is a separate script usable outside of the ddoSutil package.
# Uses kernel filtering and iptables.

usage() {
cat << EOF
usage: $0 options

ddoSutil-harden.sh v.3

Example:
./ddoSutil-harden.sh -s -e

RUN OPTIONS:
-h Shows usage parameters.
-s Runs the sysctl hardening function (prompts to enable/disable features)
-e Enable connections per IP limitations (prompts for threshold)
-d Disable connections per IP limitation.
EOF
exit 1
}

# READ THE CONF
  if [ -f ./conf/harden.conf ] ; then
        . ./conf/harden.conf
  else
      	echo -e "Error, unable to read configuration file [./conf/harden.conf]"
        exit 1
  fi

if [ $DEBUG -eq "1" ] ; then
	set -x
fi
  
# IPTABLES Binary
IP_TABLES=`which iptables`

# No need to edit anything below this line.
TMP_OUT="/tmp/ddoSutil-out.txt"
# Constants
FUNCTION_SUCCESS=0
FUNCTION_FAILURE=1
EXIT_SUCCESS=0
EXIT_FAILURE=1

# Simple logging function
log () {
    if [ -n "$VERBOSE" ] ; then eecho "$1" ; fi
    echo "$(date +%m-%d-%Y\ %H:%M:%S) | $1" >> ./data/logs/$LOG_FILE
}

# Add some color.
eecho () {
    echo -e "\e[1;31mddoSutil:\033[0m $1"
}

# We call this function when we need to know the users desired action
ask_them () {
    echo -en "\e[1;31mddoSutil:\033[0m $1 (yes/no):"
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
    if [ ! -f ./data/sysctl.orig ] ; then
        cp $SYSCTL_FILE ./data/sysctl.orig 2> /dev/null
		if [ $? -ne $FUNCTION_SUCCESS ] ; then
			log "Backed up $SYSCTL_FILE to ./data/iptables.orig"
		else
			eecho "Error $LINENO: unable to backup $SYSCTL_FILE, please backup manually."
        fi        
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

# The disable action
limit_connections_none () {
	$IP_TABLES -L ddoSutil-harden &> /dev/null
		if [ $? -eq $FUNCTION_FAILURE ] ; then eecho "Error $LINENO:  Could not disable ddoSutil rule, does not exist" ; exit $EXIT_FAILURE ; fi
		for rulenum in `$IP_TABLES -L ddoSutil-harden --line-numbers | awk '{print $1}' | sed '1!G;h;$!d' | grep ^[0-9]` ; do
			$IP_TABLES -D ddoSutil-harden $rulenum
		done
		# Remove the chain.
		$IP_TABLES -X ddoSutil-harden
			if [ $? -eq 0 ] ; then
				eecho "successfully removed the connections per IP limitation."
			fi
}

# The enable action
limit_connections_all () {

	# Ensure that the rule doesnt already exist.
	$IP_TABLES -L ddoSutil-harden &> /dev/null
		if [ $? -eq $FUNCTION_SUCCESS ] ; then
			eecho "ddoSutil-harden connections per IP limit in place already."
			ask_them "Would you like to delete this rule so that it can be refined?"
				if [ $USER_ACTION -eq "1" ] ; then
				limit_connections_none
				return $FUNCTION_FAILURE
				fi
		fi
	
    ask_them "Do you wish to globally hard cap the amount of SYN packets per IP?"
        if [ $USER_ACTION -eq "1" ] ; then
            echo -n "How many SYN packets to allow per IP?:"
            read LIMIT
            log "SYN connection hard cap integer provided:  $LIMIT"
                if [ -z $(echo $LIMIT | grep "^[0-9]*$") ] ; then
                    eecho "Please provide a number, exiting function"
                    return $FUNCTION_FAILURE
                fi
          # Create the chain and ensure it went through successfully.
			 $IP_TABLES -N ddoSutil-harden &> /dev/null
				if [ $? -eq $FUNCTION_FAILURE ] ; then
					eecho "Error $LINENO: Unable to create chain, rule may exist or iptables error."
				   exit $EXIT_FAILURE
       		fi
          $IP_TABLES -A ddoSutil-harden -p tcp --syn -m connlimit --connlimit-above $LIMIT -j REJECT --reject-with tcp-reset
             if [ $? -eq $FUNCTION_SUCCESS ] ; then
					log "successfully implemented rule, now blocking connections per IP over $LIMIT"
				 fi
        fi
}

trap_cleanup () {
    if [ -f $TMP_OUT ] ; then rm -rf $TMP_OUT ; fi
    log "$(basename $0) has finished"
    exit $EXIT_SUCCESS
}

# Grab the users supplied options using getopts.
while getopts "hsed" opts
do
case $opts in
    h)
        usage
        exit $EXIT_SUCCESS
        ;;
    s)
        CTL_METH=true
        ;;
    e)
		  IPT_METH=true	
        ;;
    d)
        IPT_UNMETH=true
        ;;
    ?)
        usage
        exit $EXIT_FAILURE
        ;;
esac
done

if [[ -z "$CTL_METH" && -z "$IPT_METH" && -z "$IPT_UNMETH" ]] ; then usage ; fi

if [[ -n "$IPT_METH" && -n "$IPT_UNMETH" ]] ; then
	eecho "Error $LINENO:  Both enable and disable arguments provided for connection limitations"
	usage
fi


# Backup files
backup_files

if [ -n "$CTL_METH" ] ; then
# Take initial action
	take_action "/proc/sys/net/ipv4/tcp_syncookies" "net.ipv4.tcp_syncookies" "SYN filtering"
	take_action2 "/proc/sys/net/ipv4/ip_forward" "net.ipv4.ip_forward" "TCP Forwarding"

# ICMP Filtering
	take_action "/proc/sys/net/ipv4/icmp_echo_ignore_all" "net.ipv4.icmp_echo_ignore_all" "ICMP Filtering"
	take_action "/proc/sys/net/ipv4/icmp_echo_ignore_broadcasts" "net.ipv4.icmp_echo_ignore_broadcasts" "ICMP Broadcast Filtering"

# Our action loops
	action_loop "/proc/sys/net/ipv4/conf/*/accept_source_route" "Accept Redirect Protection" "2"
	action_loop "/proc/sys/net/ipv4/conf/*/accept_redirects" "Accept Redirect Protection" "2"
	action_loop "/proc/sys/net/ipv4/conf/*/send_redirects" "Send Redirect Protection" "2"
	action_loop "/proc/sys/net/ipv4/conf/*/rp_filter" "Send Redirect Protection" "1"
fi

# Limit connections ALL
if [ -n "$IPT_METH" ] ; then
	limit_connections_all
fi

if [ -n "$IPT_UNMETH" ] ; then
	limit_connections_none
fi

# Exit add trap handlers.
trap_cleanup

