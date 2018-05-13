#!/usr/bin/perl -w
################
# nagios: +epn
#
# check_bgp_ipv6 - nagios plugin 
#
# Copyright (C) 2013 Guillaume PÃ©court
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Report bugs to:  guillaume.pecourt@gmail.com
#
# Requirements : 
#	- perl -MCPAN -e 'install Net::OpenSSH'
#	- perl -MCPAN -e 'install Regexp::IPv6' 
#	- libnet-telnet-cisco-perl
#	- libio-pty-perl
#
# Tested on :
#	- Cisco ASR 1000 Series Routers (ASR1001 - ASR1002-F)
#
################


use warnings;
use lib "/usr/lib/nagios/plugins"  ;
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use vars qw($PROGNAME);

use Switch;
use Net::Telnet::Cisco;
use Net::OpenSSH;
use Regexp::IPv6 qw($IPv6_re);

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
        print ("ERROR: Plugin took too long to complete (alarm)\n");
        exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

$PROGNAME = "check_bgp_ipv6.pl";
sub rntrim($);
sub print_help ();
sub print_usage ();

my ($opt_h,$opt_V);
my $connection = "telnet";
my $login = "yourlogin";
my $passwd = "yourpassword";
my ($hostname,$status,$as,$up);

use Getopt::Long;
&Getopt::Long::config('bundling');
GetOptions(
	"V"   => \$opt_V,       "version"    => \$opt_V,
        "h"   => \$opt_h,       "help"       => \$opt_h,
        "C=s" => \$connection,  "connection=s" => \$connection,
        "H=s" => \$hostname,    "hostname=s" => \$hostname,
        "L=s" => \$login,       "login=s" => \$login,
        "P=s" => \$passwd,      "password=s" => \$passwd,
);

# -h & --help print help
if ($opt_h) { print_help(); exit $ERRORS{'OK'}; }
# -V & --version print version
if ($opt_V) { print_revision($PROGNAME,'$Revision: 1.0 $ '); exit $ERRORS{'OK'}; }
# Invalid hostname print usage
if (!utils::is_hostname($hostname)) { print_usage(); exit $ERRORS{'UNKNOWN'}; }


my $state = 'OK';
$cmd = "show ip bgp ipv6 unicast summary";
$error = "";

switch ($connection) {
	case "ssh" {
	    	$session = Net::OpenSSH -> new($hostname, user => $login, password => $passwd, master_stdout_discard => 1, master_stderr_discard => 1, timeout => 7, 
			master_opts => [-o => "StrictHostKeyChecking=no"]);
		$session->error and $state = "WARNING" and print "$state : Unable to open ssh connection\n" and exit $ERRORS{$state};
		@output = $session->capture($cmd);
	}   
        case "telnet" {
		$session = Net::Telnet::Cisco -> new(Host => $hostname, Timeout => 7, Errmode => 'return');
		$session->login($login,$passwd);
		if ($session->errmsg =~ /timed-out/) { $state = "WARNING"; print $state . " : " . $session->errmsg . "\n"; exit $ERRORS{$state}; }
		$session->cmd('terminal length 0');
		@output = $session->cmd($cmd);
		$error = $session->last_prompt;
		$session->close;
        }      
	else {
		print_usage(); exit $ERRORS{'UNKNOWN'};	
	}
}

my $failed = "Status retrieval failed";
my $msg = '';
my $msgC = '';
my $msgW = '';
my $msgA = '';
my $count = 0;
my $countTotal = 0;

if (!@output) {
	$state = "WARNING";
	print "$state : $failed. No result from connection \n";
	exit $ERRORS{$state};
}

#system("echo 'line: @output' >> /tmp/nagios_debug.txt");

my $nextline;
my $j;
# Look for errors in output
for ( my ($i, $lastline) = (0, '');
	$i <= $#output;
        $lastline = $output[$i++] ) {
        	# This may have to be a pattern match instead.
        	if ( ( substr $output[$i], 0, 1 ) eq '%' ) {
        		if ( $output[$i] =~ /'\^' marker/ ) { # Typo & bad arg errors
                		chomp $lastline;
                		$msg = $failed."\n\n Last command and router error:\n (". $error . $cmd . ")\n". $lastline . $output[$i];
                		splice @output, $i - 1, 3;
                		$state = "CRITICAL";
        		}
        		else { # All other errors.
        			chomp $output[$i];
                		$msg = $failed."\n\n Last command and router error:\n (". $error . $cmd . ")\n". $output[$i];
                		splice @output, $i, 2;
                		$state = "CRITICAL";
        		}
			if ($state ne "OK") {print "$state : $msg\n"; exit $ERRORS{$state}; }
        		last;
		}
		
		if ($output[$i] =~ /invalid/) { 
			$state = "CRITICAL"; 
			print "$state : Error Command -> $output[$i]\n"; 
			exit $ERRORS{$state};
		}   
		if ($output[$i] =~ /$IPv6_re/) {
			$j=$i+1;
			$nextline=$output[$j];
			@info = split (/ +/,$nextline);
			$as = $info[2];
			$up = $info[8];
			$status = $info[9];
			if ($info[10]) { $status = $status." ".$info[10]; }
			switch ($status) {
				case /Admin/ { 
                                        $msgA = $msgA . rntrim("SHUTDOWN ADMIN : $output[$i] (AS$as) state is $status.") . "\n";
                                }
				case /Idle/ {
                                	$state = "CRITICAL";
        				$msgC = $msgC . rntrim("$state : $output[$i] (AS$as) state is $status.") . "\n";
                       		}
				case /^0/ {
					$state = "WARNING";
                                        $msgW = $msgW . rntrim("$state : $output[$i] (AS$as) state is established. Established: $up. But Prefix Received: 0") . "\n";
						
				}
				else { $count++ }
			}
			$countTotal++;
		}	
}

$msg = $msgC.$msgW.$msgA;
my $msgall = "($count/$countTotal) BGP Peer Are Established.\n";
if ($state eq "OK") {print "$state : $msgall$msgA"; exit $ERRORS{$state}; }

switch ($msg) {
	case /CRITICAL/ {
		$state = "CRITICAL";
		print $msgall.$msg; exit $ERRORS{$state};
	}
	case /WARNING/ {
		$state = "WARNING";
		print $msgall.$msg; exit $ERRORS{$state};
	}
}

sub rntrim($)
{
	my $string = shift;
	$string =~ s/\r|\n//g;
	return $string;
}

sub print_help() {
        print_revision($PROGNAME,'$Revision: 1.0 $ ');
        print "Copyright (c) 2013 PÃ©court Guillaume\n";
        print "This program is licensed under the terms of the\n";
        print "GNU General Public License\n(check source code for details)\n";
        print "\n";
        printf "Check BGP peer IPv6 status via SSH or Telnet on Cisco IOS.\n";
        print "\n";
        print_usage();
        print "\n";
        print " -H (--hostname)     Hostname to query - (required)\n";
        print " -C (--connection)   Telnet or SSH - (default: $connection)\n";
        print " -L (--login)        Username - (optional: can be set in the script)\n";
        print " -P (--password)     Password - (optional: can be set in the script)\n";
	print " -V (--version)      Plugin version\n";
        print " -h (--help)         usage help\n";
        print "\n";
        support();
}

sub print_usage() {
        print "Usage: \n";
        print "  $PROGNAME -H <HOSTNAME> -C <connection> -L <login> -P <password>\n";
        print "  $PROGNAME [-h | --help]\n";
}

