#!/usr/bin/perl -w
use strict;
use XML::XPath;
use DBI;

my $tool_name = "Stanse";
my $tool_ver = "2";

my $dest_proj = "Linux Kernel";
my $dest_proj_ver = "2.6.28";
my $user = "jirislaby";

die "wrong commandline. should be $0 db_error_type stanse_error_type " .
	"dest.db src.xml [string to crop from paths]" if @ARGV < 4;

my $error_type = $ARGV[0];
my $stanse_error_type = $ARGV[1]; # short_desc in XML
my $out = $ARGV[2];
my $in = $ARGV[3];
my $crop = @ARGV > 4 ? $ARGV[4] : "";

if (!-e $out) {
	print "'$out' doesn't exist!\n";
	exit 1;
}

my $xp = XML::XPath->new(filename => "$in") || die "can't open $in";

my $dbh = DBI->connect("dbi:SQLite:dbname=$out","","", {AutoCommit => 0}) ||
	die "connect to db error: " . DBI::errstr;

$dbh->do("PRAGMA foreign_keys = ON;");

my $data = $dbh->prepare("SELECT id FROM project WHERE name = ?") ||
	die "cannot fetch kernel ID";
$data->execute($dest_proj) || die "cannot fetch kernel ID";
my $hash = $data->fetchrow_hashref;
die "project not found in the database" unless (defined $hash);
my $proj_id = ${$hash}{id};

$data = $dbh->prepare("SELECT id FROM error_type WHERE name = ?") ||
	die "cannot fetch error type ID";
$data->execute($error_type) || die "cannot fetch error type ID";
$hash = $data->fetchrow_hashref;
die "error type not found in the database" unless (defined $hash);
my $error_type_id = ${$hash}{id};

$data = $dbh->prepare("SELECT id FROM user WHERE login = ?") ||
	die "cannot fetch user ID";
$data->execute($user) || die "cannot fetch user ID";
$hash = $data->fetchrow_hashref;
die "user not found in the database" unless (defined $hash);
my $user_id = ${$hash}{id};

$data = $dbh->prepare("SELECT id FROM tool WHERE name = ? AND version = ?") ||
	die "cannot fetch tool ID";
$data->execute($tool_name, $tool_ver) || die "cannot fetch tool ID";
$hash = $data->fetchrow_hashref;
die "user not found in the database" unless (defined $hash);
my $tool_id = ${$hash}{id};

print "$dest_proj: $proj_id\n";
print "$error_type: $error_type_id\n";
print "$user: $user_id\n";
print "tool ID: $tool_id\n";

$data = $dbh->prepare("INSERT INTO error(user, error_type, project, " .
		"project_version, loc_file, loc_line, marking) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my $data1 = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
		"VALUES (?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my $croplen = length $crop;
my $xp1 = XML::XPath->new();

my $errors = $xp->findnodes("/database/errors/error");

foreach my $error ($errors->get_nodelist) {
	my $short_desc = $error->findvalue("short_desc");
	next if ($short_desc ne $stanse_error_type);

	my $fp_bug = 0;
	$fp_bug++ if ($xp1->exists("real-bug", $error));
	$fp_bug-- if ($xp1->exists("false-positive", $error));
	next unless ($fp_bug);

	my ($loc) = $error->findnodes("traces/trace[1]/locations/location[last()]");
	my $unit = $loc->findvalue("unit");
	if (substr($unit, 0, $croplen) eq $crop) {
		$unit = substr($unit, $croplen);
	}
	$unit =~ s@/\.tmp_@/@;
	$unit =~ s@\.o\.preproc$@.c@;
	$data->execute($user_id, $error_type_id, $proj_id, $dest_proj_ver,
			$unit, $loc->findvalue("line"), $fp_bug * 100) ||
		die "cannot INSERT: " . DBI::errstr;
	my $error_id = $dbh->last_insert_id(undef, undef, undef, undef);
	$data1->execute($tool_id, $error_id) ||
		die "cannot INSERT: " . DBI::errstr;
}

$dbh->commit;

$dbh->disconnect;

0;
