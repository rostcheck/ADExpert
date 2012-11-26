#class RecordLoader - class capable of loading a record from a book (defined
#a la ACE.pm) to a database
package RecordLoader;
use instantframe;
use ACE;
use strict;

sub new {
  my ($class) = @_;
  my $self = {
    'table_name' => undef,
    'keyfield' => undef
  };
  bless $self, $class;
  return $self;
}

# Given a reference to a book (a la ACE), load each record
sub load_book {
  my ($self, $r_book) = @_;
  my $r_list = get_book_as_list($r_book);

  foreach my $r_record(@{$r_list}) { 
    $self->load_record($r_record);
  }
}

# Load an individual record (enforces the control flow). Subclasses should not
# need to override this.
sub load_record {
  my ($self, $r_record) = @_;
  $self->prep($r_record);
  my $record_id = $self->exists_in_db($r_record);
  if (!$record_id) {
    my $r_new_record = $self->remap_fields($r_record);
    my @fieldlist = keys %$r_new_record;
    #print "fieldlist: " . join(",", @fieldlist) . "\n";
    store_to_db($self->{'table_name'}, \@fieldlist, $r_new_record, $self->{'keyfield'});
  }
  else {
    log_msg("Found record for $self->{'table_name'} $record_id");
  }
}

# Given a record, a field list, and a map of field names to change, construct a
# new record containing the new fieldnames.
# Subclasses should not need to override this
sub remap_fields
{
  my ($self, $r_record) = @_;
  my %new_record;
  my $r_map = $self->field_map();
  foreach my $field(keys %$r_map) {
    my $recordkey = $field;
    if ($r_map->{$field}) {
      $recordkey = $r_map->{$field};
    }
    if ($recordkey) { 
      $new_record{$recordkey} = $r_record->{$field};  
    }
    #print "mapped $field to $recordkey\n";
  }
  return \%new_record;
}
# Prep the record for loading. Subclasses should override this with any prep
# they want to do (set fields in the record based on other fields in the record)
sub prep {
  my ($self, $record) = @_;
  return $self->$record;
}

# Test if this record exists in the DB; return 1 if so, 0 if not. Subclasses 
# should override this.
sub exists_in_db {
  my ($self, $record) = @_;
  return 0;
}

# Return a map of field names in the incoming record to field names in the DB.
# Subclasses should override this.
sub field_map {
  our %map = {};
  return \%map;
}

1;
