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
	return get_id($self->{dbh}, "project_info", "name = ?", ($proj));
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

sub find_dup($$$) {
	my $self = shift;
	my $unit = shift;
	my $loc = shift;
	my $tool_id = $self->{err_tool_id};
	my $error_type_id = $self->{err_error_type_id};
	my $proj_id = $self->{err_proj_id};
	my $proj_ver = $self->{err_proj_ver};
	my $dbh = $self->{dbh};
	my $data = $dbh->prepare("SELECT error.id cid, loc_file, loc_line, " .
			"error_tool_rel.tool_id tool " .
			"FROM error, error_tool_rel " .
			"WHERE error.id == error_tool_rel.error_id AND " .
			"error_type = ? AND " .
			"project = ? AND project_version = ? AND " .
			"loc_file = ? AND loc_line = ?") ||
		die "cannot prepare SELECT: $dbh->errstr";
	$data->execute($error_type_id, $proj_id, $proj_ver, $unit, $loc);
	my $dup_id = undef;
	my $same_tool = 0;
	while ($_ = $data->fetchrow_hashref) {
		print "DUP: id=$$_{cid} unit=$unit line=$loc tool=$$_{tool}\n";
		$dup_id = $$_{cid};
		if ($tool_id == $$_{tool}) {
			$same_tool = 1;
		}
	}
	return ($dup_id, $same_tool);
}

sub error_init($$$$$) {
	my $self = shift;
	$self->{err_tool_id} = shift;
	$self->{err_error_type_id} = shift;
	$self->{err_proj_id} = shift;
	$self->{err_proj_ver} = shift;

	$self->{errors} = [];
	$self->{errors_rel} = [];
	%{$self->{errors_dup}} = ();
}

sub error_add($$$$) {
	my $self = shift;
	my $unit = shift;
	my $loc = shift;
	my $marking = shift;
	my $errors = $self->{errors};
	my $errors_rel = $self->{errors_rel};
	my $errors_dup = $self->{errors_dup};

	if (!$$errors_dup{"$unit\0$loc"}) {
		my ($dup_id, $same_tool) = $self->find_dup($unit, $loc);
		if (defined $dup_id) {
			if (!$same_tool) {
				push $errors_rel, $dup_id;
			}
		} else {
			push $errors, [ $unit, $loc, $marking ];
		}
		$$errors_dup{"$unit\0$loc"} = 1;
	}
}

sub error_push($$$) {
	my $self = shift;
	my $user_id = shift;
	my $subtype = shift;
	my $dbh = $self->{dbh};
	my $tool_id = $self->{err_tool_id};
	my $error_type_id = $self->{err_error_type_id};
	my $proj_id = $self->{err_proj_id};
	my $proj_ver = $self->{err_proj_ver};
	my @errors = @{$self->{errors}};
	my @errors_rel = @{$self->{errors_rel}};

	my $data = $dbh->prepare("INSERT INTO error_full(user, error_type, " .
		"project, project_version, loc_file, loc_line, marking, " .
		"error_subtype) VALUES (?, ?, ?, ?, ?, ?, ?, ?)") ||
		die "cannot prepare INSERT: " . $dbh->errstr;

	foreach (@errors) {
		my $unit = $$_[0];
		my $loc = $$_[1];
		my $marking = $$_[2];
		print "$unit $loc\n";
		$data->execute($user_id, $error_type_id, $proj_id,
				$proj_ver, $unit, $loc, $marking, $subtype) ||
			die "cannot INSERT: " . $dbh->errstr;
		my $error_id = $dbh->last_insert_id(undef, undef, undef, undef);
		push @errors_rel, $error_id;
	}

	$data = $dbh->prepare("INSERT INTO error_tool_rel(tool_id, error_id) " .
			"VALUES (?, ?)") ||
			die "cannot prepare INSERT: " . $dbh->errstr;

	foreach (@errors_rel) {
		$data->execute($tool_id, $_) ||
			die "cannot INSERT: " . $dbh->errstr;
	}

	$dbh->commit;

	$self->error_init(undef, undef, undef, undef);
}

1;
