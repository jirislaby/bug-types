package Helper;

use strict;
use DBI;

sub new {
	my $class = shift;
	my $out = shift;
	my $self = {};

	$self->{dbh} = undef;

	if (!-e $out) {
		print STDERR "'$out' doesn't exist!\n";
		return 0;
	}

	$self->{dbh} = DBI->connect("dbi:SQLite:dbname=$out","","", {AutoCommit => 0});
	if (!defined $self->{dbh}) {
		print STDERR "connect to db error: ", $DBI::errstr, "\n";
		return 0;
	}

	$self->{dbh}->do("PRAGMA foreign_keys = ON;");

	return bless $self, $class;
}

sub DESTROY {
	my $self = shift;
	$self->{dbh}->disconnect if (defined $self->{dbh});
}

sub get_dbh {
	return shift->{dbh};
}

sub get_id($$$@) {
	my $dbh = shift;
	my $table = shift;
	my $where = shift;

	my $data = $dbh->prepare("SELECT id FROM $table WHERE $where");
	return undef if (!defined $data);
	$data->execute(@_);
	my $hash = $data->fetchrow_hashref;
	return defined $hash ? ${$hash}{id} : undef;
}

sub get_prj($$) {
	my $self = shift;
	my $proj = shift;
	return get_id($self->{dbh}, "project", "name = ?", ($proj));
}

sub get_error($$) {
	my $self = shift;
	my $error_type = shift;
	return get_id($self->{dbh}, "error_type", "name = ?", ($error_type));
}

sub get_user($$) {
	my $self = shift;
	my $user = shift;
	return get_id($self->{dbh}, "user", "login = ?", ($user));
}

sub get_tool($$$) {
	my $self = shift;
	my $tool = shift;
	my $tool_ver = shift;
	my $where = "name = ?";
	my @bind = ($tool);
	if (defined $tool_ver) {
		$where .= " AND version = ?";
		push @bind, $tool_ver;
	}
	return get_id($self->{dbh}, "tool", $where, @bind);
}

1;
