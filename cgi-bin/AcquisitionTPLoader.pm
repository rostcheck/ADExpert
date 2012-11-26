# AcquisitionTPLoader.pm - subclass of RecordLoader that knows how to load 
# trading partners from acquisition records
package AcquisitionTPLoader;
use RecordLoader;
use instantframe;
use strict;
our @ISA = 'RecordLoader'; 

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{'table_name'} = "trading_partner";
  $self->{'keyfield'} = "trading_partner_id";
  bless $self, $class;
  return $self;
}

sub prep {
  my ($class, $r_record) = @_;
  if ($r_record->{'acquisition_license'}) { 
    $r_record->{'acquisition_license'} =~ s/FFL: //;
  }
  # Fix specific error w/ DFW Gun FFL #
  #if ($r_record->{'acquisition_license'} eq "0-75-113-07-3G-04361") {
  #  $r_record->{'acquisition_license'} = "5-75-113-07-3G-04361";
  #}
  $r_record->{'acquisition_address'} =~ m/^(.+), (.+), (\w{2}) ([\d\-]+)$/;
  $r_record->{'street'} = $1;
  $r_record->{'city'} = $2;
  $r_record->{'state'} = $3;
  $r_record->{'zip'} = $4;
  return $r_record;
}

# Check if this trading partner exists in the DB
sub exists_in_db {
  my ($self, $r_record) = @_;
  if (!$r_record->{'acquisition_license'} && !$r_record->{'acquisition_name'}) {
    return 1; # No data in record, don't insert
  }
  my $sql;
  my @values;
  if ($r_record->{'acquisition_license'}) {
    $sql = qq|select $self->{'keyfield'} from $self->{'table_name'} where ffl_license_number like ?|;
    @values = ($r_record->{'acquisition_license'});
  }
  else {
    $sql = qq|select $self->{'keyfield'} from $self->{'table_name'} where name like ?|;
    @values = ($r_record->{'acquisition_name'});
  }
  my ($record_id) = quick_sql_query($sql, \@values);
  return $record_id;
}

sub field_map {
  my %map;
  my @unchanged_fields = ();
  foreach my $unchanged_field(@unchanged_fields) {
    $map{$unchanged_field} = $unchanged_field;
  }
  $map{'acquisition_name'} = 'name';
  $map{'acquisition_license'} = 'ffl_license_number';
  $map{'street'} = 'mailing_address1';
  $map{'city'} = 'mailing_city';
  $map{'state'} = 'mailing_state';
  $map{'zip'} = 'mailing_zip';
  return \%map; 
}

1;
