#!/usr/bin/perl -w
use strict;
use CGI ':standard';
use DBI;

my $cg=new CGI;
$cg->default_dtd('-//W3C//DTD XHTML 1.0 Strict//EN',
                'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd');
print $cg->header(-charset=>"UTF-8", -expires=>"1h");
print $cg->start_html(-dtd=>"yes", -lang=>"cs", -title=>"Bug database",
	-style=>{'src'=>'style.css'},-encoding=>"UTF-8");

my $dbh = DBI->connect("dbi:SQLite:dbname=database.db","","") ||
	die "connect to db error: " . DBI::errstr;

print $cg->h1('Database of bugs found in the Linux Kernel'), "\n";
#print $cg->start_form(-action=>"", -method=>"GET");
#print "<div>", $cg->textfield(-name=>'filter', -size=>20),
#	$cg->submit('Filter files'), "</div>\n";
#print $cg->hidden('db', $datafile), "\n";
#print $cg->end_form, "\n";
#print qq|<p>$count errors (false positives including) found in <strong>$OKfiles{$datafile}</strong> kernel|;
#print qq| for filter '$filter_name'| if (defined $filter_name);
#print qq|:</p>\n|;
#print qq|<div style="font-size: 75%;"><em>The number before pipe is |,
#	qq|importance (the lower the better).</em></div>\n|;
#
#my $errors = $dbh->prepare("SELECT * FROM errors WHERE file LIKE ? ORDER BY checker,importance,error,locations,file,line");
#$errors->execute($filter);
#
#my $checker = "";
#
#while ($_ = $errors->fetchrow_hashref) {
#	print qq(<div style="margin-top: 1em; font-size: 120%; font-family: Sans-serif;">$$_{checker}</div>\n) unless ($checker eq $$_{checker});
#	print '<div>';
#	for (my $a = 3 - length $$_{importance}; $a > 0; $a--) {
#		print "&nbsp;";
#	}
#	print qq($$_{importance}| $$_{error} <a href="error.cgi?db=$datafile&id=$$_{id}">$$_{file}</a> line ),
#		qq(<a href="error.cgi?db=$datafile&id=$$_{id}#l$$_{line}">$$_{line}</a></div>\n);
#	$checker = $$_{checker};
#}

$dbh->disconnect;

end:
print $cg->end_html, "\n";

0;
