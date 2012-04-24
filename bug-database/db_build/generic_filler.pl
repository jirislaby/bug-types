#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use Helper;
use DBI;

my %opts;

my $usage = "Usage: $0 -d database.db -e error_type -t tool_name [-v tool_ver]";

if (!getopts("d:e:t:v:", \%opts)) {
	die $usage;
}

my $database = $opts{'d'};
my $tool_name = $opts{'t'};
my $tool_ver = $opts{'v'};

my $dest_proj = "Linux Kernel";
my $dest_proj_ver = "2.6.28";
my $user = "jirislaby";
my $error_type = $opts{'e'};

if (!defined $database || !defined $tool_name || !defined $error_type) {
	die $usage;
}

my $hlp = Helper->new($database) || die "helper failed to open db!";
my $dbh = $hlp->get_dbh;

my $proj_id = $hlp->get_prj($dest_proj) ||
	die "cannot fetch project ID for '$dest_proj'";
my $error_type_id = $hlp->get_error($error_type) ||
	die "cannot fetch error ID for '$error_type'";
my $user_id = $hlp->get_user($user) ||
	die "cannot fetch user ID for '$user'";
my $tool_id = $hlp->get_tool($tool_name, $tool_ver) ||
	die "cannot fetch tool ID for '$tool_name'";

print "$dest_proj: $proj_id\n";
print "$error_type: $error_type_id\n";
print "$user: $user_id\n";
print "tool ID: $tool_id\n";

my $data = $dbh->prepare("INSERT INTO error_full(user, error_type, project, " .
		"project_version, loc_file, loc_line, marking) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my @errors_rel = ();

while (<>) {
	chomp;
	die "invalid input" if (!/^([^ ]+) ([0-9]+) (-?[01])$/);
	my $unit = $1;
	my $loc = $2;
	my $marking = $3;
	print "$unit $loc\n";
	$data->execute($user_id, $error_type_id, $proj_id, $dest_proj_ver,
			$unit, $loc, $marking) ||
		die "cannot INSERT: $dbh->errstr";
	my $error_id = $dbh->last_insert_id(undef, undef, undef, undef);
	push @errors_rel, $error_id;
}

$data = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
		"VALUES (?, ?)") ||
		die "cannot prepare INSERT: " . $dbh->errstr;

foreach (@errors_rel) {
	$data->execute($tool_id, $_) ||
		die "cannot INSERT: " . $dbh->errstr;
}

$dbh->commit;

1;
