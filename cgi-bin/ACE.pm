# ACE - Automated Compliance Exam functions
package ACE;
use Exporter;
use POSIX;
use Spreadsheet::WriteExcel;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::SaveParser;

$VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw($ace_version %ace_config  
							init_ace make_book get_book_as_list get_book_as_hash filter_book make_error_record
							print_fields print_report_header check_book print_errors records_to_stdout
							records_to_text records_to_excel match_books standardize_date days_apart to_unix_time
							reconcile_carried_forward find_record_in_list fields_match copy_fields format_date
							find_close_record_in_list find_record_in_book rename_book write_book make_outpath
							get_book_record_count get_book_clean_name add_error_record print_compliance_stats
							write_formatted_book load_spreadsheet find_records_in_book match_acquisitions 
							reverse_match_acquisitions create_errorset add_to_errorset print_errorset 
							create_sub_errorset merge_errorset get_book_type new_book);

$ace_version = "1.13";
%ace_config;
@default_header_fields = ('line_num',	'manufacturer',	'model', 'serial_id',	'type',	'caliber', 'acquisition_date',
	'acquisition_info',	'disposition_date',	'disposition_name',	'disposition_info',	'notes', 'book', 'page',	
	'record_type', 'audit_notes', 'row_num');

# Initialize the ACE library for use
sub init_ace
{
	load_config("ace_config.txt");
	if (-e $output_dir) { system("rm -rf $output_dir"); }
}

# Load the config file
sub load_config
{
	my $file_name = shift;
  if ($file_name eq "") { die "No file_name provided to load_config()"; }	
  open INFILE, "$file_name" or die "Error opening $file_name: $!"; 
  local $/;
  my $bigline = <INFILE>;
  $bigline =~ s/\r/\n/g; # MS-DOS to Unix line feeds
  #foreach $match($bigline =~ m/\"(.+?)\"/gs) { # remove newlines inside quote blocks
  #  $oldmatch = $match;
  #  $match =~ s/\n//g;
  #  $bigline =~ s/$oldmatch/$match/;
  #}
  $bigline =~ s/\"//g; # Get rid of all "s
  my @lines = split "\n", $bigline;
  my @file_records = ();
  my $ctr = 1;
  foreach my $line (@lines) {
    chomp($line);
    $line =~ s/\#.+//g; # Remove comments
    $line =~ s/^\s+//g; # Remove leading whitespace
    $line =~ s/\s+$//g; # Remove trailing whitespace    
    my @fields = split("=", $line);
    if (! $fields[0]) { next; }
    $fields[0] =~ s/\s+$//g; # Remove trailing whitespace 
    $fields[1] =~ s/^\s+//g; # Remove leading whitespace
    $ace_config{$fields[0]} = $fields[1];
  }	
}

# Given a file name, load its records and return it as a book reference. The book is an abstract object
# that can be accessed as a list or hash via the get_book_as... functions. Note, assumes files are in standard
# prep format (see load_file). Accepts an optional book type and field list.
sub make_book
{
  my $file_name = shift;
  my $book_type = shift; # Optional; "master" or if "partner", marks this as a trading partner book
  my $r_field_list = shift; # Optional, reference to list of fields to use (vs. inferring from column headers)
  my $header_lines = shift; # Optional, number of header lines to skip
  
  my $r_book = new_book($file_name, $book_type);
  if ($r_field_list) { $r_book->{'fields'} = $r_field_list; }
  my @records_as_list;

  if ($file_name =~ m/xls/i) { @records_as_list = load_spreadsheet($r_book, $header_lines); }
  else { @records_as_list = load_file($r_book, $header_lines); } 

  $r_book->{'list'} = \@records_as_list;

  return $r_book;
}

# Create a new, empty book and return it as a reference. The book is an abstract object
# that can be accessed as a list or hash via the get_book_as... functions. Normally the book
# would be created directly from a file via make_book() instead.
sub new_book
{
  my $file_name = shift;
  my $book_type = shift; # Optional; "master" or if "partner", marks this as a trading partner book  
  my $r_record_list = shift; # Optional, reference to list of records from load_spreadsheet or load_file, if already done
  
  if ($file_name eq "") { die "No file_name provided to new_book()"; }
  if ($book_type eq "") { $book_type = "master"; }
  if ($book_type ne "partner" && $book_type ne "master") { 
    die "Invalid book type provided to make_book(), must be partner or master";
  }
  my %book = {};
  $book{'name'} = $file_name;
  $book{'type'} = $book_type;  

	my @errorset_fields = ('manufacturer',	'model', 'serial_id',	'type',	'caliber', 'acquisition_date', 'acquisition_info', 'disposition_name',
		'disposition_date', 'disposition_info', 'error_message');
	$book{'errorset'} = create_errorset(\%book, "had errors", \@errorset_fields);
  return \%book;
}

# Given a book and a filter function, return a reference to a new book containing all the records of the old one
# for which the filter function returns true
sub filter_book 
{
	my $r_book = shift;
 	my $r_filter_function = shift;
 	if (! $r_book) { die "Invalid book provided to filter_book()"; }
 	if (! $r_filter_function) { die "No filter function provided to filter_book()"; }
 	 	
  my %book = {};
  $book{'name'} = $r_book->{'name'} . "-filtered"; 	
  my $ctr = 0;
  my $r_list = get_book_as_list($r_book);

  my @filtered_list = ();
  foreach my $r_entry(@{$r_list}) {
    my @args = ($r_entry);
    if ($r_filter_function->(@args)) { $filtered_list[$ctr++] = $r_entry; }
  }
  $book{'list'} = \@filtered_list;
  $book{'type'} = "filtered";
  push (my @fields, @{$r_book->{'fields'}});
  $book{'fields'} = \@fields;
  # Filtered book gets a new errorset
	my @errorset_fields = ('manufacturer',	'model', 'serial_id',	'type',	'caliber', 'acquisition_date');
	$book{'errorset'} = create_errorset(\@book, "$clean_name errors", \@errorset_fields);  
  return \%book;
}

# Given a reference to the book, return a reference to a list containing references to its entries
sub get_book_as_list
{
  my $r_book = shift;
  if (! $r_book) { die "Invalid book provided to get_book_as_list()"; }
  return $r_book->{'list'};
}

# Return "txt" or "xls" based on the book type
sub get_book_type
{
	my $r_book = shift;
  if (! $r_book) { die "Invalid book provided to get_book_type()"; }
  if ($r_book->{'name'} =~ m/xls/i) { return 'xls'; }
  return 'txt';
}

# Given a reference to the book, return a reference to a hash containing its entries indexed by serial number
sub get_book_as_hash
{
  my $r_book = shift;
  my $index_field = shift; # optional, defaults to serial_id 
  
  if (! $r_book) { die "Invalid book provided to get_book_as_hash()"; }
  if (!$r_book->{'hash'}) {
    $r_book->{'hash'} = index_book($r_book, $index_field);
  }
  return $r_book->{'hash'};
}

# Given reference to a book, return a reference to a hash (indexed by serial_id) of its entries. Note that since
# a serial_id can have multiple entries, the indexed hash returns a reference to a list of the entries.
sub index_book
{
  my $r_book = shift;
  my $index_field = shift; # optional, defaults to serial_id
  if (! $r_book) { die "Invalid book provided to index_book()"; }  
  if ($index_field eq "") { $index_field = 'serial_id'; }
  #print "indexing book $r_book->{'name'}\n";
  
  my %book_hash;
  my $r_list = get_book_as_list($r_book);
  my $ctr = 0;
  foreach my $r_entry(@{$r_list}) {
    $ctr++;
    if ($r_entry->{$index_field} eq "") { $no_serial_num_ctr++; next; }
    my $r_record_list = $book_hash{$r_entry->{$index_field}};    
    if ($r_record_list) { # Add to the list of records for this serial id
      push(@{$r_record_list}, $r_entry); next;  
    }
    else { 
      # Create a new list of records for this serial id
      my @entry_list = ($r_entry);
      $book_hash{$r_entry->{$index_field}} = \@entry_list;
      next;
    } 
  }
  return \%book_hash;
}

# Given a reference to a book, load the book (using the filename from 'name')
# Note: assumes files are in standard prep format: tab-delimited text format, line breaks within quotes removed, no extra
# footer rows, one header row containing column names in lowercase text with underscores (ex. serial_id). 
sub load_file 
{
	my $r_book = shift;
	if (! $r_book) { die "Invalid book provided to load_file()"; }
  my $header_lines = shift; # defaults to 0  
  my $r_field_names = $r_book->{'fields'};
    
  if ($r_book->{'name'} eq "") { die "No filename in book provided to load_file()"; }
  open INFILE, "$r_book->{'name'}" or die "Error opening $r_book->{'name'}: $!"; 
  local $/;
  my $bigline = <INFILE>;
  $bigline =~ s/\r/\n/g; # MS-DOS to Unix line feeds
  $bigline =~ s/\"//g; # Get rid of all "s
  my @lines = split "\n", $bigline;
  my @file_records = ();
  my $ctr = 1;

  foreach my $line (@lines) 
  {
    if ($ctr <= $header_lines) { $ctr++; next; } # Skip header
        
    # If field names aren't supplied, assume they are provided as the first header row (no spaces in names)
    chomp($line);
    my @fields = split "\t", $line;
    if (!$r_field_names && $ctr == 1) {
	    if (! identify_header_fields(\@fields)) { 
	      print "using default header fields\n";
	    	$r_field_names = \@default_header_fields;
	    	$r_book->{'fields'} =  \@default_header_fields; 
	    }
	    else {
	      if ($line !~ m/row_num/) { push(@fields, "row_num"); }
	      $r_field_names = \@fields;
	      $r_book->{'fields'} =  \@fields;
	      $header_lines = 1;
	      $ctr++;
	      next;    
	    }
    }
     
    $file_records[$ctr - $header_lines - 1] = {};
    for ($field_ctr = 0; $field_ctr < @{$r_field_names}; $field_ctr++) {
      my $value = $fields[$field_ctr];
      $value =~ s/\s+$//; # Trim trailing whitepace
      if ($r_field_names->[$field_ctr] =~ m/date/i) { $value = format_date($value); }
      $file_records[$ctr - $header_lines - 1]->{$r_field_names->[$field_ctr]} = $value;
     }
    $file_records[$ctr - $header_lines - 1]->{'row_num'} = $ctr; # add the file line number to the record if not supplied
    $ctr++;
  }
  print "$r_book->{'name'} contains " . scalar @file_records . " records\n";
  return @file_records;
}

# Given a reference to a book, load the book from a .xls spreadsheet (using the filename from 'name')
# Note: if the book fields are not set, expects one header row containing column names in lowercase 
# text with underscores (ex. serial_id) containing them. Optionally takes a number of header rows to skip.
sub load_spreadsheet
{
	my $r_book = shift;
	if (! $r_book) { die "Invalid book provided to load_spreadsheet()"; }
  if ($r_book->{'name'} eq "") { die "No filename in book provided to load_spreadsheet()"; }	
  my $header_lines = shift; # defaults to 0
 
  my $r_field_names = $r_book->{'fields'};  
	my $parser = Spreadsheet::ParseExcel->new();
	my $workbook = $parser->parse($r_book->{'name'});
	if (!defined $workbook) { my $error = $parser->error(); die "Unable to load $r_book->{'name'}: $error"; }
	
	my $worksheet = $workbook->worksheet(0);
	my ($row_min, $row_max) = $worksheet->row_range();
	my ($col_min, $col_max) = $worksheet->col_range();
	my @fields;

  # If not told explicitly how many header rows to skip, look for them
	if (!$header_lines) {
		#print "no header lines set\n";
		my $cell = $worksheet->get_cell($row_min, $col_min);		
		if ($cell->value() =~ m/Description of Firearm/i) {
		# This is an ATF-formatted view. The header is on the second row.
			$row_min++; 
			#print "Found 1 header line\n";
		}
		else {
			my $cell = $worksheet->get_cell($row_min + 1, $col_min);
			if ($cell->value() =~ m/Description of Firearm/i) {
				# This is an ATF-formatted view. The header is on the third row.
				$row_min += 2;
				#print "Found 2 header lines\n";
			}			
		}
	}
	else { print "header lines set to $header_lines\n"; }
				
	# If field names aren't supplied, assume they are provided as the first header row (no spaces in names)
	if (!$r_field_names) {
		for my $row ($row_min .. $row_min) { # Pick up header fields from first row
	    for my $col ($col_min .. $col_max) {
	    	my $cell = $worksheet->get_cell($row, $col);
		    next unless $cell;
				push (@fields, $cell->value());
				my $val = $cell->value();
				#print "found field $val\n";
	    }
		}	      
	  my $line = join ",", @fields;
	  if ($line !~ m/row_num/) { push(@fields, "row_num"); }
	  $r_field_names = \@fields;
	  $r_book->{'fields'} =  \@fields;
	  $header_lines += 1;
	}
	$row_min++;		
		
	# Pick up the data
	my @file_records = ();
	for my $row ($row_min  .. $row_max) {
    $file_records[$ctr] = {};
    my $no_data = 1;	
    for my $col ($col_min .. $col_max) {
    	my $cell = $worksheet->get_cell($row, $col);
    	next unless $cell;

			my $value = $cell->value();
			if ($value) { $no_data = 0; }
			$value =~ s/[\s\n]+$//; # Trim trailing whitepace
			$value =~ s/\n+/ /; # Replace any newlines with spaces
			if ($r_field_names->[$field_ctr] =~ m/date/i) { $value = format_date($value); }
			$file_records[$ctr]->{$r_field_names->[$col]} = $value;
   	}
		if ($no_data) { last; } # Blank row - we're done here   	
		$file_records[$ctr]->{'row_num'} = $row + 1; # add the file line number to the record if not supplied
		$ctr++;
	}
   
  print "$r_book->{'name'} contains " . scalar @file_records . " records\n";
  return @file_records;
}

# Given a reference to a record (hash), print the fields 
sub print_fields
{
  my $r_record = shift;
	if (!$r_record) { die "no record provided to print_fields()"; }
  foreach my $field(keys %{$r_record}) {
    print "field $field: |$r_record->{$field}|\n";
  }
}  

# Print the report header
sub print_report_header
{
  @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
  ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
  $year = 1900 + $yearOffset;
  $theTime = sprintf("%02d:%02d:%02d", $hour, $minute, $second) . " $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
  print "Automated Compliance Examination (ACE) by H2 Arms, version $ace_version\n";
  if ($ace_config{'date_checks'}) { print "Date checks are ON, max_allowable_ship_days $ace_config{'max_allowable_ship_days'}\n"; }
  else { print "Date checks are OFF\n"; }
  print "Report generated at $theTime\n\n";
  print "Client: $ace_config{'client_name'}, license start date: $ace_config{'license_start_date'}\n";
}

# Given a reference to AD book, walk it checking for internal consistency errors: ex. no acquisition date
sub check_book
{
  my $r_book = shift;
  my $r_list = get_book_as_list($r_book);
  my $clean_name = get_book_clean_name($r_book);
  my $no_serial_id = create_sub_errorset($r_book, "had no serial number");
  my $no_acquisition_date = create_sub_errorset($r_book, "had no acquisition date");

  print "checking book $r_book->{'name'} with " . scalar @{$r_list} . " records\n";
  my $ctr = 1;
  foreach my $r_entry(@{$r_list}) {
    if ($r_entry->{'acquisition_date'} eq "") { 
      add_to_errorset($no_acquisition_date, $r_entry);
      $no_acquisition_date_ctr++;
    }
    if ($r_entry->{'serial_id'} eq "") { add_to_errorset($no_serial_id, $r_entry); $no_serial_num_ctr++; }
    $ctr++;
  }
  merge_errorset($no_serial_id, $r_book->{'errorset'});
  merge_errorset($no_acquisition_date, $r_book->{'errorset'});  
}

# Given a book name, error string, and array of errors, print the errors and/or remove them to a file, based on threshold.
# The error elements are hashes containing fields. Consumes the array elements, leaving it empty.
sub print_errors
{
  my $cleaned_book_name = shift;
  $cleaned_book_name =~ s/\.txt//i;
  my $error_type = shift;
  my $error_type_string = $error_type;
  $error_type_string =~ s/ /_/g;
  my $r_error_records = shift;
  
  my $r_first_error = $r_error_records->[0];
  my @error_fields = keys(%{$r_first_error});
  #print "error fields " . join(",", @error_fields) . "\n";
  
  my $outfile = "$cleaned_book_name" . "_$error_type_string" . ".txt";
  #system("rm -f $outfile");
  my $record_type = "records";
  if ($r_book) { $record_type = "serial numbers"; }
  if (@{$r_error_records} > 0) {
    print "Possible errors: " . scalar @{$r_error_records} . " $record_type $error_type in $cleaned_book_name:\n";
    if (@{$r_error_records} > $ace_config{'remove_to_file_threshold'}) {
      if ($ace_config{'output_excel'}) { 
      	records_to_excel(make_outpath($outfile), \@error_fields, $r_error_records, "Potential Errors"); 
      }
      else { records_to_text(make_outpath($outfile), \@error_fields, $r_error_records); }
    }
    else { records_to_stdout(\$error_fields, $r_error_records); }
  }
}

# Given a reference to a list of error field names and an reference to an array of error records,
# print the errors to stdout
sub records_to_stdout
{
	my $r_error_fields = shift;
	my $r_error_records = shift;
	
	print join("\t", @{$r_error_fields}) . "\n"; 
	foreach my $r_error(@{$r_error_records}) { 
		my @values = (); my $ctr = 0;
    foreach $error_field(@error_fields) {
		  $values[$ctr++] = $r_error->{$error_field};
		}
		print join("\t", @values) . "\n";
  }
}

# Given an output path, reference to a fields list, and refernece to an array of records, write the records to a 
# tab-delimited .txt file
sub records_to_text
{
	my $outpath = shift;
	my $r_fields = shift;
	my $r_records = shift;
	$outpath =~ s/xls/txt/i;
	
	print "[ removed to $outpath ]\n"; 
  open OUTFILE, ">$outpath" or die "Error opening $outpath";
  print OUTFILE join("\t", @{$r_fields}) . "\n"; # Header
	foreach my $r_record(@{$r_records}) { 
		#my $serial_id = $r_error->{'serial_id'};
		#my $line_num = $r_error->{'line_num'};
		my @values = (); my $ctr = 0;
		foreach $field(@{$r_fields}) {   
			my $data = $r_record->{$field};
			if ($field =~/date/i) { $data = format_date($data); }     
			$values[$ctr++] = $data;		
		}
		print OUTFILE join("\t", @values) . "\n";
	}
	close OUTFILE; 
}

# Print the error records to an Excel file
sub records_to_excel
{
	my $outpath = shift;
	my $r_fields = shift;
	my $r_records_list = shift;
	my $sheet_name = shift; # Optional
			
	$outpath =~ s/txt/xls/i;
	print "[ removed to $outpath ]\n"; 
	my $workbook  = Spreadsheet::WriteExcel->new("$outpath");
	if (!$workbook) { die "Error opening $outpath"; }
	if ($sheet_name eq "") { $sheet_name = "Sheet 1"; }
	my $worksheet = $workbook->add_worksheet($sheet_name);	
	my $format = $workbook->add_format();
	$format->set_bold();
	for (my $col = 0; $col < @{$r_fields}; $col++) {
		$worksheet->write(0, $col, $r_fields->[$col], $format);
	}
  my $row = 1;
	foreach my $r_record(@{$r_records_list}) { 
		my @values = (); my $col = 0;
		foreach $field(@{$r_fields}) {
			my $data = $r_record->{$field};
			if ($field =~ m/_date/i) { $data = format_date($data); }
		  $worksheet->write($row, $col++, $data);	
		}
		$row++;
	}
	#print "wrote $row records\n";
	$workbook->close();	
}

# Given references to a acquirer's book and a disposer's book, verify that the sales from the selling dealer's book are 
# reflected in the acquirer's book. Assume the disposer's book is an extract for this client (prepared by the client or 
# extracted by a prep function before calling this) and all its transactions reflect only business with this client. 
sub match_books
{
  my $r_acquirer_book = shift;
  my $r_disposer_book = shift;
  my $f_match_disposer_name_in_acquirer_book = shift;
  if (!$r_acquirer_book) { die "no acquirer book provided to match_books()"; }
  if (!$r_disposer_book) { die "no disposer book provided to match_books()"; }
  if (!$f_match_disposer_name_in_acquirer_book) { die "no reverse match function provided to match_books()"; }
   
  my $acquirer_book_name = get_book_clean_name($r_acquirer_book);
  my $disposer_book_name = get_book_clean_name($r_disposer_book);
  my $r_ad = get_book_as_hash($r_acquirer_book);
  my $r_disposer_list = get_book_as_list($r_disposer_book);

	# Format all the messages
  print "matching $acquirer_book_name against $disposer_book_name\n";
  my @sale_not_in_book_error_fields = ('serial_id', 'row_num', 'disposition_date', 'disposition_name', 'disposition_info', 
    'zip', 'model', 'type', 'action', 'caliber', 'audit_notes');
  my @error_fields = ('serial_id', 'record_num', 'acquisition_date', 'acquisition_info', 'notes', 'audit_notes');
  my @error_fields2 = ('disposition_date'); 
  my $not_in_ad_book_msg = "appeared in $disposer_book_name but did not appear in $acquirer_book_name - may be missing A&D record";
  my $sale_not_matched_msg = "appeared in $acquirer_book_name but did not match disposer record in $disposer_book_name";  
  my $entered_late_msg = "entered in $acquirer_book_name than $ace_config{'max_allowable_ship_days'} days after disposition in $disposer_book_name";  
  my $received_before_msg = " received in $acquirer_book_name before disposition in $disposer_book_name";
  my $same_day_msg = "received in $acquirer_book_name same day as disposition in $disposer_book_name";
        
  # Create all the errorsets       
  my $sale_not_in_ad_book = create_sub_errorset($r_acquirer_book, $not_in_ad_book_msg);
  my $sale_not_matched = create_sub_errorset($r_acquirer_book, $sale_not_matched_msg); 
  my $entered_late = create_sub_errorset($r_acquirer_book, $entered_late_msg);
  my $received_before_shipped = create_sub_errorset($r_acquirer_book, $received_before_msg);
  my $received_same_day_as_shipped = create_sub_errorset($r_acquirer_book, $same_day_msg);

  # Verify that all guns sold (from the disposer's book) exist in the (client) AD book
  foreach my $r_disposer_record(@{$r_disposer_list}) {
    if ($r_disposer_record->{'serial_id'} eq "") { next; } # Skip records w/ no ID
    #print " $r_disposer_record->{'serial_id'}\t$r_disposer_record->{'disposition_date'}\n";
    # Ignore date before this license starts
    if (standardize_date($r_disposer_record->{'disposition_date'}) < $ace_config{'license_start_date'}) { next; }
    my $serial_id = $r_disposer_record->{'serial_id'};
  
    # Sale not in book
    if (!$r_ad->{$serial_id}) { add_to_errorset($sale_not_in_ad_book, $r_disposer_record); next; }
    
    # Possibly run date checks
    if ($ace_config{'date_checks'}) {
	    # The acquirer should have a record with acquisition_date within $ace_config{'max_allowable_ship_days'} of the disposer's disposition_date
	    my $r_record_list = $r_ad->{$serial_id};
	    my $r_match_record = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
	      $ace_config{'max_allowable_ship_days'});
	    if ($r_match_record) {
	      # Look for records received same day as shipped (odd)
	      my $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 0);
	      if ($r_match_record2) { add_to_errorset($received_same_day_as_shipped, $r_match_record2, $r_disposer_record); next; }   
	    }
	    else {
	      # Look for records received late
	      my $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
	        $ace_config{'supermax_ship_days'});
	      if ($r_match_record2) { add_to_errorset($entered_late, $r_match_record2, $r_disposer_record); next; }
	      else {
	        # Look for records received before shipment
	        $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
	          -$max_ship_days);
	        if ($r_match_record2) { add_to_errorset($received_before_shipped, $r_match_record2, $r_disposer_record); next; }        
	      }
		    add_to_errorset($sale_not_matched, $r_disposer_record);
	      next;
	    } 
    }
  }
  merge_errorset($sale_not_in_ad_book, $r_acquirer_book->{'errorset'});
  merge_errorset($sale_not_matched, $r_acquirer_book->{'errorset'});
  merge_errorset($received_before_shipped, $r_acquirer_book->{'errorset'});
  merge_errorset($received_same_day_as_shipped, $r_acquirer_book->{'errorset'});
  merge_errorset($entered_late, $r_acquirer_book->{'errorset'}); 
  
  # Reverse match book - verify that all firearms received by the acquirer from this disposer appear as sales on 
  # disposer's books
  my $r_acquirer_book_filtered = filter_book($r_acquirer_book, $f_match_disposer_name_in_acquirer_book);
  #$r_acquirer_book_filtered->{'name'} = "$disposer_book_name" . "_from_" . "$acquirer_book_name" . ".txt";
  my $r_acquirer_book_filtered_name = get_book_clean_name($r_acquirer_book_filtered);
  my $r_received_from_disposer_list = get_book_as_list($r_acquirer_book_filtered);
  my $r_disposer_hash = get_book_as_hash($r_disposer_book);
  #print "Found " . get_book_record_count($r_acquirer_book_filtered) . " possible records to check\n";
  print "reverse matching $r_acquirer_book_filtered_name against $disposer_book_name\n";
  my $received_not_sold = create_errorset($r_acquirer_book_filtered, "show as acquisitions in $acquirer_book_name without dispositions in $disposer_book_name", \@error_fields);
  foreach my $r_received_record(@{$r_received_from_disposer_list}) {
    $r_record_list = $r_disposer_hash->{$r_received_record->{'serial_id'}};
    #print "Checking $r_received_record->{'serial_id'}... ";
    # Not found at all
    if (! $r_record_list) { add_to_errorset($received_not_sold, $r_received_record); next; }
  }
  print_errorset($received_not_sold, $r_acquirer_book_filtered->{'errorset'});
}

# Given references to a acquirer's book and a disposer's book, verify that the dispositions from the selling dealer's book are 
# reflected as acquisitions in the acquirer's book.  
sub match_acquisitions
{
  my $r_acquirer_book = shift;
  my $r_disposer_book = shift;
  if (!$r_acquirer_book) { die "no acquirer book provided to match_acquisitions()"; }
  if (!$r_disposer_book) { die "no disposer book provided to match_acquisitions()"; }  
   
  my $acquirer_book_name = get_book_clean_name($r_acquirer_book);
  my $disposer_book_name = get_book_clean_name($r_disposer_book);
  my $r_ad = get_book_as_hash($r_acquirer_book);
  my $r_disposer_list = get_book_as_list($r_disposer_book);

  print "matching dispositions from $disposer_book_name against acquisitions in $acquirer_book_name\n";
	# Format all the messages
  print "matching $acquirer_book_name against $disposer_book_name\n";
  my @sale_not_in_book_error_fields = ('serial_id', 'row_num', 'disposition_date', 'disposition_name', 'disposition_info', 
    'zip', 'model', 'type', 'action', 'caliber', 'audit_notes');
  my @error_fields = ('serial_id', 'record_num', 'acquisition_date', 'acquisition_info', 'notes', 'audit_notes');
  my @error_fields2 = ('disposition_date'); 
  my $not_in_ad_book_msg = "did not appear in $acquirer_book_name";
  my $sale_not_matched_msg = "had records in $acquirer_book_name but did not match sale";  
  my $entered_late_msg = "were entered more than $ace_config{'max_allowable_ship_days'} days after shipment";  
  my $received_before_msg = "were received in $acquirer_book_name before dealer shipped";
  my $same_day_msg = "were received in $acquirer_book_name same day that dealer shipped";
        
  # Create all the errorsets       
  my $sale_not_in_ad_book = create_errorset($r_acquirer_book, $not_in_ad_book_msg, \@sale_not_in_book_error_fields); 
  my $sale_not_matched = create_errorset($r_acquirer_book, $sale_not_matched_msg, \@sale_not_in_book_error_fields); 
  my $entered_late = create_errorset($r_acquirer_book, $entered_late_msg, \@error_fields, \@error_fields2);
  my $received_before_shipped = create_errorset($r_acquirer_book, $received_before_msg, \@error_fields, \@error_fields2);
  my $received_same_day_as_shipped = create_errorset($r_acquirer_book, $same_day_msg, \@error_fields, \@error_fields2);

  # Verify that all guns sold (from the disposer's book) exist in the (client) AD book
  foreach my $r_disposer_record(@{$r_disposer_list}) {
    if ($r_disposer_record->{'serial_id'} eq "") { next; } # Skip records w/ no ID
    #print " $r_disposer_record->{'serial_id'}\t$r_disposer_record->{'disposition_date'}\n";
    # Ignore date before this license starts
    if (standardize_date($r_disposer_record->{'disposition_date'}) < $ace_config{'license_start_date'}) { next; }
    my $serial_id = $r_disposer_record->{'serial_id'};
  
    # Sale not in book
    if (!exists $r_ad->{$serial_id}) { add_to_errorset($sale_not_in_ad_book, $r_disposer_record); next; }
    
    # The acquirer should have a record with acquisition_date within $ace_config{'max_allowable_ship_days'} of the disposer's disposition_date
    my $r_record_list = $r_ad->{$serial_id};
    my $r_match_record = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
      $ace_config{'max_allowable_ship_days'});
    if ($r_match_record) {
      # Look for records received same day as shipped (odd)
      my $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 0);
      if ($r_match_record2) { add_to_errorset($received_same_day_as_shipped, $r_match_record2, $r_disposer_record); next; }   
    }
    else {
      # Look for records received late
      my $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
        $ace_config{'supermax_ship_days'});
      if ($r_match_record2) { add_to_errorset($entered_late, $r_match_record2, $r_disposer_record); next; }
      else {
        # Look for records received before shipment
        $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
          -$max_ship_days);
        if ($r_match_record2) { add_to_errorset($received_before_shipped, $r_match_record2, $r_disposer_record); next; }        
      }
	    add_to_errorset($sale_not_matched, $r_disposer_record);
      next;
    }
  }
  print_errorset($sale_not_in_ad_book);
  print_errorset($sale_not_matched);
  print_errorset($received_before_shipped);
  print_errorset($received_same_day_as_shipped);
  print_errorset($entered_late); 
}

# Given references to a filtered acquirer's book and a disposer's book, verify that all the sales recorded as acquisitons
# in the acquiring dealer's book are recorded as dispositions in the disposer's book. The acquirer's book should be 
# pre-filtered to show transactions from only this disposer.
sub reverse_match_acquisitions
{
 	my $r_acquirer_book_filtered = shift;
  my $r_disposer_book = shift;
  if (!$r_acquirer_book) { die "no acquirer book provided to reverse_match_acquisitions()"; }
  if (!$r_disposer_book) { die "no disposer book provided to reverse_match_acquisitions()"; }  
  
  my $acquirer_book_name = get_book_clean_name($r_acquirer_book);
  my $disposer_book_name = get_book_clean_name($r_disposer_book);
  my $r_ad = get_book_as_hash($r_acquirer_book);
  my $r_disposer_list = get_book_as_list($r_disposer_book);
  print "reverse matching sales for $acquirer_book_name against $disposer_book_name\n";
    	
  # Reverse match book - verify that all firearms received by the acquirer from this disposer appear as sales on 
  # disposer's books
  my $r_acquirer_book_filtered = filter_book($r_acquirer_book, $f_match_disposer_name_in_acquirer_book);
  $r_acquirer_book_filtered->{'name'} = "$disposer_book_name" . "_from_" . "$acquirer_book_name" . ".txt";
  my $r_acquirer_book_filtered_name = get_book_clean_name($r_acquirer_book_filtered);
  my $r_received_from_disposer_list = get_book_as_list($r_acquirer_book_filtered);
  my $r_disposer_hash = get_book_as_hash($r_disposer_book);
  #print "Found " . get_book_record_count($r_acquirer_book_filtered) . " possible records to check\n";
  print "reverse matching $r_acquirer_book_filtered_name against $disposer_book_name\n";
  my $received_not_sold = create_errorset($r_acquirer_book_filtered, "not in $disposer_book_name", \@error_fields);
  foreach my $r_received_record(@{$r_received_from_disposer_list}) {
    $r_record_list = $r_disposer_hash->{$r_received_record->{'serial_id'}};
    #print "Checking $r_received_record->{'serial_id'}... ";
    # Not found at all
    if (! $r_record_list) { add_to_errorset($received_not_sold, $r_received_record); next; }
  }
  print_errorset($received_not_sold);
}

# Given references to a disposer's book and an acquirer's book, verify that the dispositions from the disposing 
# dealer's book are reflected as acquisitions in the acquirer's book. The acquirer's book is assumed to be a 
# special-purpose extract from their books showing only acquisitions from the disposing dealer.
sub match_dispositions
{
	my $r_disposer_book = shift;
  my $r_acquirer_book = shift;

  if (!$r_acquirer_book) { die "no acquirer book provided to match_dispositions()"; }
  if (!$r_disposer_book) { die "no disposer book provided to match_dispositions()"; }  
   
  my $acquirer_book_name = get_book_clean_name($r_acquirer_book);
  my $disposer_book_name = get_book_clean_name($r_disposer_book);
  my $r_ad = get_book_as_hash($r_acquirer_book);
  my $r_disposer_list = get_book_as_list($r_disposer_book);

  print "matching sales for $acquirer_book_name against $disposer_book_name\n";
  my @sale_not_in_ad_book = (); my @could_not_match_sale = (); my @received_but_entered_late = ();
  my @received_before_shipped = (); my @received_same_day_as_shipped = (); my @received_but_not_sold = ();
  my @sale_not_in_book_error_fields = ('serial_id', 'row_num', 'disposition_date', 'disposition_name', 'disposition_info', 
    'zip', 'model', 'type', 'action', 'caliber', 'audit_notes');
  my @received_error_fields = ('serial_id', 'record_num', 'acquisition_date', 'acquisition_info', 'notes', 'audit_notes');
  my @received_error_fields2 = ('disposition_date');
  # Verify that all guns sold (from the disposer's book) exist in the (client) AD book
  foreach my $r_disposer_record(@{$r_disposer_list}) {
    if ($r_disposer_record->{'serial_id'} eq "") { next; } # Skip records w/ no ID
    #print " $r_disposer_record->{'serial_id'}\t$r_disposer_record->{'disposition_date'}\n";
    if (standardize_date($r_disposer_record->{'disposition_date'}) < $ace_config{'license_start_date'}) { next; } # Ignore date before this license starts
    my $serial_id = $r_disposer_record->{'serial_id'};
    if (!exists $r_ad->{$serial_id}) {
      add_error_record($r_acquirer_book, \@sale_not_in_ad_book, make_error_record($r_disposer_record, \@sale_not_in_book_error_fields)); 
      next;
    }
    # The acquirer should have a record with acquisition_date within $ace_config{'max_allowable_ship_days'} of the disposer's disposition_date
    my $r_record_list = $r_ad->{$serial_id};
    my $r_match_record = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
      $ace_config{'max_allowable_ship_days'});
    if ($r_match_record) {
      # Look for records received same day as shipped (odd)
      my $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 
        'disposition_date', 0);
      if ($r_match_record2) { 
        add_error_record($r_acquirer_book, \@received_same_day_as_shipped, 
        	make_error_record($r_match_record2, \@received_error_fields, $r_disposer_record, \@received_error_fields2)); 
        next;
      }        
    }
    else {
      # Look for records received late
      my $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
        $ace_config{'supermax_ship_days'});
      if ($r_match_record2) { 
        add_error_record($r_acquirer_book, \@received_but_entered_late, 
        	make_error_record($r_match_record2, \@received_error_fields, $r_disposer_record, \@received_error_fields2)); 
        next;
      }
      else {
        # Look for records received before shipment
        $r_match_record2 = find_close_record_in_list($r_record_list, $r_disposer_record, 'acquisition_date', 'disposition_date', 
          -$max_ship_days);
        if ($r_match_record2) { 
          add_error_record($r_acquirer_book, \@received_before_shipped, 
          	make_error_record($r_match_record2, \@received_error_fields, $r_disposer_record, \@received_error_fields2)); 
          next;
        }        
      }
      add_error_record($r_acquirer_book, \@could_not_match_sale, 
      	make_error_record($r_disposer_record, \@sale_not_in_book_error_fields)); 
      next;
    }
  }
  print_errors($disposer_book_name, "did not appear in $acquirer_book_name", \@sale_not_in_ad_book);
  print_errors($disposer_book_name, "had records in $acquirer_book_name but did not match sale", \@could_not_match_sale);
  print_errors($disposer_book_name, "were received in $acquirer_book_name before dealer shipped", \@received_before_shipped);
  print_errors($disposer_book_name, "were received in $acquirer_book_name same day that dealer shipped", \@received_same_day_as_shipped);
  print_errors($disposer_book_name, "were entered more than $ace_config{'max_allowable_ship_days'} days after shipment", \@received_but_entered_late); 
}

# Convert a date (in various formats) to a standard YYYYMMDD format. If an optional 
# separators is passed in, separate the date elements with that.
sub standardize_date
{
  my ($this_date, $separator) = @_;
  my $year; my $month; my $day;
  # MM/DD/YY or MM/DD/YYYY
  if ($this_date =~ m/(\d+)[\/\.](\d+)[\/\.](\d+)/) {
    $year = $3; $month = $1; $day = $2;
  }
  elsif ($this_date =~ m/(\d+)-(\d+)-(\d+)/) {
    $year = $1; $month = $2; $day = $3;
  }
  else { return $this_date; }
  if ($year < 1000) {
    if ($year < 30) { $year += 2000; }
    else { $year += 1900;  }
  }
  $day = sprintf("%02d", $day);
  $month = sprintf("%02d", $month);
  return $year . $separator . $month . $separator . $day;
}

# Given two dates (in whatever format), return the number of days apart (positive if second date is greater, negative otherwise)
sub days_apart
{
  my $first_date = standardize_date(shift);
  my $second_date = standardize_date(shift);
  return int((to_unix_time($second_date) - to_unix_time($first_date)) / (60 * 60 * 24));
}

# Convert a standard date (YYYYMMDD) to Unix time
sub to_unix_time
{
  my $standard_date = shift;
  $standard_date =~ m/(\d\d\d\d)(\d\d)(\d\d)/;
  my $year = $1 - 1900;
  my $month = $2 - 1;
  my $day = $3;
  return $unixtime = mktime(0, 0, 0, $day, $month, $year, 0, 0);
}

# Given a reference to a book and a record, return a reference to the matching record in the book (compares 
# the fields in the compare_fields list if provided or defaults to serial_id, acquisition_date, model, caliber
sub find_record_in_book
{
	my $r_book = shift;
	my $r_record = shift;	
	if (!$r_book) { die "no book provided to find_record_in_book()"; }
	if (!$r_record) { die "no record provided to find_record_in_book()"; }	
	my $r_compare_fields = shift; # optional

	#print "finding record in book, compare fields: " . join ",", @{$r_compare_fields} . "\n";
	if (! $r_compare_fields) {
		my @fields = ('serial_id', 'acquisition_date', 'model', 'caliber'); # default
		$r_compare_fields = \@fields;
	}
	my $r_hash = get_book_as_hash($r_book);
	#print "searching serial_id: $r_record->{'serial_id'}\n";
	my $r_list = $r_hash->{$r_record->{'serial_id'}};
	return find_record_in_list($r_list, $r_record, $r_compare_fields);
}

# Given a reference to a book and a record, return a reference to a list of records in the book 
# whose fields from the compare_fields list match the record provided. If compare_fields not 
# provided, defaults to serial_id, acquisiton_date, model, caliber.
# Note, assumes serial_id can be matched.
sub find_records_in_book
{
	my $r_book = shift;
	my $r_record = shift;	
	if (!$r_book) { die "no book provided to find_records_in_book()"; }
	if (!$r_record) { die "no record provided to find_records_in_book()"; }	
	my $r_compare_fields = shift; # optional

	#print "finding record in book, compare fields: " . join ",", @{$r_compare_fields} . "\n";
	if (! $r_compare_fields) {
		my @fields = ('serial_id', 'acquisition_date', 'model', 'caliber'); # default
		$r_compare_fields = \@fields;
	}
	my @results;
	my $r_hash = get_book_as_hash($r_book);
	#print "searching serial_id: $r_record->{'serial_id'}\n";
	my $r_list = $r_hash->{$r_record->{'serial_id'}};
	#print "test list contains ". scalar @{$r_list} . " records\n";
	foreach my $r_test_record(@{$r_list}) {
		#print "testing serial_id $r_test_record->{'serial_id'}, acquisition_info $r_test_record->{'acquisition_info'}, book $r_test_record->{'book'}\n";
		if (fields_match($r_record, $r_test_record, $r_compare_fields)) { push(@results, $r_test_record); }
	}
	if (@results == 0) { return undef; } 
	else { return \@results; }
}

# Given a reference to a list of records and a query record (hash), return a reference to the matching record
# in the list (compares the fields in the compare_fields list)
sub find_record_in_list
{
  my $r_ad_list = shift;
  my $r_record = shift;
	if (!$r_ad_list) { return undef; }
	if (!$r_record) { die "no record provided to find_record_in_list()"; }	  
  my $r_compare_fields = shift; # optional
  
	if (! $r_compare_fields) {
		my @fields = ('serial_id', 'acquisition_date', 'model', 'caliber'); # default
		$r_compare_fields = \@fields;
	}

  for (my $ctr = 0; $ctr < @{$r_ad_list}; $ctr++) {
    my $r_ad_record = $r_ad_list->[$ctr];
    if (fields_match($r_ad_record, $r_record, $r_compare_fields)) { return $r_ad_record; }
  }
  return undef;
}

# Given two references to records (hashes) and a reference to a list of fields to compare them on, return true if they
# match, otherwise return false
sub fields_match
{
  my $r_record1 = shift;
  my $r_record2 = shift;
  my $r_compare_fields = shift;
	if (!$r_record1) { die "no record1 provided to fields_match()"; }
	if (!$r_record2) { die "no record2 provided to fields_match()"; }	  
 	if (!$r_compare_fields) { die "no comparison field list provided to fields_match()"; }
 	 
  my $match = 1;   
  foreach $field(@{$r_compare_fields}) {
    if ($r_record1->{$field} ne $r_record2->{$field}) { $match = 0; }
  }
  return $match;
}

# Given two references to records (hashes) and a reference to a list of fields to compare them on, copy the listed fields
# from the first reference to the second
sub copy_fields
{
  my $r_from_record = shift;
  my $r_to_record = shift;
  my $r_copy_fields = shift;
	if (!$r_from_record) { die "no from record provided to copy_fields()"; }
	if (!$r_to_record) { die "no to record provided to copy_fields()"; }	  
 	if (!$r_copy_fields) { die "no copy field list provided to copy_fields()"; }  
  
  foreach $field(@{$r_copy_fields}) {
    $r_to_record->{$field} = $r_from_record->{$field};
  }
}

# Take the supplied record (hash), copy the specified fields to an error record (hash), and return it.
# If no fields supplied, assume serial_id and line_num. If a second record and set of error fields is provided,
# set those into the error record also.
sub make_error_record
{
  my $r_record = shift;
	if (!$r_record) { die "no record provided to make_error_record()"; }
  my $r_error_field_list = shift; # optional
  my $r_second_record = shift; # optional
  my $r_second_field_list = shift; # optional
  
  my @default_error_fields = ('serial_id', 'row_num', 'audit_notes');
  if (! $r_error_field_list) { $r_error_field_list = \@default_error_fields; }
  my %error_record;
  foreach my $error_field(@{$r_error_field_list}) {
    if ($error_field =~ m/date/i) { $error_record{$error_field} = standardize_date($r_record->{$error_field}); }
    else { $error_record{$error_field} = $r_record->{$error_field}; }
  }
  if ($r_second_record) {
    foreach my $error_field(@{$r_second_field_list}) {
      if ($error_field =~ m/date/i) { $error_record{$error_field} = standardize_date($r_second_record->{$error_field}); }
      else { $error_record{$error_field} = $r_second_record->{$error_field}; }
    }
  }
  return \%error_record;
}

# Given a reference to a list of records and a query record (hash), return a reference to a record matching closely
# enough. Takes two comparison fields, which must be dates, and a threshold number of days to be within. There may
# be multiple matches; this will try to find the closest. A negative threshold will allow negative values (B before A
# instead of the expected A before B).
sub find_close_record_in_list
{
  my $r_ad_list = shift;
  my $r_record = shift;
  my $compare_field1 = shift;
  my $compare_field2 = shift;
  my $threshold = shift;
	if (!$r_ad_list) { die "no list provided to find_close_record_in_list()"; }
	if (!$r_record) { die "no record provided to find_close_record_in_list()"; }
	if ($compare_field1 eq "") { die "no compare_field1 provided to find_close_record_in_list()"; }
	if ($compare_field1 eq "") { die "no compare_field2 provided to find_close_record_in_list()"; }
	if ($threshold eq "") { die "no threshold provided to find_close_record_in_list()"; }				  
  
  my $best_days_apart = $threshold;
  my $best_match = undef;
  for (my $ctr = 0; $ctr < @{$r_ad_list}; $ctr++) {
    my $r_ad_record = $r_ad_list->[$ctr];
    my $days_apart = days_apart($r_record->{$compare_field2}, $r_ad_record->{$compare_field1});
    if (abs($days_apart) <= abs($best_days_apart)) {
      if ($threshold > 0) { if ($days_apart < 0) { next; } }
      $best_match = $r_ad_record;
      $best_days_apart = $days_apart;
    }
  }
  return $best_match;
}

# Given a reference to a book and a new name, rename the book
sub rename_book
{
	my $r_book = shift;
	my $new_name = shift;
	if (!$r_book) { die "no book provided to rename_book()"; }
	if ($new_name eq "") { die "no new name provided to rename_book()"; }
			
	$r_book->{'name'} = $new_name;
}

# Given a reference to a book, write the book to disk. Note this may overwrite the book if you do not 
# rename it first. If format provided as "text", write text, otherwise default to Excel. If fields list provided, 
# use it, otherwise default to using the complete book field list (in order).
sub write_book
{
	my $r_book = shift;
	my $format = shift; # optional
	my $r_fields = shift; # Optional
	if (! $r_book) { die "no book provided to write_book()"; }
	
	my $r_list = get_book_as_list($r_book);
	if (! $r_fields) { $r_fields = $r_book->{'fields'}; }
	if ($format eq "text" || $format eq "txt") {
		records_to_text($r_book->{'name'}, $r_fields, $r_list); 
	}
	else {
		print "calling records_to_excel with name $r_book->{'name'}, " . scalar @{$r_fields} . " fields, " . 
			scalar @{$r_list} . " records\n";
		#foreach $field(@{$r_fields}) { print "field: $field\n"; }
		records_to_excel($r_book->{'name'}, $r_fields, $r_list); 
	}
}

# Given a filename, return an output path, insuring the (configured) ouput dir exists in the process
sub make_outpath
{
	my $file_name = shift;
	if ($file_name eq "") { die "no file name provided to make_outpath()"; }
	
	if (! -d $ace_config{'output_dir'}) { system("mkdir $ace_config{'output_dir'}"); }
	return $ace_config{'output_dir'} . "/" . $file_name;
}

# Given a reference to a book, return the number of records in the book
sub get_book_record_count
{
	my $r_book = shift;
	if (! $r_book) { die "no book provided to get_book_record_count()"; }
	my $r_list = get_book_as_list($r_book);
	return scalar @{$r_list};
}

# Given a reference to a book, return its name without any file extension
sub get_book_clean_name
{
	my $r_book = shift;
	if (! $r_book) { die "no book provided to get_book_clean_name()"; }
		
	my $cleaned_book_name = $r_book->{'name'};
  $cleaned_book_name =~ s/\.txt//i;
  $cleaned_book_name =~ s/\.xls//i;
  return $cleaned_book_name;
}

# Add an error record to a list. Keeps track of error statistics
sub add_error_record
{
	my $r_book = shift;
	my $r_list = shift;
	my $r_error_record = shift;
	if (! $r_book) { die "no book provided to add_error_record()"; }
	if (! $r_list) { die "no error list provided to add_error_record()"; }
	if (! $r_error_record) { die "no error record provided to add_error_record()"; }
			
	push (@{$r_list}, $r_error_record);
}

sub print_compliance_stats
{
	my $r_book = shift;
	if (! $r_book) { die "no book provided to print_compliance_stats()"; }
		
	my $r_list = get_book_as_list($r_book);
	my $r_errorset = $r_book->{'errorset'};
	my $r_error_records = $r_errorset->{'error_records'};		
	my $total_count = @{$r_list};
	my $good_count = $total_count - scalar(@{$r_error_records});
	my $compliance_rate = $good_count / $total_count * 100.0;
	#print "good count: $good_count, total_count $total_count, compliance_rate: $compliance_rate\n";
	my $book_name = get_book_clean_name($r_book);
	print "Compliance rate for $book_name: " . sprintf("%.2f", $compliance_rate) . "%\n\n"; 
	print_errorset($r_book->{'errorset'});
}

# Given a date, return it in format MM/YY/DD
sub format_date
{
	my $standard_date = standardize_date(shift);
	my $return_value = "";
  if ($standard_date ne "") {
		$standard_date =~ m/\d\d(\d\d)(\d\d)(\d\d)/; # standard format is YYYYMMDD
		$return_value = $2 . "/" . $3 . "/" . $1; # return MM/DD/YY  
  }
  #if ($return_value eq '//') { $return_value = ""; }
	return $return_value;
}

# Given a reference to a set of suspected header fields, return true if they do appear to be header fields
sub identify_header_fields
{
	my $r_list = shift;
	if (! $r_list) { die "no list provided to identify_header_fields()"; }
	# assume this is a header and disprove that
	foreach $field(@${r_list}) {
		if ($field !~ m/[\w\d\_]+/) { return 0; }
	}
	return 1;
}

# Given a reference to an AD book, output in ready-to-print ATF-acceptable Excel format 
sub write_formatted_book
{	
	my $r_book = shift;
	if (! $r_book) { die "no book provided to write_formatted_book()"; }
	my $r_records_list = get_book_as_list($r_book);
	my $workbook = "";
	
	my $file_name = $r_book->{'name'};
	$file_name =~ s/txt/xls/i; # .txt to Excel
	if ($file_name !~ m/\.xls$/i) { die "Non-xls file $file_name provided (in book) to load_header_book()"; }
	my $parser = Spreadsheet::ParseExcel::SaveParser->new();
	if ($ace_config{'header_template'} eq "") { die "Error, no header_template configured in ace_config file"; }
	my $template = $parser->Parse($ace_config{'header_template'});
	if (!defined $template) { die $parser->error(); }
	my $worksheet = $template->worksheet(0);
	
	# Fields are fixed by the book format
	my @fields = ('manufacturer',	'model', 'serial_id',	'type',	'caliber', 'acquisition_date',
		'acquisition_info',	'disposition_date',	'disposition_name',	'disposition_info', 'branch'); 
		
	#my ($row_min, $row_max) = $worksheet->{Worksheet}[0]->row_range();
  #my ($col_min, $col_max) = $worksheet->{Worksheet}[0]->col_range();       
	my @format = (); my $row = 2; # first data row
	
 	# Get the formats from the first row of data cells
 	for my $col (0 .. 9) {
 	  my $cell = $worksheet->get_cell($row, $col);
  	$format[$col] = $cell->{FormatNo}; 	  # $cell->get_format(); #
 	}
 	
 	# Write the data
	foreach my $r_record(@{$r_records_list}) { 
		my @values = (); my $col = 0;
		foreach $field(@fields) {
			my $data = $r_record->{$field};
			if ($field =~/date/i) { $data = format_date($data); }
		  #$worksheet->write($row, $col++, $data);
		  $worksheet->AddCell($row, $col, $data, $format[$col]);
		  $col++;
		}
		$row++;
	}
  #my $row_height = $worksheet->get_default_row_height(2);
  #print "row height: $row_height\n";
	#$workbook->close();
	{
		local $^W = 0; # Suppress SaveParser warnings
	  $workbook = $template->SaveAs("$file_name"); # Create our copy
	}
	print "wrote $row records\n";
	my $new_worksheet = $workbook->sheets(0);
	$new_worksheet->print_area("A2:J$row");
	$new_worksheet->fit_to_pages(1, 0);
	#my $format = $workbook->add_format();
	#$format->set_text_wrap();
	for my $rowctr (2 .. $row) { $new_worksheet->set_row($rowctr, 30); }
	$workbook->close();
}

# Create an errorset in a book. Errorsets store errors; they know how to prepare them and 
# output them
sub create_errorset
{
	my $r_book = shift;
	my $description = shift;
	my $r_record1_fields = shift; # optional, will default
	my $r_record2_fields = shift; # optional
	
	if (! $r_book) { die "no book provided to create_errorset()"; }
	if ($description eq "") { die "no description provided to create_errorset()"; }
	#if (! $r_record1_fields) { die "no record1_fields provided to create_errorset()"; }
	my @default_error_fields = ('serial_id', 'row_num', 'audit_notes');
	if (!$r_record1_fields) { $r_record1_fields = \@default_error_fields; }
	
	my %errorset;
	$errorset{'description'} = $description;
	$errorset{'book'} = $r_book;
	$errorset{'record1_fields'} = $r_record1_fields;
	$errorset{'record2_fields'} = $r_record2_fields;
	my @errorset_fields;
	my @error_records;
	push(@errorset_fields, @{$r_record1_fields});
	if ($r_record2_fields) { push(@errorset_fields, @{$r_record2_fields}); }
	$errorset{'fields'} = \@errorset_fields;
	$errorset{'error_records'} = \@error_records;
	return \%errorset;
}

# Given a book and a description, create a sub-errorset (intended to collect a 
# specific kind of error but be merged back into the parent later)
sub create_sub_errorset
{
	my $r_book = shift;
	my $description = shift;
	if (! $r_book) { die "no book provided to create_sub_errorset()"; }
	if ($description eq "") { die "no description provided to create_sub_errorset()"; }	
	my $r_parent_errorset = $r_book->{'errorset'};
	return create_errorset($r_book, $description, $r_parent_errorset->{'record1_fields'}, 
		$r_parent_errorset->{'record2_fields'});
}

# Given a source errorset reference and a target errorset reference, merge the source records
# into the target. Source should have been created from the parent via create_sub_errorset
sub merge_errorset
{
	my $r_source_errorset = shift;
	my $r_target_errorset = shift;
	if (! $r_source_errorset) { die "no source_errorset provided to merge_errorset()"; }
	if (! $r_target_errorset) { die "no target_errorset provided to merge_errorset()"; }
	
	my $r_source_list = $r_source_errorset->{'error_records'};	
	my $r_target_list = $r_target_errorset->{'error_records'};
	my $clean_name = get_book_clean_name($r_source_errorset->{'book'});
  if (@{$r_source_list} > 0) {
    print "Possible errors: " . scalar @{$r_source_list} . " records from $clean_name $r_source_errorset->{'description'}\n";
  }	
	push (@{$r_target_list}, @{$r_source_list});	
}

# Given an errorset, an AD record, and a possible second AD record, create an error 
# record (as defined by the field lists set when the errorset was created) and add it to the errorset
sub add_to_errorset
{
	my $r_errorset = shift;;
	my $r_record1 = shift;
	my $r_record2 = shift; # optional
	if (! $r_errorset) { die "no errorset provided to add_to_errorset()"; }
	if (! $r_record1) { die "no record provided to add_to_errorset()"; }

	my $r_error_record = make_error_record($r_record1, $r_errorset->{'record1_fields'}, $r_record2, 
		$r_errorset->{'record2_fields'});
	$r_error_record->{'error_message'} = $r_errorset->{'description'};
	my $r_list = $r_errorset->{'error_records'};
	push (@{$r_list}, $r_error_record);
}

# Given an errorset, print the errors and/or remove them to a file, based on threshold.
sub print_errorset
{
	my $r_errorset = shift;
	if (! $r_errorset) { die "no errorset provided to print_errorset()"; }		

	my $r_book = $r_errorset->{'book'};
	my $r_error_records = $r_errorset->{'error_records'};	
  my $cleaned_book_name = get_book_clean_name($r_book);
  $cleaned_book_name =~ s/\.txt//i;
  my $error_description = $r_errorset->{'description'};
  my $error_description_string = "$cleaned_book_name $error_description";
  $error_description_string =~ s/ /_/g;
  my $r_error_fields = $r_errorset->{'fields'};
  my $outfile = "$error_description_string" . ".txt";

  my $record_type = "records";
  if ($r_book) { $record_type = "serial numbers"; }
  if (@{$r_error_records} > 0) {
    print "Possible errors: " . scalar @{$r_error_records} . " records from $cleaned_book_name $error_description:\n";
    if (@{$r_error_records} > $ace_config{'remove_to_file_threshold'}) {
      if ($ace_config{'output_excel'}) { 
      	records_to_excel(make_outpath($outfile), $r_error_fields, $r_error_records, "Potential Errors"); 
      }
      else { records_to_text(make_outpath($outfile), $r_error_fields, $r_error_records); }
    }
    else { records_to_stdout($r_error_fields, $r_error_records); }
  }
}

1;
