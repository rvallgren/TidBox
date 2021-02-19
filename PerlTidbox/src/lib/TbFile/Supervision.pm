#
package TbFile::Supervision;
#
#   Document: Supervision class
#   Version:  1.9   Created: 2019-09-03 13:22
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Supervision.pmx
#

my $VERSION = '1.9';
my $DATEVER = '2019-09-03';

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
# 1.6  2017-09-15  Roland Vallgren
#      Removed support for import of earlier Tidbox data
# 1.7  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      References to other objects in own hash
#      Added merge with new backup data
# 1.8  2019-02-07  Roland Vallgren
#      Removed log->trace
# 1.9  2019-08-29  Roland Vallgren
#      Code improvements: Times should find dates with event
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base TbFile::Base;

use strict;
use warnings;
use Carp;
use integer;

# Register version information
{
  use TidVersion qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}

#----------------------------------------------------------------------------
#
# Constants
#

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
# Method:      _mergeData
#
# Description: Merge supervision data
#              Existing data is used
#
# Arguments:
#  - Object reference
#  - Source object to merge from
#  - Start Date
#  - End Date
# Returns:
#  -

sub _mergeData($$$$) {
  # parameters
  my $self = shift;
  my ($source, $startDate, $endDate) = @_;


  # Use enabled supervision or existing supervision
  return 0
      if ($self->{cfg}{sup_enable});

  my $sourceCfg = $source->getCfg();
  if ($sourceCfg->{sup_enable}) {
    %{$self->{cfg}} = %{$sourceCfg};
    return 0;
  } # if #

  return 0
      if ($self->{cfg}{sup_event});

  %{$self->{cfg}} = %{$sourceCfg}
      if ($sourceCfg->{sup_event});

  return 0;
} # Method _mergeData

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
  $self->{erefs}{-times}->setDisplay('Supervision', [$self, 'updated']);

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


    my $day_r = $self->{erefs}{-calculate}->
        dayWorkTimes($date, $self->{condensed}, $self->{erefs}{-error_popup});

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


  if ($self->{date} ne $self->{erefs}{-clock}->getDate()) {

    # Add time from start date up to yesterday

    my $dates =
       $self->{erefs}{-times}->getEventDates($self->{event}, $self->{start});

    my $time    = 0;

    for my $date (@$dates) {

      $time += $self->_day($date);

    } # for #

    $self->{yesterday} = $time;
    $self->{date} = $self->{erefs}{-clock}->getDate();

  } # if #

  return ($self->{yesterday} + $self->_day($self->{date}), $self->{event});

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
      unless ($self->{erefs}{-calculate}->
                 impactedDate(
                              [$self->{start},
                               $self->{erefs}{-clock}->getDate()
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
