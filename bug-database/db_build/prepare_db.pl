#!/usr/bin/perl -w
use strict;
use DBI;
use Crypt::PasswdMD5 qw(unix_md5_crypt);

die "wrong commandline. should be $0 dest.db URLs..." if @ARGV < 1;

my $out = shift @ARGV;

if (-e $out) {
	my $reply = "N";
	do {
		print "'$out' already exists, overwrite? [y/N] ";
		$reply = uc(<STDIN>);
		chomp($reply);
	} while ($reply ne "Y" && $reply ne "N" && $reply ne "");
	exit 1 if ($reply ne "Y");
	unlink $out;
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$out","","", {AutoCommit => 0}) ||
	die "connect to db error: " . DBI::errstr;

$dbh->do("PRAGMA foreign_keys = ON;");

$dbh->do("CREATE TABLE user(id INTEGER PRIMARY KEY, name VARCHAR(255), " .
		"affilitation VARCHAR(255), login VARCHAR(255) UNIQUE, " .
		"password VARCHAR(128))") ||
		die "cannot CREATE user: " . DBI::errstr;
$dbh->do("CREATE TABLE error_type(id INTEGER PRIMARY KEY, " .
		"name VARCHAR(255) UNIQUE, " .
		"short_description VARCHAR(255) NOT NULL, " .
		"description STRING)") ||
		die "cannot CREATE err_type: " . DBI::errstr;
$dbh->do("CREATE TABLE project(id INTEGER PRIMARY KEY, " .
		"name VARCHAR(255) UNIQUE, url STRING, description STRING)") ||
		die "cannot CREATE project: " . DBI::errstr;
$dbh->do("CREATE TABLE error(id INTEGER PRIMARY KEY, user INT NOT NULL, " .
		"error_type INT NOT NULL, error_subtype STRING, " .
		"project INT NOT NULL, project_version VARCHAR(32), " .
		"note STRING, " .
		"loc_file STRING NOT NULL, loc_line INT NOT NULL, " .
		"url STRING, " .
		"timestamp_enter DATETIME DEFAULT CURRENT_TIMESTAMP, " .
		"timestamp_lastmod DATETIME, " .
		"timestamp_found DATETIME, " .
		"marking INT, " .
		"UNIQUE(error_type, error_subtype, project, project_version, " .
			"loc_file, loc_line)" .
		"FOREIGN KEY(user) REFERENCES user(id), " .
		"FOREIGN KEY(error_type) REFERENCES error_type(id), " .
		"FOREIGN KEY(project) REFERENCES project(id))") ||
		die "cannot CREATE error: " . DBI::errstr;
$dbh->do("CREATE TABLE error_trace(id INTEGER PRIMARY KEY, error_id INT, " .
		"trace STRING NOT NULL, " .
		"FOREIGN KEY(error_id) REFERENCES error(id))") ||
		die "cannot CREATE err_trace: " . DBI::errstr;
$dbh->do("CREATE TABLE tool(id INTEGER PRIMARY KEY, " .
		"name VARCHAR(255) NOT NULL, version VARCHAR(32), " .
		"url STRING, description STRING, UNIQUE(name, version))") ||
		die "cannot CREATE tool: " . DBI::errstr;
$dbh->do("CREATE TABLE error_tool_rel(tool_id INT NOT NULL, " .
		"error_id INT NOT NULL, " .
		"UNIQUE(tool_id, error_id), " .
		"FOREIGN KEY(tool_id) REFERENCES tool(id), " .
		"FOREIGN KEY(error_id) REFERENCES error(id))") ||
		die "cannot CREATE error_tool_rel: " . DBI::errstr;

my $data;

$data = $dbh->prepare("INSERT INTO user(name, affilitation, login, password) " .
		"VALUES (?, ?, ?, ?)") ||
		die "cannot INSERT user: " . DBI::errstr;
$data->execute("Jiri Slaby", "FI MU", "jirislaby", unix_md5_crypt("ble")) ||
		die "cannot INSERT user: " . DBI::errstr;

$data = $dbh->prepare("INSERT INTO tool(name, version, url, description) " .
		"VALUES (?, ?, ?, ?)") ||
		die "cannot INSERT tool: " . DBI::errstr;
$data->execute("Stanse", "2", "http://stanse.fi.muni.cz/",
		"Taking a firm stanse on bugs") ||
		die "cannot INSERT tool: " . DBI::errstr;
$data->execute("Soberity", "100012211.2434.3", undef,
		"Lorem Ipsum is simply dummy text of the printing and" .
		"typesetting industry. Lorem Ipsum has been the industry's " .
		"standard dummy text ever since the 1500s, when an unknown " .
		"printer took a galley of type and scrambled it to make a " .
		"type specimen book. It has survived not only five " .
		"centuries, but also the leap into electronic typesetting, " .
		"remaining essentially unchanged. It was popularised in the " .
		"1960s with the release of Letraset sheets containing Lorem " .
		"Ipsum passages, and more recently with desktop publishing " .
		"software like Aldus PageMaker including versions of Lorem " .
		"Ipsum.") ||
		die "cannot INSERT tool: " . DBI::errstr;

$data = $dbh->prepare("INSERT INTO project(name, url, description) " .
		"VALUES (?, ?, ?)") ||
		die "cannot INSERT project: " . DBI::errstr;
$data->execute("Linux Kernel", "http://www.kernel.org/", undef) ||
		die "cannot INSERT project: " . DBI::errstr;

$data = $dbh->prepare("INSERT INTO error_type(name, short_description, " .
		"description) VALUES (?, ?, ?)") ||
		die "cannot INSERT error_type: " . DBI::errstr;
$data->execute("BUG/WARNING", "An unsatisfied assertion in the code", undef) ||
		die "cannot INSERT error_type: " . DBI::errstr;
$data->execute("div by zero", "The code tries to divide by zero",
		"There is a division in the code and the divisor is zero.") ||
		die "cannot INSERT error_type: " . DBI::errstr;

$data = $dbh->prepare("INSERT INTO error(user, error_type, error_subtype, " .
		"project, project_version, note, loc_file, loc_line, url, " .
		"marking) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot INSERT error: " . DBI::errstr;
$data->execute(1, 1, undef, 1, undef, undef, "/abc", "100", undef, undef) ||
		die "cannot INSERT error: " . DBI::errstr;
$data->execute(1, 2, "Subtype XYZ", 1, "2.6.28", "Note this crap", "/abc",
		"100", "http://www.fi.muni.cz", 1) ||
		die "cannot INSERT error: " . DBI::errstr;

$data = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
		"VALUES (1, last_insert_rowid())") ||
		die "cannot INSERT error-tool rel: " . DBI::errstr;
$data->execute ||
		die "cannot INSERT error-tool rel: " . DBI::errstr;

$dbh->commit;

$dbh->disconnect;

0;
