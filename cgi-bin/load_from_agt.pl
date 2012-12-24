#!/usr/bin/perl
# load_from_agt.pl - Load a reporting spreadsheet from Auto Gun Tracker,
# setting the firearms, trading partners, and transactions
use ACE;
use instantframe;
use FirearmLoader;
use AcquisitionTPLoader;
use DispositionTPLoader;
use AcquisitionLoader;
use DispositionLoader;

init_ace();
if_init("ADExpert.ifconfig");
$r_config->{'logging'} = "stdout";
#$test_mode = 1;

if (@ARGV < 1) { die "Usage: load_from_agt.pl <spreadsheet from Auto Gun Tracker>"; }

my $agt_file = $ARGV[0];

my @fields = ('row_num', 'manufacturer', 'model', 'serial_id', 'type', 'caliber', 'acquisition_date', 'acquisition_name', 'acquisition_license', 'acquisition_address', 'disposition_date', 'disposition_name',  'disposition_license', 'disposition_address');
my $r_book = make_book($agt_file, "master", \@fields);
#load_firearms($r_book);
load_trading_partners($r_book);
load_acquisitions($r_book);
load_dispositions($r_book);

sub load_firearms
{
  my $r_book = $_[0];

  my $firearms_loader = FirearmLoader->new();
  $firearms_loader->load_book($r_book);
}

sub load_trading_partners
{
  my $r_book = $_[0];
  my $tp_loader = AcquisitionTPLoader->new();
  $tp_loader->load_book($r_book);
  $tp_loader = DispositionTPLoader->new();
  $tp_loader->load_book($r_book);
}

sub load_acquisitions
{
  my $r_book = $_[0];
   my $acquisition_loader = AcquisitionLoader->new();
   $acquisition_loader->load_book($r_book);
}

sub load_dispositions
{
  my $r_book = $_[0];
   my $disposition_loader = DispositionLoader->new();
   $disposition_loader->load_book($r_book);
}
