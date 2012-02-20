#!/usr/bin/perl -w
use strict;
use Helper;
use XML::XPath;
use Getopt::Std;
use DBI;

my $tool_name = "Stanse";
my $tool_ver = "1.2";

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

my $hlp = Helper->new($out);
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
print "note: $note\n" if (defined $note);

my $data = $dbh->prepare("INSERT INTO error(user, error_type, project, " .
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

0;
