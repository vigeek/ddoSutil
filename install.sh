#!/bin/env bash
# ddoSutil installer script

eecho () {
    
    echo -e "\e[1;31mddoSutil:\033[0m $1"
}

necho () {
    echo -en "\e[1;31mddoSutil:\033[0m $1"
}

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
        mkdir -p data
        mkdir -p conf
        mkdir -p data/logs
        if [[ -d "$INSTALL_DIR/ddoSutil/data" && -d "$INSTALL_DIR/ddoSutil/conf" && -d "$INSTALL_DIR/ddoSutil/data/logs" ]] ; then
            eecho "Successfully created data, docs and log directories"
            # Download the scripts....
        
            wget -q -O README http://www.viGeek.net/projects/ddoSutil/README
            wget -q -O ddoSutil-harden.sh http://www.viGeek.net/projects/ddoSutil/ddoSutil-harden.sh
                if [ ! -f ddoSutil-harden.sh ] ; then eecho "Failed to download ddoSutil-harden.sh, moving on..." ; fi
            wget -q -O ddoSutil-gpblock.sh http://www.viGeek.net/projects/ddoSutil/ddoSutil-gpblock.sh
                if [ ! -f ddoSutil-gpblock.sh ] ; then eecho "Failed to download ddoSutil-gpblock.sh, moving on..." ; fi
            wget -q -O ddoSutil-geoip.sh http://www.viGeek.net/projects/ddoSutil/ddoSutil-geoip.sh
                if [ ! -f ddoSutil-geoip.sh ] ; then eecho "Failed to download ddoSutil-geoip.sh, moving on..." ; fi
            wget -q -O ddoSutil-deflate.py http://www.viGeek.net/projects/ddoSutil/ddoSutil-deflate.py
                if [ ! -f ddoSutil-deflate.py ] ; then eecho "Failed to download ddoSutil-deflate.py, moving on..." ; fi
            
            eecho "Installation completed to: $INSTALL_DIR/ddoSutil"
        else
            eecho "Failed to create required directories, exiting."
            exit 1
        fi
    fi
fi
