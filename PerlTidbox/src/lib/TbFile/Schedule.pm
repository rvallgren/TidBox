#
package TbFile::Schedule;
#
#   Document: Work time schedule
#   Version:  1.0   Created: 2026-02-01 19:22
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Schedule.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2026-02-01';

# History information:

# PA1  2024-01-04  Roland Vallgren
#      First issue based on TbFile::EventCfg.
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


# Schedule configuration: Default
use constant
{
  SCHEDULE_START => '0000-00-00',

#  ordinary_week_work_time  Ordinary week worktime, used for Week hints
#                           Default is 40 hours a week

  ORDINARY_WEEK_WORK_TIME => 40,

  FILENAME  => 'schedule.dat',
  FILEKEY   => 'SCHEDULE CONFIGURATION',
};

# TODO testr onl
# Registration analysis constants
my $YEAR  = '\d{4}';
my $MONTH = '\d{2}';
my $DAY   = '\d{2}';
my $DATE = $YEAR . '-' . $MONTH . '-' . $DAY;

my $HOUR   = '\d{2}';
my $MINUTE = '\d{2}';
my $TIME   = $HOUR . ':' . $MINUTE;

my $TYPE = qr/[BEPW][AENOV][DEGRU][EIKNPS][ADEKNORSTUVW]*/;

#############################################################################
#
# Function section
#
#############################################################################

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create new event configuration data
#              If used in an archive set slightly limitied
#              TODO: Subclass archive?
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;
  my $self;

  $self = {
           -display => {},
           ordinary_week_work_time => ORDINARY_WEEK_WORK_TIME,
          };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all schedule data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  $self->{date} = SCHEDULE_START;
  $self->{cfg} =
    {
      ordinary_week_work_time => ORDINARY_WEEK_WORK_TIME,
    };
  %{$self->{earlier}} = ()
      if (exists($self->{earlier}));

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load schedule data
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle to load from
# Returns:
#  0 = Success

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->loadDatedSets($fh, 'cfg');


  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save schedule data to file
#
# Arguments:
#  0 - Object reference
#  1 - Filehandle
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
# Method:      splitSet
#
# Description: Split schedule set on date
#
# Arguments:
#  - Object reference
#  - Reference to schedule set
#  - Split date
# Returns:
#  - One of the sets?

sub splitSet($$) {
  # parameters
  my $self = shift;
  my ($cfg_ref, $split_date) = @_;


  # Split into before and after
  my $before_ref = {};
  my $after_ref = {};
  for my $date (keys(%{$cfg_ref})) {
    if ($date eq 'ordinary_week_work_time') {
      # We keep ordinary week worktime in both before and after
      $after_ref->{$date} = $cfg_ref->{$date};
      $before_ref->{$date} = $cfg_ref->{$date};
    } elsif ($date ge $split_date) {
      $after_ref->{$date} = [@{$cfg_ref->{$date}}];
    } else {
      $before_ref->{$date} = [@{$cfg_ref->{$date}}];
    } # if #
  } # for #

  return ($before_ref, $after_ref);
} # Method splitSet

#----------------------------------------------------------------------------
#
# Method:      move
#
# Description: Move schedule to a schedule object
#              If no last date or first is specified all data is moved
#
# Arguments:
#  - Object reference
#  - Reference to schedule configuration object to move to
# Optional Arguments:
#  - Last date to move
#  - First date to move
# Returns:
#  -

sub move($$;$$) {
  # parameters
  my $self = shift;
  my ($target, $last_date, $first_date) = @_;


  # Move all data after first date and before last date
  my $cfg_r;
  my ($before_date, $prev_date);
  for my $date (sort(keys(%{$self->{earlier}}))) {
    if (defined($first_date) and $date lt $first_date) {
      $before_date = $date;
      next;
    } # if #
    $cfg_r = $self->{earlier}{$date};
    $prev_date = $date;
    if (defined($last_date) and $date gt $last_date) {
      # Use splitSet to split previous set at last date
      my ($before_ref, $after_ref) =
          $self->splitSet($self->{earlier}{$prev_date}, $last_date);
      $self->{earlier}{$last_date} = $after_ref;
      $target->addSet('cfg', $before_ref, $prev_date);
      delete($self->{earlier}{$prev_date});
      last;
    } # if #

    # This set is between first date and last date, whole set moved
    $target->addSet('cfg', $cfg_r, $date);
    delete($self->{earlier}{$date});

  } # for #

  if (defined($before_date) and not exists($self->{earlier}{$first_date})) {
    # Split set that goes through first date
    my ($before_ref, $after_ref) =
        $self->splitSet($self->{earlier}{$before_date}, $first_date);
    $target->addSet('cfg', $after_ref, $first_date);
    $self->{earlier}{$before_date} = $before_ref;
  } # if #

  # TODO What if there is only an active set?
  if (defined($last_date) and $self->{date} le $last_date) {
    # Last date is in active set split and archive first part
    my ($before_ref, $after_ref) =
        $self->splitSet($self->{cfg}, $last_date);
    $target->addSet('cfg', $before_ref, $self->{date});
    $self->{date} = $last_date;
    $self->{cfg} = $after_ref;
  } # if #

  $self   -> dirty();
  $target -> dirty();

  return 0;
} # Method move

#----------------------------------------------------------------------------
#
# Method:      _mergeData
#
# Description: Merge schedule from an schedule set, skip schedule
#              on the same date
#
# Arguments:
#  - Object reference
#  - Source object to merge from
#  - Start Date
#  - End Date
# Optional Arguments:
#  - Reference to progress handling hash
# Returns:
#  -

sub _mergeData($$$$;$) {
  # parameters
  my $self = shift;
  my ($source, $startDate, $endDate, $progress_ref) = @_;


  # Merge all data or up to date to merge is later than actual
  # event configuration date

  my ($tdate, $tcfg) = $self->getDateSchedule();
  my $earlier = $source->getEarlierSchedule();

  # Progress bar handling
  my $sProgressSteps;
  my $sProgressCnt;
  my $si = 0;
  my $tProgressSteps;
  my $tProgressCnt;
  my $ti = 0;
  if ($progress_ref) {
    $sProgressSteps =
      ( (scalar(keys(%{$earlier})) + 1) / $progress_ref->{-percent_part} ) || 1;
    $sProgressCnt = 0;
    $tProgressSteps =
      ( (scalar(keys(%{$self->{earlier}})) + 1) /
                   $progress_ref->{-percent_part} ) || 1;
    $tProgressCnt = 0;
  } # if #

  # Add all earlier data and clear earlier
  for my $date (keys(%{$earlier})) {

    $si++;
    if ($progress_ref) {
#      if ($sProgressSteps > $tProgressSteps) {
        if ($si > $sProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $sProgressCnt += $sProgressSteps;
        } # if #
#      } else {
#        if ($ti > $tProgressCnt) {
#          $self->callback(@{$progress_ref->{-callback}});
#          $tProgressCnt += $tProgressSteps;
#        } # if #
#      } # if #
    } # if #


    next
        if ($date lt $startDate);
    next
        if ($date gt $endDate);
    next
        if ($date eq $tdate);
    unless (exists($self->{earlier}{$date})) {
      $self->addSet('cfg', [ @{$earlier->{$date}} ], $date);
      $source->removeCfg($date);
    } # unless #
  } # for #

  #   Copy actual data to target set and update date
  my ($date, $cfg) = $source->getDateSchedule();
  return 0
      if ($date lt $startDate);
  return 0
      if ($date gt $endDate);
  return 0
      if ($date eq $tdate);
  unless (exists($self->{earlier}{$date})) {
    $self->addSet('cfg', [ @{$cfg} ], $date);
    $source->removeCfg($date);
  } # unless #

  return 0;
} # Method _mergeData

#----------------------------------------------------------------------------
#
# Method:      getWeekScheduledTime
#
# Description: Returns scheduled work hours, in number of minutes,
#              for the week, today or week with specified date
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Date in week
# Returns:
#  Scheduled work time from schedule

sub getWeekScheduledTime($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  return $self->{ordinary_week_work_time}
    unless ($date);

  # Find record with dates
  my $ref;
  if ($date ge $self->{date}) {
    $ref = $self->{cfg};
  } else {
    my $found = SCHEDULE_START;
    for my $d (sort(keys(%{$self->{earlier}}))) {
      last
        if $d gt $date;
      $found = $d;
    } # for #
    $ref = $self->{earlier}{$found};
  } # if #

  # Get time if a special week: NOTE Special weeks have date for Monday
  return ($ref->{$date}[0])
    if (exists($ref->{$date}));

  return $ref->{ordinary_week_work_time};

} # Method getWeekScheduledTime

#----------------------------------------------------------------------------
#
# Method:      getEarlierSchedule
#
# Description: Get earlier schedule
#
# Arguments:
#  - Object reference
# Returns:
#  - Referense to earlier hash

sub getEarlierSchedule($) {
  # parameters
  my $self = shift;

  return $self->{earlier};
} # Method getEarlierSchedule

#----------------------------------------------------------------------------
#
# Method:      getDateSchedule
#
# Description: Get current event configuration and start date
#
# Arguments:
#  0 - Object reference
# Returns:
#  - Reference to array with date and event configuration

sub getDateSchedule($) {
  # parameters
  my $self = shift;

  return ($self->{date}, $self->{cfg});
} # Method getDateSchedule

#----------------------------------------------------------------------------
#
# Method:      _copySet
#
# Description: Create a copy of a schedule set
#
# Arguments:
#  - Object reference
#  - Ref to set to copy
# Optional Arguments
#  -
# Returns:
#  Reference to copy

sub _copySet($$) {
  # parameters
  my $self = shift;
  my ($cfg) = @_;


  my $set = {ordinary_week_work_time => $cfg->{ordinary_week_work_time}};

  while (my ($date, $ref) = each(%{$cfg})) {
    next
        if ($date eq 'ordinary_week_work_time');
    $set->{$date} = [@$ref];
  } # while #

  return $set;
} # Method _copySet

#----------------------------------------------------------------------------
#
# Method:      updateCfg
#
# Description: Update active schedule settings
#              Replace current set with future set
#              If earlier set is specified Add the earlier set
#
# Arguments:
#  - Object reference
#  - Ref to future set
#  - Start date for future set
# Optional Arguments
#  - Ref to earlier set
#  - Start date of earlier set
# Returns:
#  -

sub updateCfg($$$;$$) {
  # parameters
  my $self = shift;
  my ($future_cfg, $future_date, $earlier_cfg, $earlier_date) = @_;


  if ($earlier_date) {
    $self->{earlier}{$earlier_date} = $self->_copySet($earlier_cfg);
  } # if #

  $self->{cfg} = $self->_copySet($future_cfg);
  $self->{date} = $future_date;
  $self->dirty();

  # TODO Not yet implemented to change sets before last ordinary week
  #      worktime change

  return 0;
} # Method updateCfg

#----------------------------------------------------------------------------
#
# Method:      notifyClients
#
# Description: Notify clients of changes in schedule
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub notifyClients($) {
  # parameters
  my $self = shift;

  $self->_doDisplay(@_);
  return 0;
} # Method notifyClients

1;
__END__
