#!/usr/bin/env bash
# dSutil-geoIP.sh 0.3 part of dSutil by Russ@viGeek.net.
# This is the separate script usable outside of the dSutil package.

# Requires iptables active/enabled.

# READ THE CONF
  if [ -f ./conf/geoip.conf ] ; then
	. ./conf/geoip.conf
  else
	echo -e "Error, unable to read configuration file [./conf/geoip.conf]"
	exit 1
  fi

# No need to edit anything below this.

usage() {
cat << EOF
usage: $0 options

dSutil geoIP block v0.1

RUN OPTIONS:
-h Shows usage parameters.
-c Country to block, use quotes for spaces i.e 'United States'
-a Action: 1 to block, 0 to unblock (i.e -a 1)
-s Show country status and statistics (i.e: dSutil-geoip.sh -c nigeria -s)
-v Verbose output to console.
EOF
exit 1
}


IP_TABLES=`which iptables`

# Country to block, uses full name i.e Russia, China, Germany, etc.
# This is passed at script runtime. Case not sensitive.
COUNTRY_NAME=

# Hold the desire to block(1), unblock(0).. Passed at runtime.
ACTION=
# Hold counter integer
COUNTER="0"

# We call this function when we need to know the users desired action
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

# Simple logging function.
log () {
    if [ $VERBOSE ] ; then necho "$(date +%H:%M:%S) $1" ; fi
    echo -e "$(date +%m-%d-%Y\ %H:%M:%S) | $1" >> ./logs/$LOG_FILE
}

# Create our directory to hold the zones if it does not exist..

show_status () {
    SAVE_FILE=$(echo $COUNTRY_NAME | tr -d ' ')
    if [ `$IP_TABLES -L $SAVE_FILE | wc -l` -gt 0 ] ; then
     necho "IPTables chain rule [$COUNTRY_NAME] active"
     necho "IPTables chain rule $COUNTRY_NAME: `$IP_TABLES -L $SAVE_FILE | wc -l` total records."
    fi
exit 1
}

necho () {
    echo -e "\e[1;31mdSutil:\033[0m $1"
}

iptables_method () {
# We use CURL to cross reference our files.
if [ $GEO_UPDATE -eq 1 ] ; then
    if [ $USE_MIRROR -eq 1 ] ; then
	pwd
     GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIPCountryCSV.zip' -z GeoIPCountryCSV.zip http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip)
    else
     GET_SUCCESS=$(curl -s -w %{size_download} -o 'GeoIPCountryCSV.zip' -z GeoIPCountryCSV.zip http://vigeek.net/files/GeoIPCountryCSV.zip)
    fi
    # If downloaded 0 bytes then.
	echo -e $GET_SUCCESS
    if [ $GET_SUCCESS -eq 0 ] ; then
        log "Local version of GeoIP list current, no download required."
    else
        log "Local version outdated, downloaded latest GeoIP list total transfer: $GET_SUCCESS"
    fi
fi

# The block lists get stored in country.txt files, i.e Russia.txt
# This allows us to block/unblock countries independently.
if [ $ACTION -eq 1 ] ; then
    SAVE_FILE=$(echo $COUNTRY_NAME | tr -d ' ')
    
    $IP_TABLES -N $SAVE_FILE 2> /dev/null
        if [ $? -eq 1 ] ; then
            necho "The dSutil rule for $COUNTRY_NAME exists, please remove first."
            exit 1
        fi
    
    zcat GeoIPCountryCSV.zip | grep -iw "$COUNTRY_NAME" | cut -d "," -f1,2 | sed 's/,/-/g' | tr -d '"' > $SAVE_FILE
    if [ -f $SAVE_FILE ] ; then
        if [ $(cat $SAVE_FILE | wc -l) -eq 0 ] ; then
            log "Error: no geoIP list built, is this correct: $COUNTRY_NAME"
        else
            log "Completed building geoIP list for $COUNTRY_NAME total records $(cat $COUNTRY_NAME | wc -l)"
            #/sbin/iptables -A savefile -j LOG
            echo -en "\e[1;31mdSutil:\033[0m working, please wait."
            for i in `cat $SAVE_FILE`; do
              $IP_TABLES -A $SAVE_FILE -s 0/0 -d 0/0 -m iprange --src-range $i -j DROP
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
            show_status
        fi
    fi
else
    # Disable Action... Flush the chain...
	SAVE_FILE=$(echo $COUNTRY_NAME | tr -d ' ')
    if [ -f $SAVE_FILE ] ; then
        $IP_TABLES -F $SAVE_FILE
        # Lets delete the rules.
        for rulenum in `$IP_TABLES -L INPUT --line-numbers | grep -i $SAVE_FILE | awk '{print $1}' | sed '1!G;h;$!d'` ; do
            $IP_TABLES -D INPUT $rulenum
        done
        for rulenum in `$IP_TABLES -L FORWARD --line-numbers | grep -i $SAVE_FILE | awk '{print $1}' | sed '1!G;h;$!d'` ; do
           $IP_TABLES -D FORWARD $rulenum
        done
        $IP_TABLES -X $SAVE_FILE
        if [ $? -eq 0 ] ; then
            necho "successfully deleted rule [$COUNTRY_NAME]"
            rm -f $SAVE_FILE
        fi
    else
        necho "The dSutil rule for $COUNTRY_NAME does not exist, please add first."
    fi
fi
}

while getopts "hc:a:sv" opts
do
case $opts in
    h)
        usage
        exit 1
        ;;
    c)
        COUNTRY_NAME=$OPTARG
        ;;
    a)
        ACTION=$OPTARG
        ;;
    s)
        show_status
        ;;
    v)
        # Enable verbose methods
        VERBOSE=true
        ;;
    ?)
        usage
        exit
        ;;
esac
done

# Nothing passed...
if [ -z $COUNTRY_NAME ] ; then usage ; exit 1 ; fi
if [ -z $ACTION ] ; then usage ; exit 1 ; fi

if [ -d data ] ; then
    cd data ; if [ $? -ne 0 ] ; then log "error changing directories" ; fi
else
    mkdir -p data
fi

iptables_method
        
