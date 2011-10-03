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

print qq(<div>You can select a category which do you want to see found bugs ),
	qq(from. This is done by clicking on the tool name, error type, ),
	qq(project etc. Or you may want to see all bugs we have in our ),
	qq(database. Then use the link below.</div>\n);
print qq(<div style="margin-top: 2ex;"><a href="bugs.cgi?all=1">Show All Bugs</a></div>\n);

print $cg->h2('Tools'), "\n";
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

print $cg->h2('Errors Found'), "\n";
$data = $dbh->prepare("SELECT * FROM error_type ORDER BY name") ||
	die "cannot SELECT error types: " . DBI::errstr;
$data->execute || die "cannot SELECT error types: " . DBI::errstr;
while ($_ = $data->fetchrow_hashref) {
	my $url = $$_{url};
	print qq(<div style="font-weight: bold;"><a href="bugs.cgi?type=$$_{id}">$$_{name}</a></div>\n);
	print qq(<div style="margin-left: 1em;">\n);
	print qq(<div><b>Short Description:</b> $$_{short_description}</div>\n);
	if (defined $$_{CWE_error}) {
		my $url = "http://cwe.mitre.org/data/definitions/$$_{CWE_error}.html";
		print qq(<div><b>CWE URL:</b> <a href="$url">$url</a></div>\n);
	}
	print qq(</div>\n);
}

$dbh->disconnect;

end:
print $cg->end_html, "\n";

0;
