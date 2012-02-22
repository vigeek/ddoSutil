#!/user/bin/perl -w
## ddoSutil-deflate.pl
## Author:  Russ Thompson <russ@vigeek.net>

use Fcntl qw(:flock);
  open(SELF,"<",$0) or die "Cannot open $0 - $!";
  flock(SELF, LOCK_EX|LOCK_NB) or die "Deflate - Already Running";

use strict;

my $config_file = "./conf/deflated.conf";
  open CONFIG, "$config_file" or die "Program stopping, couldn't open the configuration file '$config_file'.\n";
my $config = join "", <CONFIG>;
  close CONFIG;
  eval $config;
    die "Could not read the configuration file '$config_file'" if $@;

if ($USE_LOGGING==1) {

        use Log::Log4perl;

        my $log_conf = q(
                log4perl.rootLogger              = DEBUG, LOG1
                log4perl.appender.LOG1           = Log::Log4perl::Appender::File
                log4perl.appender.LOG1.filename  = /var/log/deflated.log
                log4perl.appender.LOG1.mode	 = append
                log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
                log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
        );
	Log::Log4perl::init(\$log_conf);
        my $logger = Log::Log4perl->get_logger();
}

