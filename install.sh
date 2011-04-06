#!/bin/bash
# ddoSutil installer script

# Status variable
STATUS="0"

eecho () {
    echo -e "\e[1;31mddoSutil:\033[0m $1"
}

necho () {
    echo -en "\e[1;31mddoSutil:\033[0m $1"
}

# Determine whether RH or DEB based.
	if [ -f /etc/redhat-release ] ; then
		DISTRO="RH"
	elif [ -f /etc/lsb-release ] ; then
		DISTRO="DEB"
	elif [ -f /etc/debian_version ] ; then
		DISTRO="DEB"
	else
		DISTRO="UNK"
		eecho "Linux distribution not directly supported, some functions may not work properly."
	fi
	

necho "Please define your installation directory (default=/opt):"
read INSTALL_DIR
    if [ -z $INSTALL_DIR ] ; then
        eecho "No installation path provided, installing to default /opt/ddoSutil"
        INSTALL_DIR="/opt"    
    fi

# Installation directory exists and is available.    
if [ -d $INSTALL_DIR ] ; then
    if [ -d "$INSTALL_DIR/ddoSutil" ] ; then eecho "ddoSutil already installed to $INSTALL_DIR/ddoSutil, uninstall first" ; exit 1 ; fi
        eecho "Installation path '$INSTALL_DIR' exists beginning installation..."
    cd $INSTALL_DIR
    mkdir -p ddoSutil
    cd ddoSutil
        eecho "Successfully created ddoSutil directory and change paths"
    if [ -d "$INSTALL_DIR/ddoSutil" ] ; then
        
        # Make our directories
        mkdir -p data ; if [ $? -ne 0 ] ; then "Error creating directory data, install failure" ; fi
        mkdir -p conf ; if [ $? -ne 0 ] ; then "Error creating directory data, install failure" ; fi
        mkdir -p data/logs ; if [ $? -ne 0 ] ; then "Error creating directory data, install failure" ; fi
        #if [[ -d '$INSTALL_DIR/ddoSutil/data' && -d '$INSTALL_DIR/ddoSutil/conf' && -d '$INSTALL_DIR/ddoSutil/data/logs' ]] ; then
            eecho "Successfully created data, docs and log directories"
            # Download the scripts....
        
            wget -q http://www.viGeek.net/projects/ddoSutil/README
            wget -q http://www.viGeek.net/projects/ddoSutil/ddoSutil-harden.sh
                if [ ! -r ddoSutil-harden.sh ] ; then STATUS="1" ; eecho "Failed to download ddoSutil-harden.sh, moving on..." ; fi
            wget -q http://www.viGeek.net/projects/ddoSutil/ddoSutil-gpblock.sh
                if [ ! -r ddoSutil-gpblock.sh ] ; then STATUS="1" ; eecho "Failed to download ddoSutil-gpblock.sh, moving on..." ; fi
            wget -q http://www.viGeek.net/projects/ddoSutil/ddoSutil-geoip.sh
                if [ ! -r ddoSutil-geoip.sh ] ; then STATUS="1" ; eecho "Failed to download ddoSutil-geoip.sh, moving on..." ; fi
            wget -q http://www.viGeek.net/projects/ddoSutil/ddoSutil-deflate.py
                if [ ! -r ddoSutil-deflate.py ] ; then STATUS="1" ; eecho "Failed to download ddoSutil-deflate.py, moving on..." ; fi
            wget -q http://www.viGeek.net/projects/ddoSutil/ddoSutil-nstat.sh
                if [ ! -r ddoSutil-nstat.sh ] ; then STATUS="1" ; eecho "Failed to download ddoSutil-nstat.sh, moving on..." ; fi

	    # Download the configuration files.
		cd conf ; if [ $? -ne 0 ] ; then echo "Error on install" ; exit 1 ;fi
            wget -q http://www.viGeek.net/projects/ddoSutil/conf/geoip.conf
                if [ ! -r geoip.conf ] ; then STATUS="1" ; eecho "Failed to download geoip.conf, moving on..." ; fi
            wget -q http://www.viGeek.net/projects/ddoSutil/conf/gpblock.conf
                if [ ! -r gpblock.conf ] ; then STATUS="1" ; eecho "Failed to download gpblock.conf, moving on..." ; fi
            wget -q http://www.viGeek.net/projects/ddoSutil/conf/harden.conf
                if [ ! -r harden.conf ] ; then STATUS="1" ; eecho "Failed to download harden.conf, moving on..." ; fi
            wget -q http://www.viGeek.net/projects/ddoSutil/conf/distro.conf
                if [ ! -r distro.conf ] ; then 
					eecho "Failed to download distro.conf, moving on..."
					echo -e "\nDISTRO='$DISTRO'" >> distro.conf
					STATUS="1" 
				else
					echo -e "\nDISTRO='$DISTRO'" >> distro.conf
				fi
		if [ $STATUS -eq "1" ] ; then
			echo -e ""
			eecho "ERRORS found during installation, ddoSutil may not function properly"
		fi
            eecho "Installation completed to: $INSTALL_DIR/ddoSutil"
        else
            eecho "Failed to create required directories, exiting."
            exit 1
        fi
    fi
#fi

