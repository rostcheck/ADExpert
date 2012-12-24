# Package containing business-level functions for auditing changes.

# 12/23/12 davidr  Created.
#
package ifaudit;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

#use strict;
use Exporter;
use DBI;
use instantframe;
use iferror;
use ifuser;

$VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(&log_changes);

# Given a reference to a hash containing new state (usually a copy of 
# %cleanvar) and a table name, log to the database what the changes were
sub log_changes
{
  my $r_state = $_[0];
  my $table_name = $_[1];
  my $id_field = $table_name . "_id";
  my $id_field_value = $r_state->{$id_field};

  my $where_clause = "$id_field = $id_field_value";
  my @columns = get_columns($table_name);
  my $r_old_values = query_fields_from_table(\@columns, $table_name, $where_clause);
  # Story an unchanged  copy to the pre-edit table
  store_to_db($table_name . "_pre_edit", \@columns, $r_old_values);
  my $change_msg = "User $r_state->{'user_email'} changed ";
  foreach my $column(@columns) {
    my $old_value = $r_old_values->{$column};
    my $new_value = $r_state->{$column};
    if ($old_value ne $new_value) {
      $change_msg .= "$column from \'$old_value\' to \'$new_value\', ";
    }
  }
  chop($change_msg); chop($change_msg);
  my ($admin_id, $login_id, $user_password) = admin_info_by_email($r_state->{'user_email'});
  my $sql = "insert into edit_log(edit_date, edit_time, record_type, record_id, admin_id, notes) values (CURRENT_DATE, CURRENT_TIME, ?, ?, ?, ?)";
  my @values = ($table_name, $id_field_value, $admin_id, $change_msg);
  quick_sql_cmd($sql, \@values);
}

1;
