#!/bin/env bash
# ddoSutil installer script

eecho () {
    
    echo -e "\e[1;31mdSutil:\033[0m $1"
}

necho () {
    echo -en "\e[1;31mdSutil:\033[0m $1"
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
        mkdir -p logs
        mkdir -p docs
        if [[ -d "$INSTALL_DIR/ddoSutil/data" && -d "$INSTALL_DIR/ddoSutil/logs" && -d "$INSTALL_DIR/ddoSutil/docs" ]] ; then
            eecho "Successfully created data, docs and log directories"
            # Download the scripts....
        
            wget -q -O docs/README http://www.viGeek.net/projects/ddoSutil/README
            wget -q -O dSutil-harden.sh http://www.viGeek.net/projects/ddoSutil/dSutil-harden.sh
                if [ ! -f dSutil-harden.sh ] ; then eecho "Failed to download dSutil-harden.sh, moving on..." ; fi
            wget -q -O dSutil-gpblock.sh http://www.viGeek.net/projects/ddoSutil/dSutil-gpblock.sh
                if [ ! -f dSutil-gpblock.sh ] ; then eecho "Failed to download dSutil-gpblock.sh, moving on..." ; fi
            wget -q -O dSutil-geoip.sh http://www.viGeek.net/projects/ddoSutil/dSutil-geoip.sh
                if [ ! -f dSutil-geoip.sh ] ; then eecho "Failed to download dSutil-geoip.sh, moving on..." ; fi
            wget -q -O dSutil-deflate.py http://www.viGeek.net/projects/ddoSutil/dSutil-deflate.py
                if [ ! -f dSutil-deflate.py ] ; then eecho "Failed to download dSutil-deflate.py, moving on..." ; fi
            
            eecho "Installation completed to: $INSTALL_DIR/ddoSutil"
        else
            eecho "Failed to create required directories, exiting."
            exit 1
        fi
    fi
fi
