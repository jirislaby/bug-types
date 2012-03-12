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
my $error_type_cov = "LOCK";
my $error_type =
#	"Double Lock";
	"Leaving function in locked state";

die "wrong commandline. should be $0 dest.db src.txt" if @ARGV < 2;

my $out = $ARGV[0];
my $in = $ARGV[1];

open(INPUT, "<", $in) || die "cannot open '$in' for reading";

my $hlp = Helper->new($out) || die "helper failed to open db!";
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

sub find_dup($$$) {
	my $dbh = shift;
	my $unit = shift;
	my $loc = shift;
	my $data = $dbh->prepare("SELECT error.id cid, loc_file, loc_line, " .
			"error_tool_rel.tool_id tool " .
			"FROM error, error_tool_rel " .
			"WHERE error.id == error_tool_rel.error_id AND " .
			"tool != ? AND " .
			"error_type = ? AND " .
			"project = ? AND " .
			"project_version = ? AND loc_file = ? AND " .
			"loc_line = ?") ||
		die "cannot prepare SELECT: $dbh->errstr";
	$data->execute($tool_id, $error_type_id, $proj_id, "2.6.28", $unit,
			$loc);
	print "$unit $loc\n";
	my $dup_id = undef;
	while ($_ = $data->fetchrow_hashref) {
		print "  DUP: id=$$_{cid} line=$$_{loc_line} tool=$$_{tool}\n";
		$dup_id = $$_{cid};
	}
	return $dup_id;
}

my $state = 0;
my @errors = ();
my @errors_rel = ();
my %errors = ();

$/ = "\n\n";

my $unit_line = qr/([^:]+):([0-9]+):/;

while (<INPUT>) {
	chomp;
	die "invalid input" if (!/^Error: ([^\n]*):\n(.*)\n?$/s);
	my $error = $1;
	my $entry = $2;
	next if ($error ne $error_type_cov);
	my @lines = split /\n/, $entry;

	my $loc;
	my $unit;
	if ($entry =~ /^$unit_line double_lock: .* twice\.$/m) {
		$loc = $2;
		$unit = $1;
		next if ($error_type ne "Double Lock");
	} elsif ($lines[-1] =~ /^$unit_line missing_unlock: Returning.*"\.$/) {
		$loc = $2;
		$unit = $1;
#		my $lock = $1;
		next if ($error_type ne "Leaving function in locked state");

#		my $i;
#		for ($i = $#lines; $i >= 0; $i--) {
#			if (index($lines[$i], qq(locks "$lock")) >= 0) {
#				last;
#			}
#			if (index($lines[$i], qq(transfer: Assigning: "$lock" = )) >= 0 &&
#					/" = "([^"]+)";/) {
#				$lock = $1;
#			}
#		}
#		die "bad input ($lock):\n$entry\n" if ($i < 0 ||
#			$lines[$i] !~ /^([^:]+):([0-9]+):/);
	} else {
		print "GAK: $lines[-1]\n";
		next;
	}

	if (!$errors{"$unit\0$loc"}) {
		my $dup_id = find_dup $dbh, $unit, $loc;
		if (defined $dup_id) {
			push @errors_rel, $dup_id;
		} else {
			push @errors, [ $unit, $loc ];
		}
		$errors{"$unit\0$loc"} = 1;
	}
}

close INPUT;

my $data = $dbh->prepare("INSERT INTO error_full(user, error_type, project, " .
		"project_version, loc_file, loc_line, marking) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

foreach (@errors) {
	my $unit = $$_[0];
	my $loc = $$_[1];
	print "$unit $loc\n";
	$data->execute($user_id, $error_type_id, $proj_id, $dest_proj_ver,
			$unit, $loc, 0) ||
		die "cannot INSERT: $dbh->errstr";
	my $error_id = $dbh->last_insert_id(undef, undef, undef, undef);
	push @errors_rel, $error_id;
}

$data = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
		"VALUES (?, ?)") ||
		die "cannot prepare INSERT: $dbh->errstr";

foreach (@errors_rel) {
	$data->execute($tool_id, $_) ||
		die "cannot INSERT: $dbh->errstr";
}

$dbh->commit;

0;
