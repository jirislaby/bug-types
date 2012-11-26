#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use Helper;
use DBI;

my %opts;

my $usage = "Usage: $0 <parameters>\n" .
	"\tParameters are:\n" .
	"\t-d database.db    Path to database\n" .
	"\t-D table_name     Name of the errors table, defaults to 'error'\n" .
	"\t-e error_type     Name of the error type in the error_type table\n" .
	"\t[-p proj_name]    Defaults to 'Linux kernel'\n" .
	"\t[-P proj_ver]     Defaults to '2.6.28'\n" .
	"\t[-t tool_name]    Unspecified means no tool\n" .
	"\t[-T tool_ver]\n\n" .
	"\tThe input is expected in the following format:\n" .
	"\t\tfile\\0line\\0marking\\n\n" .
	"\tMarking is a number, one of:\n" .
	"\t\t-1 ... false-positive\n" .
	"\t\t 0 ... unclassified\n" .
	"\t\t 1 ... real error\n";

if (!getopts("a:d:e:p:P:t:T:", \%opts)) {
	die $usage;
}

my $database = $opts{'d'};
my $table_name = $opts{'D'} ? $opts{'D'} : "error";
my $error_type = $opts{'e'};
my $tool_name = $opts{'t'};
my $tool_ver = $opts{'T'};
my $dest_proj = $opts{'p'} ? $opts{'p'} : "Linux Kernel";
my $dest_proj_ver = $opts{'P'} ? $opts{'P'} : "2.6.28";
my $user = "jirislaby";

if (!defined $database || !defined $error_type) {
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
my $tool_id = undef;
if (defined $tool_name) {
	$tool_id = $hlp->get_tool($tool_name, $tool_ver) ||
		die "cannot fetch tool ID for '$tool_name'";
}

print "$dest_proj: $proj_id\n";
print "$error_type: $error_type_id\n";
print "$user: $user_id\n";
print "tool ID: $tool_id\n" if (defined $tool_id);

my $data = $dbh->prepare("INSERT INTO $table_name(user, error_type, project, " .
		"project_version, loc_file, loc_line, marking) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my @errors_rel = ();

while (<>) {
	chomp;
	die "invalid input" if (!/^(.+)\x00([0-9]+)\x00(-?[01])$/);
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

if (defined $tool_id) {
	$data = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
			"VALUES (?, ?)") ||
			die "cannot prepare INSERT: " . $dbh->errstr;

	foreach (@errors_rel) {
		$data->execute($tool_id, $_) ||
			die "cannot INSERT: " . $dbh->errstr;
	}
}

$dbh->commit;

1;
