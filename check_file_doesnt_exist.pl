#! /usr/bin/perl -w

# check_file_age.pl Copyright (C) 2003 Steven Grimm <koreth-nagios@midwinter.com>
#
# Checks a file's size and modification time to make sure it's not empty
# and that it's sufficiently recent.
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA

use strict;
use English;
use Getopt::Long;
use File::stat;
use vars qw($PROGNAME);
use lib "/usr/lib/nagios/plugins";
use utils qw (%ERRORS &print_revision &support);

sub print_help ();
sub print_usage ();

my ($opt_f, $opt_h, $opt_V);
my ($result, $message, $age, $size, $st);

$PROGNAME="check_file_doesnt_exist";

$opt_f = "";

Getopt::Long::Configure('bundling');
GetOptions(
	"V"   => \$opt_V, "version"	=> \$opt_V,
	"h"   => \$opt_h, "help"	=> \$opt_h,
	"f=s" => \$opt_f, "file"	=> \$opt_f);

if ($opt_V) {
	print_revision($PROGNAME, '1.4.15');
	exit $ERRORS{'OK'};
}

if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

$opt_f = shift unless ($opt_f);

if (! $opt_f) {
	print "FILE_EXISTS UNKNOWN: No file specified\n";
	exit $ERRORS{'UNKNOWN'};
}

# Check that file exists (can be directory or link)
unless (-e $opt_f) {
	exit $ERRORS{'OK'};
} else {
	print 'FILE_EXISTS CRITICAL: File does exist '.$opt_f."\n";
	exit $ERRORS{'CRITICAL'};
}

