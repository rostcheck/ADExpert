# AcquisitionLoader.pm - subclass of RecordLoader that knows how to load acquisition 
# records
package AcquisitionLoader;
use RecordLoader;
use instantframe;
use FirearmLoader;
use AcquisitionTPLoader;
use ACE;
use strict;
our @ISA = 'RecordLoader'; 

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{'table_name'} = "acquisition";
  $self->{'keyfield'} = "acquisition_id";
  $self->{'firearm_loader'} = FirearmLoader->new();
  $self->{'acquisition_tp_loader'} = AcquisitionTPLoader->new();
  bless $self, $class;
  return $self;
}

# Look up the firearm and trading partner ids (should already have been inserted)
sub prep {
  my ($self, $r_record) = @_;
  $self->{'firearm_loader'}->prep($r_record);
  $self->{'acquisition_tp_loader'}->prep($r_record);
  $r_record->{'acquisition_date'} = standardize_date($r_record->{'acquisition_date'}, "-");
  $r_record->{'firearm_id'} = $self->{'firearm_loader'}->exists_in_db($r_record);
  if (!$r_record->{'firearm_id'}) { die "Could not find firearms record for $r_record->{'serial_id'} when building acquisition record"; }
  $r_record->{'trading_partner_id'} = $self->{'acquisition_tp_loader'}->exists_in_db($r_record);
  if (!$r_record->{'trading_partner_id'}) { die "Could not find trading record for $r_record->{'acquisition_name'} when building acquisition record"; }
  return $r_record;
}

# Check if this acquisition record exists in the DB
sub exists_in_db {
  my ($self, $r_record) = @_;
  my $serial_num = $r_record->{'serial_id'};
  my $sql = qq|select acquisition_id from acquisition where firearm_id = ? and trading_partner_id = ? and acquisition_date like ?|;
  my @values = ($r_record->{'firearm_id'}, $r_record->{'trading_partner_id'}, $r_record->{'acquisition_date'});
  my ($acquisition_id) = quick_sql_query($sql, \@values);
  return $acquisition_id;
}

sub field_map {
  my %map;
  my @unchanged_fields = ('firearm_id', 'acquisition_date', 'trading_partner_id');
  foreach my $unchanged_field(@unchanged_fields) {
    $map{$unchanged_field} = $unchanged_field;
  }

  return \%map; 
}

1;
