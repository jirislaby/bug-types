#!/usr/bin/perl -w
use strict;
use XML::XPath;
use DBI;

my $tool_name = "Stanse";
my $tool_ver = "2";

my $dest_proj = "Linux Kernel";
my $error_type = "XXX";
my $user = "jirislaby";

die "wrong commandline. should be $0 dest.db src.xml [string to crop from " .
	"paths]" if @ARGV < 2;

my $out = $ARGV[0];
my $in = $ARGV[1];
my $crop = @ARGV > 2 ? $ARGV[2] : "";

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
my $proj_id = ${$data->fetchrow_hashref}{id};

$data = $dbh->prepare("SELECT id FROM error_type WHERE name = ?") ||
	die "cannot fetch error type ID";
$data->execute($error_type) || die "cannot fetch error type ID";
my $error_type_id = ${$data->fetchrow_hashref}{id};

$data = $dbh->prepare("SELECT id FROM user WHERE login = ?") ||
	die "cannot fetch user ID";
$data->execute($user) || die "cannot fetch user ID";
my $user_id = ${$data->fetchrow_hashref}{id};

$data = $dbh->prepare("INSERT INTO tool(name, version, description) " .
		"VALUES (?, ?, ?)") ||
                die "cannot INSERT tool: " . DBI::errstr;
my $ret = $data->execute($tool_name, $tool_ver, "Crawls web and searches for " .
		"reported errors.");
unless (defined $ret) {
	print "XX=", $dbh->err, "\n";
#	foreach my $key (keys %{$dbh->err}) {
#		print "K  $key: $$dbh->err{$key}\n";
#	}
}
#die "cannot INSERT tool: " . DBI::errstr if ($err && $dbh->err != );

$data = $dbh->prepare("SELECT id FROM tool WHERE name = ? AND version = ?") ||
	die "cannot fetch tool ID";
$data->execute($tool_name, $tool_ver) || die "cannot fetch tool ID";
my $tool_id = ${$data->fetchrow_hashref}{id};

print "$dest_proj: $proj_id\n";
print "$error_type: $error_type_id\n";
print "$user: $user_id\n";
print "tool ID: $tool_id\n";

my $data = $dbh->prepare("INSERT INTO errors(checker, importance, fp_bug, " .
		"error, file, line, locations, errorXML) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

my $croplen = length $crop;
my $xp1 = XML::XPath->new();

my $errors = $xp->findnodes("/database/errors/error");

foreach my $error ($errors->get_nodelist) {
	my ($loc) = $error->findnodes("traces/trace[1]/locations/location[last()]");
	my $loc_count = $error->findvalue("count(traces/trace[1]/locations/location)");
	my $unit = $loc->findvalue("unit");
	if (substr($unit, 0, $croplen) eq $crop) {
		$unit = substr($unit, $croplen);
	}
	my $fp_bug = 0;
	$fp_bug++ if ($xp1->exists("real-bug", $error));
	$fp_bug-- if ($xp1->exists("false-positive", $error));
	$data->execute($error->findvalue("checker_name"),
			$error->findvalue("importance"),
			$fp_bug,
			$error->findvalue("short_desc"),
			$unit, $loc->findvalue("line"),
			$loc_count,
			XML::XPath::XMLParser::as_string($error));
}

$data->finish;

$dbh->commit;

$dbh->disconnect;

0;
