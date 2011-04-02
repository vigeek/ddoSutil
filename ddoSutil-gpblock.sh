#!/usr/bin/env bash
# dSutil-gpblock.sh 0.1 - filters attack get/post requests, bans requesters.
# This is a separate script usable outside of the dSutil package.
# Actively builds an IPTables ban list, keep using until attack traffic reduced.

# READ THE CONF
  if [ -f ./conf/gpblock.conf ] ; then
        . ./conf/gpblock.conf
  else
        echo -e "Error, unable to read configuration file [./conf/gpblock.conf]"
        exit 1
  fi


usage() {
cat << EOF
usage: $0 options

dSutil-gpblock.sh 0.1

RUN OPTIONS:
-h Shows usage parameters.
-r Run the script, requires filter (ie: dSutil-gpblock.sh -r '/ajax?data=brand')
-d Delete the IPTables chain with our blocked IP addresses.
-v Verbose output to console.
EOF
exit 1
}

# Counter integer
COUNTER="0"
# Setting our IFS allows to better parse/read logs.
IFS=$(echo -en "\n\b")
# Path to iptables
IP_TABLES=`which iptables`

# Simple logging function, if verbose enabled we also send to console.
log () {
    if [ $VERBOSE -eq 1 ] ; then necho "$1" ; fi
echo -e "$(date +%m-%d-%Y\ %H:%M:%S) | $1" >> ./data/logs/$LOG_FILE
}

# Put some color in our echo statements
necho () {
    echo -e "\e[1;31mdSutil:\033[0m $1"
}

ask_them () {
    echo -e ""
    echo -n "$1 (yes/no):"
    read ACTION
    # We use awk to change our string to lower case.
    ACTION=$(echo $ACTION | awk '{print tolower($0)}')
      case $ACTION in
        yes)
            USER_ACTION=true
        ;;
        no)
            USER_ACTION=false
        ;;
        *)
            USER_ACTION=false
log "Invalid option given, expecting yes or no"
        ;;
    esac
}

build_lists() {
# The primary work, go through log, find our pattern, add to list. Then compare against our max_requests quota.
# Depending on log size and system speed, entire process should take under 1 minute.
echo -en "\e[1;31mdSutil:\033[0m working, building requests list"
for line in `grep -i $FILTER $APACHE_LOG | awk '{ print $1,$6,$7}'`; do
if [[ $line == *$FILTER* ]] ; then
echo -e "$line" | awk '{print $1}' >> $TEMP_FILE
        let COUNTER+=1
        if [ $VERBOSE -eq 1 ] ; then
if [[ $COUNTER == *10* ]]; then
echo -n "."
            fi
fi
fi
done
echo -e ""
necho "Operation completed total records: $COUNTER"


# Now that we are done passing the log, let's verify if a user is over our max_requestst hreshold
COUNTER="0"
echo -en "\e[1;31mdSutil:\033[0m working, building IP offender list"
for requests in `awk '{print}' $TEMP_FILE | sort -u` ; do
SUCCESS=`grep -i $requests $TEMP_FILE | wc -l`
    if [ $SUCCESS -gt $MAX_REQUESTS ] ; then
let COUNTER+=1
        if [ $VERBOSE -eq 1 ] ; then
if [[ $COUNTER == *0* ]]; then
echo -n "."
            fi
fi
echo -e $requests >> ./data/$BAN_FILE
    fi
sed -i '/'$requests'/d' $TEMP_FILE
done
echo -e ""
necho "Operation completed total offending IP addresses: $COUNTER"
}

ban_the_list () {
    ask_them "Do you want to block offending IP addresses now?"
}

remove_ban_list () {
    rm -f ./data/$BAN_FILE
}

# Go through and get our user arguments.
while getopts "hr:dv" opts
do
case $opts in
    h)
        usage
        exit 1
        ;;
    r)
        FILTER=$OPTARG
        ;;
    d)
        DROP="1"
        ;;
    v)
        # Enable verbose methods
        VERBOSE="1"
        ;;
    ?)
        usage
        exit
        ;;
esac
done

# Ensure the user only supplied a single action
if [[ -n "$FILTER" && -n "$DROP" ]] ; then necho "Both delete (-d) and run (-r) arguments given, only select one action" ; exit 1 ; fi

if [ $DROP -eq "1" ] ; then
	if [ -f ./data/$BAN_FILE ] ; then
	ask_them "You're about to remove $(cat ./data/$BAN_FILE | wc -l) records from IPTables, continue?"
		if ($USER_ACTION ) ; then
			remove_ban_list
		fi
	then
fi
