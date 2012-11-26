# FirearmLoader.pm - subclass of RecordLoader that knows how to load firearms
package FirearmLoader;
use RecordLoader;
use instantframe;
use strict;
our @ISA = 'RecordLoader'; 

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{'table_name'} = "firearm";
  $self->{'keyfield'} = "firearm_id";
  bless $self, $class;
  return $self;
}

# If there is no importer, explicitly write "no importer" with the manufacture
sub prep {
  my ($self, $r_record) = @_;
  if ($r_record->{'importer'} eq "") {
    $r_record->{'importer'} = "No importer";
    if ($r_record->{'importer'} =~ m/\/\w+(.+)$/) {
      $r_record->{'importer'} .= $1;
    }
  }
  return $r_record;
}

# Check if this firearm exists in the DB
sub exists_in_db {
  my ($self, $r_record) = @_;
  my $serial_num = $r_record->{'serial_id'};
  my $sql = qq|select firearm_id from firearm where serial_number like ?|;
  my @values = ($serial_num);
  my ($firearm_id) = quick_sql_query($sql, \@values);
  return $firearm_id;
}

sub field_map {
  my %map;
  my @unchanged_fields = ('manufacturer', 'importer', 'model', 'caliber');
  foreach my $unchanged_field(@unchanged_fields) {
    $map{$unchanged_field} = $unchanged_field;
  }
  $map{'type'} = 'firearm_type';
  $map{'serial_id'} = 'serial_number';

  return \%map; 
}

1;
