#!/usr/bin/perl -w
use strict;
use XML::XPath;
use Getopt::Std;
use DBI;

my $tool_name = "Stanse";
my $tool_ver = "1";

my $dest_proj = "Linux Kernel";
my $dest_proj_ver = "2.6.28";
my $user = "jirislaby";

my $cmdline_err = "wrong commandline. should be:\n" .
	"$0 db_error_type stanse_error_type dest.db src.xml " .
	"[-c string to crop from paths] [-m conversion file] [-n note]";

die $cmdline_err if (scalar @ARGV < 4);

my $error_type = shift;
my $stanse_error_type = shift; # short_desc in XML
my $out = shift;
my $in = shift;
my %opts;
if (!getopts("c:fm:n:", \%opts) || scalar @ARGV) {
	die $cmdline_err;
}

my $note = $opts{'n'};
my $crop = $opts{'c'};
my $first_loc = $opts{'f'};
my $conv = $opts{'m'};
my %conv_map;

if (!-e $out) {
	print "'$out' doesn't exist!\n";
	exit 1;
}

if (defined $conv) {
	print "Using '$conv' as conv file\n";
	open(CONV, $conv) || die "cannot open $conv";
	while (<CONV>) {
		chomp;
		die "invalid conv file" unless (/^(.+) ([0-9]+) (.+) ([0-9]+)$/);
		$conv_map{"$1\x00$2"} = "$3\x00$4";
	}
	close CONV;
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
die "tool not found in the database" unless (defined $hash);
my $tool_id = ${$hash}{id};

print "$dest_proj: $proj_id\n";
print "$error_type: $error_type_id\n";
print "$user: $user_id\n";
print "tool ID: $tool_id\n";
print "note: $note\n" if (defined $note);

$data = $dbh->prepare("INSERT INTO error(user, error_type, project, " .
		"project_version, loc_file, loc_line, marking, note) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my $data1 = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
		"VALUES (?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my $croplen = defined($crop) ? length($crop) : 0;
my $xp1 = XML::XPath->new();

sub get_loc($) {
	my $error = shift;
	my @loc = $error->findnodes("traces/trace[1]/locations/location");
	return $loc[-1] unless ($first_loc);
	my $pos = 0;
	while ($loc[$pos]->findvalue("description") =~ /^<context>/) {
		$pos++;
	}
	return $loc[$pos];
}

my $errors = $xp->findnodes("/database/errors/error");

foreach my $error ($errors->get_nodelist) {
	my $short_desc = $error->findvalue("short_desc");
	next if ($short_desc ne $stanse_error_type);

	my $fp_bug = 0;
	$fp_bug++ if ($xp1->exists("real-bug", $error));
	$fp_bug-- if ($xp1->exists("false-positive", $error));

	my $loc = get_loc($error);
	my $unit = $loc->findvalue("unit");
	if ($croplen && substr($unit, 0, $croplen) eq $crop) {
		$unit = substr($unit, $croplen);
	}
	$unit =~ s@/\.tmp_@/@;
	$unit =~ s@\.o\.preproc$@.c@;
	my $line = $loc->findvalue("line");
	if (defined $conv) {
		my $entry = $conv_map{"$unit\x00$line"};
		die "no entry for $unit:$line in conv map" if (!defined $entry);
		($unit, $line) = split /\x00/, $entry;
	}
	$data->execute($user_id, $error_type_id, $proj_id, $dest_proj_ver,
			$unit, $line, $fp_bug, $note) ||
		die "cannot INSERT: " . DBI::errstr;
	my $error_id = $dbh->last_insert_id(undef, undef, undef, undef);
	$data1->execute($tool_id, $error_id) ||
		die "cannot INSERT: " . DBI::errstr;
}

$dbh->commit;

$dbh->disconnect;

0;
