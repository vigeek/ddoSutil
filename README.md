## ddoSutil 0.9.2

**ddoSutil** is a project aimed at dealing with *ddos* attacks on Linux systems.  Since many *ddos* attacks differ in complexity, the objective is to provide a variety of utilities to deal with different types of attacks.

Created to be as portable as possible without requirements, developed mostly in bash (with a until or two in Perl).  Tested on [CentOS](http://centos.org) and [Debian](http://debian.org) should function with no or minimal effort on most Linux distributions.

**Actively maintained** please submit issues, feedback and suggestions; or e-mail russ -at- vigeek.net

### Installation

Either clone or download as zip from github and extract to desired directory.  Set the scripts as executable (e.g:  chmod +x ddosutil.sh).

#### Usage

In the root of the directory is *ddosutil.sh* this applies a blanket approach on the system by building a firewall, block lists, TCP stack adjustments, queue changes, connection limiting and so fourth.  To use *ddosutil.sh* simply edit the configuration file *ddosutil.conf* then run *./ddosutil.sh* the results will be output.

**Utilities**

Also included are 6 utilities, each with a different purpose.  Each utility has a configuration file in **utils/conf/** or they may be ran supplying *-h* for help and general usage (e.g. ./ddosutil.geoip.sh -h)


* ddoSutil-geoip.sh
	* 	Block specific countries completely.
	* 	Countries can be blocked quickly with just a single command.
	*   Many configurable options.
* ddoSutil-gpblock.sh
	* Some *ddos* attacks make GET/PUT requests to invalid URLs.  This will…
	* Build block lists based on requests made to apache and actively drop the offending IPs.
	* Configureable, ability to control how many requests per offending IP to resource, allowed.
* ddoSutil-nstat.sh
	* 	Shows information helpful to determine the help type of attack.
* ddoSutil-mySQLrecover.pl
	* Some DDOS attacks can overload a database with expensive queries.
	* This tool allows you to actively kill slow expensive queries.  Alleviating DB load.
	* Configurable, ability to control after how many seconds should a query be killed.
* ddoSutil-harden.sh
	* *no longer maintained* most replaced and functions improved in *ddosutil.sh*
	* Implements general sysctl tweaks to help deal with attacks.
* ddoSutil-logblockd.pl [In progress]
	* Daemon automatically monitors apache/nginx logs.
	* Actively blocks IP addresses making specific requests (.e.g.: invalid URLs)	
* ddoSutil-deflated.pl [In progress]
	* Daemon automatically monitors active connections.
	* Actively blocks IP addresses with high connection counts.
	* Actively blocks IP addresses making frequent connections.
 
##### License

GPL v3

###### Author 
Russ Thompson ( Russ -at - vigeek.net)
