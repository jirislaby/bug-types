#!/usr/bin/perl -w -I /home/latest/repos/bug-types/bug-database/db_build/
use strict;
use Helper;
use DBI;
use Term::ANSIColor;

die "wrong commandline. should be $0 source.db" if @ARGV < 1;

my $db = shift @ARGV;

my $hlp = Helper->new($db) || die "cannot create helper";
my $dbh = $hlp->get_dbh;
my $q = $dbh->prepare("SELECT count(id) cid FROM error WHERE marking > 0 AND " .
		"loc_file LIKE ? OR loc_file LIKE ?") || die 'cannot prepare';
$q->execute('ldv-regression/%', 'ddv-machzwd/%') || die 'cannot execute';
my @row = $q->fetchrow_array;
die 'no count?' unless @row;
my $all = $row[0];

$q = $dbh->prepare("SELECT marking FROM error WHERE loc_file = ? AND " .
		"loc_line = ?");

my $fp = 0;
my $bugs = 0;

sub check_in_db($$) {
	my ($file, $line) = @_;

	$q->execute($file, $line);
	if (my $h = $q->fetchrow_hashref) {
		my $mark = $$h{marking};
		if ($mark > 0) {
			$bugs++;
		} elsif ($mark < 0) {
			$fp++;
		}
	}
}

while (<>) {
	chomp;
	die unless /^(.*):(.*)$/;
	check_in_db($1, $2);
}

$q->finish;
$dbh->commit;

print colored ['bold blue'], "BUGS IN PROJECT: $all\n";
print colored ['bold green'], "REPORTS: ", $bugs + $fp, "\n";
print "  BUGS: $bugs\n";
print "  FALSE POSITIVES: $fp\n";
print colored ['bold green'], "MISSED/FALSE NEGATIVES: ",
      $all - $bugs, "\n";

0;
