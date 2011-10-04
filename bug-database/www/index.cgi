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

print $cg->h1('The Bug Database'), "\n";

print qq(<div>You can select a category which you want to see found bugs ),
	qq(from. This can be done by clicking on the tool name, error type, ),
	qq(project and so on.</div>\n);

print $cg->h2('Errors Found'), "\n";
$data = $dbh->prepare("SELECT error_type.*, count(error.id) cid " .
	"FROM error_type, error WHERE error.error_type==error_type.id AND " .
	"error.project_version == ? " .
	"GROUP BY error_type.name ORDER BY error_type.name") ||
	die "cannot SELECT error types: " . DBI::errstr;
$data->execute("2.6.28") || die "cannot SELECT error types: " . DBI::errstr;
print qq(<table>\n);
print qq(<tr>\n);
print qq( <td><b>Category</b></td>\n);
print qq( <td><b>Count</b></td>\n);
print qq( <td><b>CWE ID</b></td>\n);
print qq( <td><b>Description</b></td>\n);
print qq(</tr>\n);
print qq(<tr>\n);
print qq( <td><a href="bugs.cgi?all=1">All Bugs</a></td>\n);
print qq( <td>N/A</td>\n);
print qq( <td>N/A</td>\n);
print qq( <td>All bugs in our database</td>\n);
print qq(</tr>\n);
while ($_ = $data->fetchrow_hashref) {
	print qq(<tr>\n);
	print qq( <td><a href="bugs.cgi?type=$$_{id}">$$_{name}</a></td>\n);
	print qq( <td>$$_{cid}</td>\n);
	print qq( <td>);
	if (defined $$_{CWE_error}) {
		print qq(<a href="http://cwe.mitre.org/data/definitions/) .
			qq($$_{CWE_error}.html">$$_{CWE_error}</a>)
	} else {
		print qq(N/A);
	}
	print qq(</td>\n);
	print qq( <td>$$_{short_description}</td>\n);
	print qq(</tr>\n);
}
print qq(</table>);

print $cg->h2('Tools Used'), "\n";
$data = $dbh->prepare("SELECT * FROM tool ORDER BY name") ||
	die "cannot SELECT tools: " . DBI::errstr;
$data->execute || die "cannot SELECT tools: " . DBI::errstr;
while ($_ = $data->fetchrow_hashref) {
	my $url = $$_{url};
	print qq(<div style="font-weight: bold;"><a href="bugs.cgi?tool=$$_{id}">$$_{name}</a></div>\n);
	print qq(<div style="margin-left: 1em;">\n);
	print qq(<div><b>Version:</b> $$_{version}</div>\n) if ($$_{version});
	print qq(<div><b>URL:</b> <a href="$url">$url</a></div>\n) if ($url);
	print qq(<div><b>Description:</b> $$_{description}</div>\n)
		if ($$_{description});
	print qq(</div>\n);
}

print $cg->h2('Checked Projects'), "\n";
$data = $dbh->prepare("SELECT * FROM project ORDER BY name") ||
	die "cannot SELECT projects: " . DBI::errstr;
$data->execute || die "cannot SELECT projects: " . DBI::errstr;
while ($_ = $data->fetchrow_hashref) {
	my $url = $$_{url};
	print qq(<div style="font-weight: bold;"><a href="bugs.cgi?proj=$$_{id}">$$_{name}</a></div>\n);
	print qq(<div style="margin-left: 1em;">\n);
	print qq(<div><b>URL:</b> <a href="$url">$url</a></div>\n) if ($url);
	print qq(<div><b>Description:</b> $$_{description}</div>\n)
		if ($$_{description});
	print qq(</div>\n);
}

$dbh->disconnect;

end:
print $cg->end_html, "\n";

0;
