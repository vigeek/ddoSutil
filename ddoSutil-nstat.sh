#!/usr/bin/env bash
# ddoSutil-nstat.sh 0.3 russ@vigeek.net
# https://github.com/viGeek/ddoSutil

necho () {
ivar=$2
    if [ -z "$ivar" ] ; then
	ivar="0"
    else
	ivar=$2
    fi

   echo -e "\e[1;31mddoSutil:\033[0m $1 \033[0;32m $ivar \033[0m"
}


necho "statistics report"
echo -e ""
  necho "port [80] connection total:" " $(netstat -n | grep :80 |wc -l)"
  necho "apache memory usage:" "$(ps aux | grep apache | grep -v "grep" | awk '{ s += $6 } END { print s/1024, "Mb"}')"
  necho "apache threads count:" "$(ps -ef | grep apache | grep -v "grep" | wc -l)"
  necho "sytem load averages:" "$(uptime | awk '{print $10,$11,$12}' | sed 's/,/ /g')"
  necho "system uptime:" "$(uptime | awk '{print $3,$4}'  | sed 's/,/ /g')"
  necho "last yum update:" "$(sed -n '/Updated:/h;${;g;p;}' < /var/log/yum.log | awk '{print $1,$2,$3}')"
  necho "authenication failures:" "$(awk '{print}' /var/log/secure* | grep -i 'authentication failure' | wc -l)"
echo -e ""
  necho "connections in SYN state:" "$(netstat -ant | awk '{print $6}' | grep SYN | wc -l)"
  necho "connections in LISTEN state:" "$(netstat -ant | awk '{print $6}' | grep LISTEN | wc -l)"
  necho "connections in ESTABLISHED state:" "$(netstat -ant | awk '{print $6}' | grep ESTABLISHED | wc -l)"
echo -e ""
  necho "connected IP addresses (top 10):" "$(netstat -tunv  | awk '{print $5}' | awk -F':' '{print $1}' | grep ^[0-9] | uniq -c | sort -rn | head -n 10)"
