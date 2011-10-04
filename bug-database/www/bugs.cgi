#!/usr/bin/perl -w
use strict;
use CGI ':standard';
use DBI;

my $cg=new CGI;
$cg->default_dtd('-//W3C//DTD XHTML 1.0 Strict//EN',
                'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd');
print $cg->header(-charset=>"UTF-8", -expires=>"1h");
print $cg->start_html(-dtd=>"yes", -lang=>"cs", -title=>"Bug Database",
	-style=>{'src'=>'style.css'},-encoding=>"UTF-8");

my $dbh = DBI->connect("dbi:SQLite:dbname=database.db","","") ||
	die "connect to db error: " . DBI::errstr;
my $data;

my $where;
my @where_param;
my $title;

if (defined $cg->param('all') && $cg->param('all') == 1) {
	$title = "All Bugs";
	$where = "" . "WHERE error.project_version == ?";
	@where_param = ("2.6.28");
} elsif (defined $cg->param('tool')) {
	my $tool = $cg->param('tool');
	$data = $dbh->prepare("SELECT name FROM tool WHERE id == ?") ||
		die "cannot SELECT tool: " . DBI::errstr;
	$data->execute($tool) || die "cannot SELECT tool: " . DBI::errstr;
	$_ = $data->fetchrow_hashref;
	$title = $_ ? "Bugs Found by $$_{name}" : "Bugs Found";
	$where = "WHERE error.id IN (SELECT error_id FROM error_tool_rel " .
		"WHERE tool_id == ?)" . " AND error.project_version == ?";
	@where_param = ($tool, "2.6.28");
} elsif (defined $cg->param('proj')) {
	my $proj = $cg->param('proj');
	$data = $dbh->prepare("SELECT name FROM project WHERE id == ?") ||
		die "cannot SELECT project: " . DBI::errstr;
	$data->execute($proj) || die "cannot SELECT project: " . DBI::errstr;
	$_ = $data->fetchrow_hashref;
	$title = $_ ? "Bugs Found in $$_{name}" : "Bugs Found";
	$where = "WHERE error.project == ?" . " AND error.project_version == ?";
	@where_param = ($proj, "2.6.28");
} elsif (defined $cg->param('type')) {
	my $type = $cg->param('type');
	$data = $dbh->prepare("SELECT name FROM error_type WHERE id == ?") ||
		die "cannot SELECT error type: " . DBI::errstr;
	$data->execute($type) || die "cannot SELECT error type: " . DBI::errstr;
	$_ = $data->fetchrow_hashref;
	$title = $_ ? "Bugs of Type $$_{name}" : "Bugs Found";
	$where = "WHERE error.error_type == ?" .
		" AND error.project_version == ?";
	@where_param = ($type, "2.6.28");
} else {
	print $cg->h2('Invalid query'), "\n";
	goto end;
}

print $cg->h1($title), "\n";
print qq(<div><a href="index.cgi">Back</a></div>\n);

$data = $dbh->prepare("SELECT COUNT(id) cid FROM error $where") ||
	die "cannot SELECT errors: " . DBI::errstr;
$data->execute(@where_param) || die "cannot SELECT errors: " . DBI::errstr;
$_ = $data->fetchrow_hashref;
print $cg->h2("$$_{cid} Errors Found"), "\n";

$data = $dbh->prepare("SELECT error.id id, error_type.name error_type, " .
	"error_type.CWE_error CWE_error, error_subtype, error.url url, " .
	"project.name project, project.url project_url, project_version, " .
	"loc_file, loc_line, marking, user.name user, login, timestamp_enter " .
	"FROM error " .
	"INNER JOIN project ON error.project = project.id " .
	"INNER JOIN error_type ON error.error_type = error_type.id " .
	"INNER JOIN user ON error.user = user.id " .
	"$where ORDER BY error_type, id") ||
	die "cannot SELECT errors: " . DBI::errstr;
$data->execute(@where_param) || die "cannot SELECT errors: " . DBI::errstr;

my $counter = 0;

while ($_ = $data->fetchrow_hashref) {
	$counter++;
#	foreach my $x (keys %$_) {
#		print "$x -> $$_{$x}<br/>\n";
#	}
	my $url = $$_{url};
	print qq(<div><span style="font-weight: bold;">Error $counter</span> (id $$_{id})</div>\n);
	print qq(<div style="margin-left: 1em;">\n);
	print qq(<div><b>Type:</b> );
	print qq(<a href="http://cwe.mitre.org/data/definitions/$$_{CWE_error}.html">) if (defined $$_{CWE_error});
	print qq($$_{error_type});
	print qq(</a>) if (defined $$_{CWE_error});
	print qq(</div>\n);
	print qq(<div><b>Subtype:</b> $$_{error_subtype}</div>\n)
		if ($$_{error_subtype});
	print qq(<div><b>Project:</b> );
	print qq(<a href="$$_{project_url}">) if ($$_{project_url});
	print qq($$_{project});
	print qq(</a>) if ($$_{project_url});
	print qq(</div>\n);
	print qq(<div><b>Project Version:</b> $$_{project_version}</div>\n)
		if ($$_{project_version});
	print qq(<div><b>File:</b> $$_{loc_file}</div>\n);
	print qq(<div><b>Line:</b> $$_{loc_line}</div>\n);
	print qq|<div><b>Marking:</b> $$_{marking} (-100: 100% | .
		qq|false-positive, 0: neutral, 100: 100% real error)</div>\n|
		if (defined $$_{marking});
	print qq(<div><b>URL:</b> <a href="$url">$url</a></div>\n)
		if (defined $url);
	print qq(<div><b>Added by:</b> $$_{user} ($$_{login})</div>\n);
	print qq(<div><b>Entry Created:</b> $$_{timestamp_enter}</div>\n);
	my $foundby = $dbh->prepare("SELECT COUNT(tool_id) cnt " .
		"FROM error_tool_rel WHERE error_id == ?") ||
		die "cannot SELECT tools: " . DBI::errstr;
	$foundby->execute($$_{id}) ||
		die "cannot SELECT tools: " . DBI::errstr;
	my $cnt = ${$foundby->fetchrow_hashref}{cnt};
	print qq(<div><b>Found by $cnt tools), $cnt ? ":" : "",
		qq(</b></div>\n);
	if ($cnt) {
		print qq(<div style="margin-left: 1em;">\n);
		$foundby = $dbh->prepare("SELECT * FROM tool WHERE id IN " .
			"(SELECT tool_id FROM error_tool_rel WHERE error_id == ?)") ||
			die "cannot SELECT tools: " . DBI::errstr;
		$foundby->execute($$_{id}) ||
			die "cannot SELECT tools: " . DBI::errstr;
		while (my $tool = $foundby->fetchrow_hashref) {
			print qq(<div>);
			print qq(<a href="$$tool{url}">) if ($$tool{url});
			print qq($$tool{name});
			print qq(</a>) if ($$tool{url});
			print qq( $$tool{version}) if ($$tool{version});
			print qq(</div>\n);
		}
		print qq(</div>\n);
	}
	print qq(</div>\n);
}

$dbh->disconnect;

end:
print $cg->end_html, "\n";

0;
