#!/usr/bin/perl -w
use strict;
use CGI ':standard';
use DBI;

sub hyperlink_if_nonzero($$) {
	my $cnt = shift;
	my $contents = shift;
	return $cnt unless ($cnt);
	$contents =~ s/&/&amp;/g;
	return qq(<a href="$contents">$cnt</a>);
}

my $cg=new CGI;
$cg->default_dtd('-//W3C//DTD XHTML 1.0 Strict//EN',
                'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd');
print $cg->header(-charset=>"UTF-8", -expires=>"1h");
print $cg->start_html(-dtd=>"yes", -lang=>"cs", -title=>"ClabureDB",
	-style=>{'src'=>'style.css'},-encoding=>"UTF-8");

my $dbh = DBI->connect("dbi:SQLite:dbname=database.db","","") ||
	die "connect to db error: " . DBI::errstr;
my $data;

print $cg->h1({style => 'background: #d0d0f0;'},
		$cg->span({style => 'color:#001010;'}, 'Clabure') .
		$cg->span({style => 'color:#e03040;'}, 'DB') .
		qq|: Classified Bug-Reports Database|), "\n";

print qq|<div style="background: #f0f0f0; padding: 0px 10px 0px 10px; margin-bottom: 2ex;">\n|;
print $cg->p(qq|This is a database of known bugs and false positives in real | .
		qq|software projects. So far, we support only the <b>Linux | .
		qq|Kernel 2.6.28</b> (| .
		$cg->a({href => 'kernel-vanilla-2.6.28-167.fc16.src.rpm'},
			'source RPM package') .
		qq|) and selected kinds of bugs. The main | .
		qq(purpose of the database is to support research and ) .
		qq(development in the area of bug-finding techniques and ) .
		qq(tools by providing data for their automatic evaluation.)),
      "\n",
      $cg->p(qq(We are currently focused on filling the database. We plan to ) .
		qq(support more software projects and more kinds of bug ) .
		qq(later. This web interface of the database is also an ) .
		qq(interim one.)), "\n",
      $cg->p(qq|There is also a page with | .
		$cg->a({href => 'doc.html'}, 'documentation') .
		qq|. If you have any | .
		qq|further questions or suggestions, please feel free | .
		qq(to ) . $cg->a({href => 'mailto:claburedb@fi.muni.cz'},
					qq(contact us)) .
		qq(.)), "\n";

print qq|</div>\n|;

print $cg->h2('Errors in the Database'), "\n";

print $cg->start_form, $cg->p($cg->b("Project: ") .
      $cg->popup_menu('db', ['Linux kernel 2.6.28'])),
      $cg->endform, "\n";

$data = $dbh->prepare("SELECT error_type.*, count(error.id) cid, " .
	"(SELECT count(error.id) FROM error WHERE error.marking < 0 AND " .
		"error.error_type == error_type.id) cfp, " .
	"(SELECT count(error.id) FROM error WHERE (error.marking == 0 OR " .
			"error.marking IS NULL) AND " .
		"error.error_type == error_type.id) cun, " .
	"(SELECT count(error.id) FROM error WHERE error.marking > 0 AND " .
		"error.error_type == error_type.id) crb " .
	"FROM error_type, error WHERE error.error_type==error_type.id " .
	"GROUP BY error_type.name ORDER BY error_type.name") ||
	die "cannot SELECT error types: " . DBI::errstr;
$data->execute() ||
	die "cannot SELECT error types: " . DBI::errstr;
print qq(<table border="1" cellspacing="0">\n);
print qq(<tr style="background-color: #cccccc;">\n);
print qq( <td><b><span style="color: #0066CC;">Category</span></b><br/>\n),
      qq(  <small>Description</small></td>\n);
print qq( <td><b><a href="http://www.cwe.org">CWE</a> ID</b></td>\n);
print qq( <td><b>Real Errors</b></td>\n);
print qq( <td><b>False Positives</b></td>\n);
print qq( <td><b>Unclassified</b></td>\n);
print qq( <td><b>Overall Count</b></td>\n);
print qq(</tr>\n);
my $cnt = 0;
my $cnt_rb = 0;
my $cnt_fp = 0;
my $cnt_un = 0;
while ($_ = $data->fetchrow_hashref) {
	$cnt += $$_{cid};
	$cnt_rb += $$_{crb};
	$cnt_fp += $$_{cfp};
	$cnt_un += $$_{cun};
	print qq(<tr>\n),
		qq( <td><span style="color: #0066CC;">$$_{name}</span><br/>\n),
		qq( <small>$$_{short_description}</small></td>\n),
		qq( <td align="center">);
	if (defined $$_{CWE_error}) {
		print qq(<a href="http://cwe.mitre.org/data/definitions/) .
			qq($$_{CWE_error}.html">CWE-$$_{CWE_error}</a>)
	} else {
		print qq(N/A);
	}
	print qq(</td>\n),
	      qq( <td align="center">),
	      hyperlink_if_nonzero($$_{crb}, "bugs.cgi?type=$$_{id}&marking=1"),
	      qq(</td>\n),
	      qq( <td align="center">),
	      hyperlink_if_nonzero($$_{cfp}, "bugs.cgi?type=$$_{id}&marking=-1"),
	      qq(</td>\n),
	      qq( <td align="center">),
	      hyperlink_if_nonzero($$_{cun}, "bugs.cgi?type=$$_{id}&marking=0"),
	      qq(</td>\n),
	      qq( <td align="center">),
	      hyperlink_if_nonzero($$_{cid}, "bugs.cgi?type=$$_{id}"),
	      qq(</td>\n),
	      qq(</tr>\n);
}
print qq(<tr style="background-color: #cccccc;">\n),
      qq( <td colspan="2"><b><span style="color: #0066CC;">All Bugs</span></b></td>\n),
      qq( <td align="center">),
      hyperlink_if_nonzero($cnt_rb, "bugs.cgi?all=1&marking=1"),
      qq(</td>\n),
      qq( <td align="center">),
      hyperlink_if_nonzero($cnt_fp, "bugs.cgi?all=1&marking=-1"),
      qq(</td>\n),
      qq( <td align="center">),
      hyperlink_if_nonzero($cnt_un, "bugs.cgi?all=1&marking=0"),
      qq(</td>\n),
      qq( <td align="center">),
      hyperlink_if_nonzero($cnt, "bugs.cgi?all=1"),
      qq(</td>\n),
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
