#!/usr/bin/perl -w
# spe - 10/2006
# russ@viGeek.net - 2009 - (Added kill count, dry run, alert options, adjustable threshold, console and emailing functions)
# ddoSutil-mysqlrecover.pl

use DBI;
use MIME::Lite;

my $config_file = "./conf/mysqlrecover.conf";
open CONFIG, "$config_file" or die "Program stopping, couldn't open the configuration file '$config_file'.\n";
my $config = join "", <CONFIG>;
close CONFIG;
eval $config;
die "Could not read the configuration file '$config_file'" if $@;

# These should be left default
my $sql                   = 'SHOW FULL PROCESSLIST';
my $dbhost                =`/bin/hostname`;
my $count                 = 0;
my $killedAQuery          = 0;

# Set log file
my $file                  = "./data/logs/mysqlrecover.log";

# Open our log
open FILE, ">$file" or die "unable to open $file $!";

while (1) {
        $db_handle = 0;
        while ($db_handle == 0) {
                $db_handle = DBI->connect("dbi:mysql:database=mysql;hostname=127.0.0.1:port=3306;user=".$user.";password=".$password);
                if ($db_handle == 0) {
                        sleep(1);
                }
        }

        $statement = $db_handle->prepare($sql)
            or die "Couldn't prepare query '$sql': $DBI::errstr\n";

        $statement->execute()
            or die "Couldn't execute query '$sql': $DBI::errstr\n";
        while (($row_ref = $statement->fetchrow_hashref()) && ($killedAQuery == 0))
        {
                if ($row_ref->{Command} eq "Query") {
                        if ($row_ref->{Time} >= $definq) {
								if ($dryrun == 0){
									@args = ($mysqladmin, "-u".$user, "-p".$password, "kill", $row_ref->{Id});
									$returnCode = system(@args);
								}
                                # Include console output and kill counts.
                                if($ecout == 1){
									print ("Killing row ID:  $row_ref->{Id}\n");
									$count+=1;
									print("Total killed: $count\n");
                                }
                                $emailMessage = "A slow query as been detected (more than $row_ref->{Time} seconds). SQLkiller will try to kill this request.\nThe query is:\n$row_ref->{Info}\n\n";
								print FILE "A slow query as been detected (more than $row_ref->{Time} seconds). SQLkiller will try to kill this request.\nThe query 
is:\n$row_ref->{Info}\n\n";                
       
                if ($returnCode != 0) {
                                        $emailMessage .= "Result: The SQL request cannot be killed. The problematic request is the first killed successfully\n";
                                }
                                else {
                                        $emailMessage .= "Result: The SQL request has been killed successfully\n";
                                }
                                # Establish and send e-mail
                                if($enote == 1){
                                my $msg = new MIME::Lite
                                        From    =>$emailalertfrom,
                                        To      =>$emailalertto,
                                        Subject =>'[ SQLkiller ] A query has been killed on. '.$dbhost,
                                        Type    =>'TEXT',
                                        Data    =>$emailMessage;
                                $msg -> send;
                                }
                               
                                $killedAQuery = 1;
                        }
                }
        }
        $statement->finish();
        $db_handle->disconnect();
        if ($killedAQuery == 0) {
                sleep(5);
        }
        else {
                $killedAQuery = 0;
                #sleep(1);
        }
}
