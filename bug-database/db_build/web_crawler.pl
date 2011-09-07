#!/usr/bin/perl -w
use strict;
use HTML::Parser;
use HTTP::Request;
use LWP::UserAgent;
use DBI;

my $tool_name = "Web Crawler";
my $tool_ver = "0.1";

my $dest_proj = "Linux Kernel";
my $error_type = "BUG/WARNING";
my $user = "jirislaby";

die "wrong commandline. should be $0 dest.db URLs..." if @ARGV < 2;

my $out = shift @ARGV;

if (!-e $out) {
	print "'$out' doesn't exist!\n";
	exit 1;
}

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

$data = $dbh->prepare("INSERT INTO error(user, error_type, project, " .
		"project_version, loc_file, loc_line, url) " .
		"VALUES (?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my $data1 = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
		"VALUES (?, ?)") ||
		die "cannot prepare INSERT: " . DBI::errstr;

my $parsetext = 0;
my $glob_url;
my $found;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

sub start($) {
	my $tagname = shift;
	return if ($tagname ne "pre");
	$parsetext = 1;
}

sub end($) {
	my $tagname = shift;
	return if ($tagname ne "pre");
	$parsetext = 0;
}

my $part1 = qr/(?:WARNING:|kernel\s+BUG)\s+at\s+(\S+)\s?:([0-9]+)!?/;
my $pid_line = qr/Pid:\s+[0-9]+,\s+comm:\s+.{1,20}\s+(?:Not\s+tainted|Tainted:\s+[A-Z ]+)\s+\(?([0-9.-]+\S+)\s+#/;

sub text($) {
	return unless $parsetext;
	my $text = shift;
	return unless $text =~ /$part1.*$pid_line/s;
	my $src = $1;
	my $line = $2;
	my $ver = $3;
	unless ($src =~ s|^/usr/src/packages/BUILD/(?:kernel-[a-z]+-[0-9.]+/linux-[0-9.]+/)?||) {
		print "\twarning: no src pattern in '$src'\n";
	}
	$found = 1;
	print "\tsss: $ver $src:$line from $glob_url\n";

	$data->execute($user_id, $error_type_id, $proj_id, $ver, $src, $line,
			$glob_url) ||
		die "cannot INSERT: " . DBI::errstr;
	my $error_id = $dbh->last_insert_id(undef, undef, undef, undef);
	$data1->execute($tool_id, $error_id) ||
		die "cannot INSERT: " . DBI::errstr;
}

my $arg = 0;

open FAILED, ">failed.urls";

foreach my $url (@ARGV) {
	$glob_url = $url;
	$arg++;
	print "Fetching $url\n";
	my $response = $ua->simple_request(HTTP::Request->new(GET => $url));
	if (!$response->is_success) {
		print "\tCannot fetch '$url': ", $response->status_line, "\n";
		print FAILED "$url FETCH ", $response->status_line, "\n";
		next;
	}
	print "\tParsing HTML\n";
	$found = 0;
	my $p = HTML::Parser->new(api_version => 3,
			handlers => {
				start => [\&start, "tagname"],
				text => [\&text, "text"],
				end => [\&end, "tagname"],
			});
	$p->unbroken_text(1);
	$p->parse($response->content);
	$p->eof;
	if (!$found) {
		print FAILED "$url PARSE nothing found\n";
		print "\tNothing found at '$url'. The file stored as 'arg$arg'.\n";
		open F, ">arg$arg";
		print F $response->content;
		close F;
		open F, ">arg$arg.url";
		print F "$url\n";
		close F;
	}
}

close FAILED;

$dbh->commit;

$dbh->disconnect;

0;
