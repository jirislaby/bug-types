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

print $cg->p(qq(This is a database of known bugs and false positives in real ) .
		qq(software projects. So far, we support only the <b>Linux ) .
		qq(Kernel 2.6.28</b> and selected kinds of bugs. The main ) .
		qq(purpose of the database is to support research and ) .
		qq(development in the area of bug-finding techniques and ) .
		qq(tools by providing data for their automatic evaluation.)),
      "\n",
      $cg->p(qq(We are currently focused on filling the database. We plan to ) .
		qq(support more software projects and more kinds of bug ) .
		qq(later. This web interface of the database is also an ) .
		qq(interim one.)), "\n",
      $cg->p(qq(If you have any questions or suggestions, please feel free ) .
		qq(to contact us.)), "\n",
      $cg->p($cg->a({href => 'mailto:slaby@fi.muni.cz'}, "Jiri Slaby") . ",",
		$cg->a({href => 'mailto:strejcek@fi.muni.cz'}, "Jan Strejcek"),
		"and",
		$cg->a({href => 'mailto:trtik@fi.muni.cz'}, "Marek Trtik"));

print $cg->h2('Errors in the Database'), "\n";
$data = $dbh->prepare("SELECT error_type.*, count(error.id) cid " .
	"FROM error_type, error WHERE error.error_type==error_type.id AND " .
	"error.project_version == ? " .
	"GROUP BY error_type.name ORDER BY error_type.name") ||
	die "cannot SELECT error types: " . DBI::errstr;
$data->execute("2.6.28") || die "cannot SELECT error types: " . DBI::errstr;
print qq(<table border="1" cellspacing="0">\n);
print qq(<tr style="background-color: #cccccc;">\n);
print qq( <td><b>Category</b><br/><small>Description</small></td>\n);
print qq( <td><b><a href="http://www.cwe.org">CWE</a> ID</b></td>\n);
print qq( <td><b>Count</b></td>\n);
print qq(</tr>\n);
my $cnt = 0;
while ($_ = $data->fetchrow_hashref) {
	$cnt += $$_{cid};
	print qq(<tr>\n),
		qq( <td><a href="bugs.cgi?type=$$_{id}">$$_{name}</a><br/>\n),
		qq( <small>$$_{short_description}</small></td>\n),
		qq( <td align="center">);
	if (defined $$_{CWE_error}) {
		print qq(<a href="http://cwe.mitre.org/data/definitions/) .
			qq($$_{CWE_error}.html">CWE-$$_{CWE_error}</a>)
	} else {
		print qq(N/A);
	}
	print qq(</td>\n),
		qq( <td align="center">$$_{cid}</td>\n),
		qq(</tr>\n);
}
print qq(<tr style="background-color: #cccccc;">\n),
	qq( <td colspan="2"><a href="bugs.cgi?all=1">All Bugs</a></td>\n),
	qq( <td align="center">$cnt</td>\n),
	qq(</tr>\n),
	qq(</table>);

print $cg->h2('Tools Used'), "\n";
$data = $dbh->prepare("SELECT * FROM tool ORDER BY name, version") ||
	die "cannot SELECT tools: " . DBI::errstr;
$data->execute || die "cannot SELECT tools: " . DBI::errstr;
while ($_ = $data->fetchrow_hashref) {
	my $url = $$_{url};
#	print qq(<div style="font-weight: bold;"><a href="bugs.cgi?tool=$$_{id}">$$_{name}</a></div>\n);
	print qq(<div style="font-weight: bold;">);
	print qq(<a href="$url">) if ($url);
	print qq($$_{name});
	print qq( $$_{version}) if ($$_{version});
	print qq(</a>) if ($url);
	print qq(</div>\n);
	print qq(<div style="margin-left: 1em;">$$_{description}</div>\n)
		if ($$_{description});
}

#print $cg->h2('Checked Projects'), "\n";
#$data = $dbh->prepare("SELECT * FROM project ORDER BY name") ||
#	die "cannot SELECT projects: " . DBI::errstr;
#$data->execute || die "cannot SELECT projects: " . DBI::errstr;
#while ($_ = $data->fetchrow_hashref) {
#	my $url = $$_{url};
#	print qq(<div style="font-weight: bold;"><a href="bugs.cgi?proj=$$_{id}">$$_{name}</a></div>\n);
#	print qq(<div style="margin-left: 1em;">\n);
#	print qq(<div><b>URL:</b> <a href="$url">$url</a></div>\n) if ($url);
#	print qq(<div><b>Description:</b> $$_{description}</div>\n)
#		if ($$_{description});
#	print qq(</div>\n);
#}

$dbh->disconnect;

end:
print $cg->end_html, "\n";

0;
