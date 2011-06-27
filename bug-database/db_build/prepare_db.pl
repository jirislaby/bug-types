#!/usr/bin/perl -w
use strict;
use Authen::Passphrase::BlowfishCrypt;
use DBI;

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

$dbh->do("CREATE TABLE user(id INTEGER PRIMARY KEY, name VARCHAR(255), " .
		"affilitation VARCHAR(255), login VARCHAR(255) UNIQUE, " .
		"password VARCHAR(128))") ||
		die "cannot CREATE user: " . DBI::errstr;
$dbh->do("CREATE TABLE error_type(id INTEGER PRIMARY KEY, " .
		"name VARCHAR(255) UNIQUE, short_description VARCHAR(255), " .
		"description STRING)") ||
		die "cannot CREATE err_type: " . DBI::errstr;
$dbh->do("CREATE TABLE project(id INTEGER PRIMARY KEY, " .
		"name VARCHAR(255) UNIQUE, description STRING)") ||
		die "cannot CREATE project: " . DBI::errstr;
$dbh->do("CREATE TABLE error(id INTEGER PRIMARY KEY, user INT, " .
		"error_type INT, error_subtype STRING, project INT, " .
		"project_version VARCHAR(32), note STRING, loc_file STRING, " .
		"loc_line INT UNSIGNED, url STRING, " .
		"timestamp_enter DATETIME CURRENT_TIMESTAMP, " .
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
$dbh->do("CREATE TABLE error_tool_rel(tool_id INT, error_id INT, " .
		"FOREIGN KEY(tool_id) REFERENCES tool(id), " .
		"FOREIGN KEY(error_id) REFERENCES error(id))") ||
		die "cannot CREATE error_tool_rel: " . DBI::errstr;

$dbh->do("INSERT INTO user(name, affilitation, login, password) VALUES " .
		"('Jiri Slaby', 'FI MU', 'jirislaby', " .
		"'Taking a firm stanse on bugs')");

$dbh->do("INSERT INTO tool(name, version, url, description) VALUES " .
		"('Stanse', '2', 'http://stanse.fi.muni.cz/', " .
		"'Taking a firm stanse on bugs')");

$dbh->commit;

$dbh->disconnect;

0;
