# This package contains common functions used by ADExpert variant scripts
#
package adexpert;
use Exporter;
use instantframe;
use ifaudit;

$VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(&log_trading_partner_changes &log_firearm_changes &log_acquisition_changes &log_disposition_changes &prep_ad_book_fields);

# Transform a row from the ad_book_view (normalized database form) into the
# un-normalized A&D book form per. ATF Quick References and Best Practices
# Guide.
sub prep_ad_book_fields
{
  my $r_state = $_[0];
  my %return_hash;
  my $importer = $r_state->{'importer'};
  if (!$importer) { $importer = "No importer"; }
  $return_hash{'manufacturer_or_importer'} = "$r_state->{'manufacturer'} / $importer";
  if ($r_state->{'acquisition_ffl'}) {
    $return_hash{'acquisition_info'} = "$r_state->{'acquisition_name'} FFL $r_state->{'acquisition_ffl'}";
  }
  else { 
    $return_hash{'acquisition_info'} = "$r_state->{'acquisition_name'}<br>$r_state->{'acquisition_address1'}<br>$r_state->{'acquisition_city'}, $r_state->{'acquisition_state'} $r_state->{'acquisition_zip'}";
  }
  if ($r_state->{'disposition_ffl'}) {
    $return_hash{'disposition_info'} = "FFL $r_state->{'disposition_ffl'}";
  }
  elsif ($r_state->{'4473_number'}) {
    $return_hash{'disposition_info'} = "Form 4473 #$r_state->{'4473_number'}";
  }
  elsif ($r_state->{'lost_stolen_atf_incident_number'} || $r_state->{'lost_stolen_pd_incident_number'}) {
    if ($r_state->{'lost_stolen_atf_incident_number'}) {
      $return_hash{'disposition_info'} = "ATF Incident #$r_state->{'lost_stolen_atf_incident_number'}";
    }
    if ($r_state->{'lost_stolen_pd_incident_number'}) {
      $return_hash{'disposition_info'} .= "<br>PD #$r_state->{'lost_stolen_pd_incident_number'}";
    }
  }
  elsif($r_state->{'disposition_address1'}) {
    $return_hash{'disposition_info'} = "$r_state->{'disposition_address1'}<br>$r_state->{'disposition_city'}, $r_state->{'disposition_state'} $r_state->{'disposition_zip'}";
  }
  else { $return_hash{'disposition_info'} = ""; }
  $return_hash{'acquisition_date'} = date_or_empty(short_date_from_mysql_date($r_state->{'acquisition_date'}));
  $return_hash{'disposition_date'} = date_or_empty(short_date_from_mysql_date($r_state->{'disposition_date'}));

  return \%return_hash;
}

sub date_or_empty
{
	my $input_date = $_[0];
	if ($input_date eq "01/01/70") { return ""; }
	else { return $input_date; }
}

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
