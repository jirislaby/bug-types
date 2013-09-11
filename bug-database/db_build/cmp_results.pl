#!/usr/bin/perl -w
use strict;
use Helper;
use DBI;
use Term::ANSIColor;

die "wrong commandline. should be $0 source.db" if @ARGV < 1;

my $db = shift @ARGV;
my $error_type = 7;

my $hlp = Helper->new($db) || die "cannot create helper";
my $dbh = $hlp->get_dbh;
my $q = $dbh->prepare("SELECT count(id) cid FROM error WHERE marking > 0 AND " .
		"error_type = ?") || die 'cannot prepare';
$q->execute($error_type) || die 'cannot execute';
my @row = $q->fetchrow_array;
die 'no count?' unless @row;
my $all = $row[0];

$q = $dbh->prepare("SELECT marking FROM error WHERE error_type = ? AND " .
		"loc_file = ? AND loc_line = ?");

my $fp = 0;
my $bugs = 0;

sub check_in_db($$) {
	my ($file, $line) = @_;

	$q->execute($error_type, $file, $line);
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
	die unless /^(.+)\x00([0-9]+)$/;
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
