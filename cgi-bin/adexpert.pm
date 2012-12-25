# This package contains common functions used by ADExpert variant scripts
#
package adexpert;
use Exporter;
use instantframe;
use ifaudit;

$VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(&log_trading_partner_changes &log_firearm_changes &log_acquisition_changes &log_disposition_changes);

sub log_trading_partner_changes
{
  my $r_state = $_[0];
  log_changes($r_state, "trading_partner");
}

sub log_firearm_changes
{
  my $r_state = $_[0];
  
  my @tracked_columns = ('firearm_id', 'manufacturer', 'importer', 'model',
    'serial_number', 'firearm_type', 'caliber');
  my @changed_columns = changed_columns($r_state, "firearm");
  my %changed = map { $_ => 1 } @changed_columns; # convert list to hash
  my $tracked_column_changed;
  foreach my $tracked_column(@tracked_columns) {
    if ($changed{$tracked_column}) { $tracked_column_changed = 1; last; }
  }
  if ($tracked_column_changed) {
    log_changes($r_state, "firearm");
  }
}

sub log_acquisition_changes
{
  my $r_state = $_[0];
  log_changes($r_state, "acquisition");
}

sub log_disposition_changes
{
  my $r_state = $_[0];
  log_changes($r_state, "disposition");
}

1;
