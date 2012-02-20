#!/usr/bin/perl -w
use strict;
use Helper;
use XML::XPath;
use DBI;

my $tool_name = "Undetermined 1";
my $tool_ver = undef;

my $dest_proj = "Linux Kernel";
my $dest_proj_ver = "2.6.28";
my $user = "jirislaby";

die "wrong commandline. should be $0 dest.db src.txt" if @ARGV < 2;

my $out = $ARGV[0];
my $in = $ARGV[1];

my $hlp = Helper->new($out) || die "helper failed to open db!";
my $dbh = $hlp->get_dbh;

my $proj_id = $hlp->get_prj($dest_proj) ||
	die "cannot fetch project ID for '$dest_proj'";
my $user_id = $hlp->get_user($user) ||
	die "cannot fetch user ID for '$user'";
my $tool_id = $hlp->get_tool($tool_name, $tool_ver) ||
	die "cannot fetch tool ID for '$tool_name'";

print "$dest_proj: $proj_id\n";
#print "$error_type: $error_type_id\n";
print "$user: $user_id\n";
print "tool ID: $tool_id\n";

my $data = $dbh->prepare("INSERT INTO error(user, error_type, project, " .
		"project_version, loc_file, loc_line, marking) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my $data1 = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
		"VALUES (?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

while (<>) {
	my $short_desc = "";

	my $fp_bug = 0;

	my $loc = 0;
	my $unit = "";
#	$data->execute($user_id, $error_type_id, $proj_id, $dest_proj_ver,
#			$unit, $loc->findvalue("line"), $fp_bug * 100) ||
#		die "cannot INSERT: " . DBI::errstr;
#	my $error_id = $dbh->last_insert_id(undef, undef, undef, undef);
#	$data1->execute($tool_id, $error_id) ||
#		die "cannot INSERT: " . DBI::errstr;
}

$dbh->commit;

0;
