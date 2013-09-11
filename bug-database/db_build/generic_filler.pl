#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use Helper;
use DBI;

my %opts;

my $usage = "Usage: $0 <parameters>\n" .
	"\tParameters are:\n" .
	"\t-d database.db    Path to database\n" .
	"\t[-D table_name]   Name of the errors table, defaults to 'error'\n" .
	"\t-e error_type     Name of the error type in the error_type table\n" .
	"\t[-E err_subtype]  Error subtype in the error table (defaults to empty)\n" .
	"\t[-n]              Dry run (no insertions)'\n" .
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

if (!getopts("d:D:e:E:np:P:t:T:", \%opts)) {
	die $usage;
}

my $database = $opts{'d'};
my $table_name = $opts{'D'} ? $opts{'D'} : "error";
my $error_type = $opts{'e'};
my $error_subtype = $opts{'E'};
my $dry_run = $opts{'n'};
my $dest_proj = $opts{'p'} ? $opts{'p'} : "Linux Kernel";
my $dest_proj_ver = $opts{'P'} ? $opts{'P'} : "2.6.28";
my $tool_name = $opts{'t'};
my $tool_ver = $opts{'T'};
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

$hlp->error_init($tool_id, $error_type_id, $proj_id, "2.6.28");

while (<>) {
	chomp;
	die "invalid input" if (!/^(.+)\x00([0-9]+)\x00(-?[01])$/);
	my $unit = $1;
	my $loc = $2;
	my $marking = $3;
	print "$unit $loc\n";
	$hlp->error_add($unit, $loc, $marking);
}

if (!defined $dry_run) {
	$hlp->error_push($user_id, $error_subtype);
}

1;
