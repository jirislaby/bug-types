#!/usr/bin/perl -w
use strict;
use HTML::Parser();
use LWP::Simple;

my $ff = 0;

sub start($) {
	my $tagname = shift;
	return if ($tagname ne "pre");
	$ff = 1;
}

sub end($) {
	my $tagname = shift;
	return if ($tagname ne "pre");
	$ff = 0;
}

sub text($) {
	return unless $ff;
	my $text = shift;
	return unless $text =~ /kernel\s+BUG\s+at\s+(\S+):([0-9]+)!.*Pid:\s+[0-9]+,\s+comm:\s+.{1,20}\s+(?:Not\s+tainted|Tainted:\s+[A-Z ]+)\s+([0-9.-]+\S+)\s+#/s;
	print "sss: $1 $2 $3\n";
}

foreach my $url (@ARGV) {
	my $html = get($url);
	if (!defined $html) {
		print "Cannot fetch '$url'!\n";
		next;
	}
	my $p = HTML::Parser->new(api_version => 3,
			handlers => {
				start => [\&start, "tagname"],
				text => [\&text, "text"],
				end => [\&end, "tagname"],
			});
	$p->unbroken_text(1);
	$p->parse($html);
	$p->eof;
}

0;
