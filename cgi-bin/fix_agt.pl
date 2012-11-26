#!/usr/bin/perl
# fix_agt.pl - Import a reporting spreadsheet from Auto Gun Tracker and output it in a compliant format
use ACE;

init_ace();
if (@ARGV < 1) { die "Usage: fix_agt.pl <spreadsheet from Auto Gun Tracker>"; }

my $agt_file = $ARGV[0];
my $fixed_file = $agt_file;
$fixed_file =~ s/\.xls/_compliant\.xls/;
#my $r_old_book = make_book($agt_file);
#filter_book()

print "Fixing records in $agt_file\n";
my @fields = ('row_num', 'manufacturer',	'model', 'serial_id',	'type',	'caliber', 'acquisition_date',
	'acquisition_name',	'acquisition_license', 'acquisition_address', 'disposition_date',	'disposition_name',	
	'disposition_license', 'disposition_address');
my $r_book = make_book($agt_file, "master", \@fields);

# After loading the book, change its output columns
my @new_field_list = ('row_num', 'manufacturer',	'model', 'serial_id',	'type',	'caliber', 'acquisition_date',
	'acquisition_info',	'disposition_date',	'disposition_name',	'disposition_info');
$r_book->{'fields'} = \@new_field_list;

my $r_list = get_book_as_list($r_book);
foreach my $r_record(@{$r_list}) {
	#print_record($r_record);
	#next;
	# Fix acquisition info to have FFL # per best practices guide (FFL <first 3>-<last 5>
	#$r_record->{'acquisition_license'} =~ s/-//g;
	##$r_record->{'acquisition_license'} =~ m/(\d-\d\d)-[\w\d\-]+(\d{5})/;
	#$r_record->{'acquisition_license'} =~ m/(\d{3})[\w\d\-]+(\d{5})/;
	#my $first_three = $1;
	#my $last_five = $2;
	#$r_record->{'acquisition_info'} = $r_record->{'acquisition_name'} . "\nFFL " . $first_three . "-" . $last_five;
	$r_record->{'acquisition_info'} = $r_record->{'acquisition_name'} . "\n$r_record->{'acquisition_license'}";
	
	# If there is no importer, explicitly write "no importer" with the manufacturer
	if ($r_record->{'manufacturer'} !~ m/\//) {
		$r_record->{'manufacturer'} .= " / No importer";
	}
	# Fix disposition info
	if ($r_record->{'disposition_name'} ne "") {
		$first_three = ""; $last_five = "";
		if ($r_record->{'disposition_license'} ne "") {
			my $license = $r_record->{'disposition_license'};
			$license =~ s/-//g;
			if ($license =~ m/FFL([\d\w]{1})([\d\w]{2})([\d\w]{3})([\d\w]{2})([\d\w]{2})([\d\w]{5})/) {
			#if ($r_record->{'disposition_license'} =~ m/FFL-([\d\w\-])/) {
				#$r_record->{'disposition_license'} =~ s/-//g;
				#$r_record->{'disposition_license'} =~ m/(\d{3})[\w\d\-]+(\d{5})/;			
				##$r_record->{'disposition_license'} =~ m/(\d-\d\d)-[\w\d\-]+(\d{5})/;
				#$first_three = $1;
				#$last_five = $2;
				#if ($first_three ne "") {
				#	$r_record->{'disposition_info'} = "FFL " . $first_three . "-" . $last_five;
				#};
				$r_record->{'disposition_info'} = "FFL: " . "$1-$2-$3-$4-$5-$6";
				#print "$r_record->{'disposition_license'}|$r_record->{'disposition_info'}\n";
			}
			elsif ($r_record->{'disposition_license'} =~ m/TranSN-(\d+)/)
			{
				my $form_4473_number = $1;
				if ($form_4473_number ne "") {
					$r_record->{'disposition_info'} = "Form 4473 #$form_4473_number";
				}
			}
			else {
				$r_record->{'disposition_info'} = $r_record->{'disposition_address'}
			}
		}
	}
}
#rename_book($r_book, get_book_clean_name($r_book) . "-fixed.xls");
rename_book($r_book, "Printable_Book.xls");
write_formatted_book($r_book); 



