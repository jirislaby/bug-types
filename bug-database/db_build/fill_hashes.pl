#!/usr/bin/perl -w
use strict;
use Helper;
use DBI;

die "wrong commandline. should be $0 dest.db" if @ARGV < 1;

my $out = shift @ARGV;

my $hlp = Helper->new($out) || die "cannot create helper";
my $dbh = $hlp->get_dbh;

my $data = $dbh->prepare("UPDATE error SET loc_file_hash = ? " .
		"WHERE project = ? AND project_version = ? AND loc_file = ? " .
		"AND loc_file_hash IS NULL") ||
		die "cannot UPDATE error: " . DBI::errstr;

while (<>) {
	chomp;
	die "unknown input: $_" unless (/^(.*);([0-9a-f]{40})$/);
	my ($file, $hash) = ($1, $2);
	$data->execute($hash, 1, "2.6.28", $file) ||
			die "cannot UPDATE error: " . DBI::errstr;
}

$dbh->commit;

1;
