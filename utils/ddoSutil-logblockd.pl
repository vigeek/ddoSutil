#!/user/bin/perl -w

use Fcntl qw(:flock);
  open(SELF,"<",$0) or die "Cannot open $0 - $!";
  flock(SELF, LOCK_EX|LOCK_NB) or die "LogblockD - Already Running";

use strict;

## Webserver type
## 1 = Apache
## 2 = NginX (Coming soon)
my $WEBSERVER_ENGINE="1"

## Log location.
## Point this to your webservers access_log.
my $ACCESS_LOG="/var/log/httpd/access_log"

my $reg_ex=""

if ($USE_LOGGING==1) {
	use Log::Log4perl;
	
	my $log_conf = q(
   		log4perl.rootLogger              = DEBUG, LOG1
   		log4perl.appender.LOG1           = Log::Log4perl::Appender::File
   		log4perl.appender.LOG1.filename  = /var/log/logblockd.log
   		log4perl.appender.LOG1.mode      = append
   		log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
   		log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
	);
	Log::Log4perl::init(\$log_conf);  
	my $logger = Log::Log4perl->get_logger();
}

open(my $log, "tail -n0 --follow=name $ACCESS_LOG |");
  while (my $line = <$log>) 
  { 
  	if ($line =~ m/$reg_ex/){
  		# Setup regex pattern based on string.
  	}


  }