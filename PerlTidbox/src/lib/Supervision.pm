#
package Supervision;
#
#   Document: Supervision class
#   Version:  1.5   Created: 2016-01-28 14:37
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Supervision.pmx
#

my $VERSION = '1.5';
my $DATEVER = '2016-01-28';

# History information:
#
# 1.0  2007-06-30  Roland Vallgren
#      First issue.
# 1.1  2008-06-16  Roland Vallgren
#      Use status field to report calculate problems
# 1.2  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.3  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
# 1.4  2015-09-16  Roland Vallgren
#      Fault handling aligned with Settings in edit
#      Times::getSortedRefs does join
# 1.5  2016-01-19  Roland Vallgren
#      Gui handling moved to Gui::SupervisionConfig
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base FileBase;

use strict;
use warnings;
use Carp;
use integer;

# Register version information
{
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}

#----------------------------------------------------------------------------
#
# Constants
#
# Registration analysis constants
my $YEAR  = '\d{4}';
my $MONTH = '\d{2}';
my $DAY   = '\d{2}';
my $DATE = $YEAR . '-' . $MONTH . '-' . $DAY;

my $HOUR   = '\d{2}';
my $MINUTE = '\d{2}';
my $TIME   = $HOUR . ':' . $MINUTE;

my $TYPE = '[A-Z]+';

# Event analysis constants
my $TXT_BEGIN       = ' började';
my $TXT_END         = ' slutade';

my $WORKDAYDESC         = 'Arbetsdagen';
my $WORKDAY             = 'WORK';
my $BEGINWORKDAY        = 'BEGINWORK';
my $ENDWORKDAY          = 'WORKEND';

my $PAUSDESC            = 'Paus';
my $BEGINPAUS           = 'PAUS';
my $ENDPAUS             = 'ENDPAUS';

my $EVENTDESC           = 'Händelse';
my $BEGINEVENT          = 'EVENT';
my $ENDEVENT            = 'ENDEVENT';

# Hash to store common texts
my %TEXT = (
             $BEGINWORKDAY => 'Börja arbetsdagen',
             $ENDWORKDAY   => 'Sluta arbetsdagen',

             $BEGINPAUS    => 'Börja paus',
             $ENDPAUS      => 'Sluta paus',

             $BEGINEVENT   => 'Börja händelse',
             $ENDEVENT     => 'Sluta händelse',
           );


use constant FILENAME  => 'supervision.dat';
use constant FILEKEY   => 'SUPERVISION SETTINGS';
use constant SAVEKEYS  => qw(sup_enable start_date sup_event);

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create supervision object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
                 condensed =>   0,
                 cfg       =>   {},
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);


  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all times data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  $self->{cfg}{sup_enable} =  0;
  $self->{cfg}{start_date} = '';
  $self->{cfg}{sup_event}  = '';
  $self->{start}      =  0;
  $self->{date}       = '0';
  $self->{event}      = '';

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load supervision data
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->loadDatedSets($fh, 'cfg');

  return 1;
} # Method load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save supervision data
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _save($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->saveDatedSets($fh, 'cfg');

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      importData
#
# Description: Put imported supervision data
#
# Arguments:
#  - Object reference
#  - Enable
#  - Date
#  - Event data
# Returns:
#  -

sub importData($$$$) {
  # parameters
  my $self = shift;
  my ($enable, $date, $event) = @_;

  $self->{cfg}{sup_enable} = $enable;
  $self->{cfg}{start_date} = $date;
  $self->{cfg}{sup_event}  = $event;
  $self->dirty();
  return 0;
} # Method importData

#----------------------------------------------------------------------------
#
# Method:      startAuto
#
# Description: Start autosave timer
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub startAuto($) {
  # parameters
  my $self = shift;


  # . Subscribe to updated event data
  $self->{-times}->setDisplay('Supervision', [$self, 'updated']);

  $self->SUPER::startAuto();

  return 1;
} # Method startAuto

#----------------------------------------------------------------------------
#
# Method:      _day
#
# Description: Calculate for one day
#
# Arguments:
#  0 - Object reference
#  1 - Date
# Returns:
#  Time in minutes

sub _day($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


    my $day_r = $self->{-calculate}->
        dayWorkTimes($date, $self->{condensed}, $self->{-error_popup});

    return 0
        unless exists $day_r->{activities};
    return 0
        unless exists $day_r->{activities}{$self->{event}};

    return $day_r->{activities}{$self->{event}};
} # Method _day

#----------------------------------------------------------------------------
#
# Method:      clear
#
# Description: Clear the ongoing supervision
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub clear($) {
  # parameters
  my $self = shift;

  $self->{date} = '';
  return 0;
} # Method clear

#----------------------------------------------------------------------------
#
# Method:      is
#
# Description: Is event supervised
#
# Arguments:
#  0 - Object reference
#  1 - Event
# Returns:
#  -

sub is($$) {
  # parameters
  my $self = shift;
  my ($event) = @_;

  return ($self->{cfg}{sup_enable} and $self->{event} eq $event);
} # Method is

#----------------------------------------------------------------------------
#
# Method:      calc
#
# Description: Calculate event time from today until startdate
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - Resulting time in minutes
#  1 - Event text

sub calc($) {
  # parameters
  my $self = shift;


  my $today = $self->{-clock}->getDate();

  return ($self->{yesterday} + $self->_day($today), $self->{event})
      if ($self->{date} eq $today);

  # Add time from yesterday back until startdate
  my $start   = $self->{start};
  my $checked = 0;
  my $time    = 0;

  for my $ref (reverse(
       $self->{-times}->getSortedRefs($DATE, $TIME, $BEGINEVENT, $self->{event})
    ))
  {
    my $date = substr($$ref, 0, 10);

    next if $date eq $checked;
    next if $date ge $today;
    last if $date lt $start;

    $checked = $date;

    $time += $self->_day($date);

  } # for #

  $self->{yesterday} = $time;
  $self->{date} = $today;

  return ($self->{yesterday} + $self->_day($today), $self->{event});

} # Method calc

#----------------------------------------------------------------------------
#
# Method:      setup
#
# Description: Setup supervision
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub setup($) {
  # parameters
  my $self = shift;


  if ($self->{cfg}{sup_enable})
  {
    $self->{start} = $self->{cfg}{start_date};
    $self->{event} = $self->{cfg}{sup_event};
  } else {
    $self->{start} = 0;
    $self->{event} = '';
  } # if #

  $self->{date} = '0';

  return 0;
} # Method setup

#----------------------------------------------------------------------------
#
# Method:      updated
#
# Description: Check if changed dates are in supervision range
#              and initiate an update if so
#
# Arguments:
#  0 - Object reference
#    1 .. n - Dates impacted by the update
#    1, 2, 3 - '-', d1, d2 Range of dates impacted by the update
# Returns:
#  -

sub updated($@) {
  # parameters
  my $self = shift;
  my (@dates) = @_;


  return 0
      unless ($self->{start});
  return 0
      unless ($self->{date});
  return 0
      unless ($self->{-calculate}->
                 impactedDate(
                              [$self->{start},
                               $self->{-clock}->getDate()
                              ],
                              @dates
                             )
             );

  $self->{date} = 0;

  return 0;
} # Method updated

#----------------------------------------------------------------------------
#
# Method:      getCfg
#
# Description: Get Supervision configuration
#
# Arguments:
#  - Object reference
# Returns:
#  Reference to supervision configuration

sub getCfg($) {
  # parameters
  my $self = shift;

  return $self->{cfg};
} # Method getCfg

#----------------------------------------------------------------------------
#
# Method:      setCfg
#
# Description: Set new supervision configuration
#
# Arguments:
#  - Object reference
#  - Reference to configuration settings hash
# Returns:
#  -

sub setCfg($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  %{$self->{cfg}} = %{$ref};
  $self->dirty();
  return 0;
} # Method setCfg

1;
__END__
