#!/usr/bin/perl -w
use strict;
use HTML::Parser;
use HTTP::Request;
use LWP::UserAgent;

my $parsetext = 0;
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

sub text($) {
	return unless $parsetext;
	my $text = shift;
	return unless $text =~ /kernel\s+BUG\s+at\s+(\S+):([0-9]+)!.*Pid:\s+[0-9]+,\s+comm:\s+.{1,20}\s+(?:Not\s+tainted|Tainted:\s+[A-Z ]+)\s+([0-9.-]+\S+)\s+#/s;
	my $src = $1;
	my $line = $2;
	my $ver = $3;
	unless ($src =~ s|^/usr/src/packages/BUILD/kernel-[a-z]+-[0-9.]+/linux-[0-9.]+/||) {
		print "no src pattern in '$src'\n";
	}
	$found = 1;
	print "\tsss: $ver $src:$line\n";
}

my $arg = 0;

foreach my $url (@ARGV) {
	$arg++;
	print "Fetching $url\n";
	my $response = $ua->simple_request(HTTP::Request->new(GET => $url));
	if (!$response->is_success) {
		print "\tCannot fetch '$url': ", $response->status_line, "\n";
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
		print "\tNothing found at '$url'. The file stored as 'arg$arg'.\n";
		open F, ">arg$arg";
		print F $response->content;
		close F;
	}
}

0;
