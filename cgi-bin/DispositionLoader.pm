# DispositionLoader.pm - subclass of RecordLoader that knows how to load disposition 
# records
package DispositionLoader;
use RecordLoader;
use instantframe;
use FirearmLoader;
use DispositionTPLoader;
use AcquisitionLoader;
use ACE;
use strict;
our @ISA = 'RecordLoader'; 

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{'table_name'} = "disposition";
  $self->{'keyfield'} = "disposition_id";
  $self->{'firearm_loader'} = FirearmLoader->new();
  $self->{'disposition_tp_loader'} = DispositionTPLoader->new();
  $self->{'acquisition_loader'} = AcquisitionLoader->new();
  bless $self, $class;
  return $self;
}

# Look up the firearm and trading partner ids (should already have been inserted),
# as well as the acquisition id for this record
sub prep {
  my ($self, $r_record) = @_;
  if ($r_record->{'disposition_license'} =~ m/TranSN-(\d+)/) {
    $r_record->{'4473_number'} = $1;
    $r_record->{'disposition_license_number'} = ""; # Not a dealer
  }

  $r_record->{'disposition_date'} = standardize_date($r_record->{'disposition_date'}, "-");

  # Get acquisition id
  $self->{'acquisition_loader'}->prep($r_record); 
  $r_record->{'acquisition_id'} = $self->{'acquisition_loader'}->exists_in_db($r_record);
  if (!$r_record->{'acquisition_id'}) { die "Could not find acquisition record for $r_record->{'acquisition_name'} when building disposition for firearm $r_record->{'serial_id'} on $r_record->{'disposition_date'}"; }

  # Get (disposition) trading partner id
  $self->{'disposition_tp_loader'}->prep($r_record);
  $r_record->{'trading_partner_id'} = $self->{'disposition_tp_loader'}->exists_in_db($r_record);
  if (!$r_record->{'trading_partner_id'}) { die "Could not find trading partner record for $r_record->{'disposition_name'} when building disposition for firearm $r_record->{'serial_id'} on $r_record->{'disposition_date'}";} 

  return $r_record;
}

# Check if this disposition record exists in the DB
sub exists_in_db {
  my ($self, $r_record) = @_;
  if (!$r_record->{'disposition_date'} && !$r_record->{'disposition_name'}) {
    return 1; # Nothing to insert
  }
  my $sql = qq|select disposition_id from disposition where acquisition_id = ? and disposition_date like ?|;
  my @values = ($r_record->{'acquisition_id'}, $r_record->{'disposition_date'});
  my ($disposition_id) = quick_sql_query($sql, \@values);
  return $disposition_id;
}

# Note: Lost/stolen ATF incident number and lost/stolen PD number not implemented
sub field_map {
  my %map;
  my @unchanged_fields = ('acquisition_id', 'disposition_date', 'trading_partner_id', '4473_number');
  foreach my $unchanged_field(@unchanged_fields) {
    $map{$unchanged_field} = $unchanged_field;
  }
  
  return \%map; 
}

1;
