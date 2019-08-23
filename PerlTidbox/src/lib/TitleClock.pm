#
package TitleClock;
#
#   Document: Running clock for timing and visible clock
#   Version:  1.12   Created: 2019-05-17 13:14
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: TitleClock.pmx
#

my $VERSION = '1.12';
my $DATEVER = '2019-05-17';

# History information:
#
# PA1  2006-11-26  Roland Vallgren
#      First issue, extracted from tidbox.plx
# PA2  2007-02-24  Roland Vallgren
#      Removed method setCalculator
#      Clock can be shown in more than one window
# PA3  2007-03-05  Roland Vallgren
#      Remove obsolete code
# 1.4  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
# 1.5  2007-06-17  Roland Vallgren
#      Added repeat -hour and -date
# 1.6  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.7  2013-05-18  Roland Vallgren
#      Show session lock instead of time
# 1.8  2015-09-23  Roland Vallgren
#      Added detection and subscription of sleep
#      Added quit method to stop sending repeat messages
# 1.9  2016-01-15  Roland Vallgren
#      setDisplay moved to TidBase
# 1.10  2017-10-16  Roland Vallgren
#       References to other objects in own hash
#       Added a timeout one shot timer
# 1.11  2019-01-24  Roland Vallgren
#       Clear all timeout on quit
#       Added -seconds in timeout
# 1.12  2019-05-17  Roland Vallgren
#       New method getHHMMSS
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

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
# Object data
#
#  -calculate  Reference calculator
#
# Private data
#
#  systime     Time in seconds since epoch
#  wt          Array with last time read from localtime
#  second      Current second         0..59
#  minute      Current minute         0..59
#  hour        Current hour           0..23
#  time        Current hour:minute    09:14
#  date        Current YYYY-MM-DD     2007-10-21
#  year        Current year           2007
#  month       Current month          1..12
#  day         Current day            1..31
#  monthtxt    Current month name     Januari .. December
#  week        Current week number    1..53
#  weekday     Current day in week    0..6
#  weekdaytxt  Current day name       Måndag .. Söndag
#  sleep       Time in seconds since last tick was registered
#  locked      Session locked
#
#  -display    Hash with displays were the clock is displayed
#              'name' => Reference to Tk widget to display in
#  -repeat     Hash with running timers
#              -date    List of timers to run every midnight
#              -hour    List of timers to run every new hour
#              -minute  List of timers to run every new minute
#              -sleep   List of timers to run whenever a sleep is detected
#  -timeout     Hash with running timeouts
#               -minute  List of timeouts in minutes
#               -second  List of timeouts in seconds

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              systime => time(),
              date    => 0,
              hour    => 0,
              minute  => 0,
             };

  bless($self, $class);

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      repeat
#
# Description: Add a repeat timer
#
# Arguments:
#  0 - Object reference
#  -minute    Callback for minute routine
#  -hour      Callback for hour routine
#  -date      Callback for date routine
# Returns:
#  -

sub repeat($;%) {
  # parameters
  my $self = shift;
  my %arg = @_;


  for my $k (keys(%arg)) {
    push @{$self->{-repeat}{$k}}, $arg{$k};
  } # for #

  return 0;
} # Method repeat

#----------------------------------------------------------------------------
#
# Method:      timeout
#
# Description: Add a timeout one shot timer
#              If number of minutes or seconds is less than one the timeout
#              will happen att the next minute or second tick
#
# Arguments:
#  0 - Object reference
#  -minute    Number of minutes
#  -second    Number of seconds
#  -callback  Callback to be called at time out
# Returns:
#  -

sub timeout($;%) {
  # parameters
  my $self = shift;
  my %arg = @_;


  if (exists($arg{-minute})) {
    croak 'No -minute timeout value set', %arg
        unless (defined($arg{-minute}));
    push @{$self->{-timeout}{-minute}},
              { timeout  => $arg{-minute},
                callback => $arg{-callback},
              };
  } elsif (exists($arg{-second})) {
    croak 'No -second timeout value set', %arg
        unless (defined($arg{-second}));
    push @{$self->{-timeout}{-second}},
              { timeout  => $arg{-second},
                callback => $arg{-callback},
              };
  } else {
    croak 'No known timeout set', %arg;
  } # if #


  return 0;
} # Method timeout

#----------------------------------------------------------------------------
#
# Method:      tick
#
# Description: Clock tick, triggered once a second
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub tick($) {
  # parameters
  my $self = shift;


  my $systime = time();
  my $sleep = $systime - $self->{systime};
  $self->{sleep} = $sleep;
  $self->{systime} = $systime;
  if ($sleep > 60) {
    # More than one minute since last invocation of tick
    # A possible sleep or hibernation has occured
    # Make sure the clock gets correct information
    $self->{date}   = 0;
    $self->{hour}   = 0;
    $self->{minute} = 0;
  } # if #

  my @wt = localtime($systime);
  @{$self->{wt}} = @wt;
  my ($sec, $min) = ($wt[0], $wt[1]);
  $sec = '0' . $sec if $sec < 10;
  $min = '0' . $min if $min < 10;
  $self->{second} = $sec;

  if ($min ne $self->{minute}) {

    $self->{minute} = $min;

    my $hour = $wt[2];
    $hour   = '0' . $hour if $hour < 10;
    my $time = $hour . ':' . $min;
    $self->{time} = $time;

    if ($hour ne $self->{hour}) {
      $self->{hour} = $hour;

      my $date = $self->{erefs}{-calculate}->yyyyMmDd($wt[5], $wt[4]+1, $wt[3]);

      if ($date ne $self->{date}) {
        $self->{date} = $date;
        ($self->{year}, $self->{month}, $self->{day}) = split('-', $date);
        $self->{monthtxt}   =
                       $self->{erefs}{-calculate}->monthStr($self->{month});
        $self->{week}       = $self->{erefs}{-calculate}->weekNumber($date);
        $self->{weekday}    = $wt[6];
        $self->{weekdaytxt} = $self->{erefs}{-calculate}->dayStr($wt[6]);

        for my $ref (@{$self->{-repeat}{-date}}) {
          $self->callback($ref);
        } # for #
      } # if #

      for my $ref (@{$self->{-repeat}{-hour}}) {
        $self->callback($ref);
      } # for #
    } # if #

    for my $ref (@{$self->{-repeat}{-minute}}) {
      $self->callback($ref);
    } # for #

    my $index = 0;
    my $aref = $self->{-timeout}{-minute};
    while ($index <= $#{$aref} ) {
      my $ref = $aref->[$index];
      if ( $ref->{timeout} <= 0 ) {
        $self->callback($ref->{callback});
        splice @{$aref}, $index, 1;
        # TODO Only allow one timeout to trigger at the same time?
        #      Coordinate with -second and -repeat??
        # last;
      } else {
        $ref->{timeout}--;
        $index++;
      } # if #
    } # while #

  } # if #

  my $index = 0;
  my $aref = $self->{-timeout}{-second};
  while ($index <= $#{$aref} ) {
    my $ref = $aref->[$index];
    if ( $ref->{timeout} <= 0 ) {
      $self->callback($ref->{callback});
      splice @{$aref}, $index, 1;
      # TODO Only allow one timeout to trigger at the same time?
      # last;
    } else {
      $ref->{timeout}--;
      $index++;
    } # if #
  } # while #

  if ($sleep > 60) {
    # Handle action due to sleep or hibernation longer than 60 seconds
    for my $ref (@{$self->{-repeat}{-sleep}}) {
      $self->callback($ref);
    } # for #
  } # if #

  if ($self->{-display}) {
    my $t = join(' ',           $self->{weekdaytxt},
                      'Vecka:', $self->{week},
                      'Datum:', $self->{date},
                      (
                       $self->{locked} ?
                          ' Tidbox är låst!'   :
                          ('Kl:',    join(':', $self->{hour}, $min, $sec))
                      ),
                 );
    for my $d (values(%{$self->{-display}})) {
      $d -> configure(-text => $t) if $d;
    } # for #
  } # if #

  return 0;
} # Method tick

#----------------------------------------------------------------------------
#
# Method:      getSecond
#
# Description: Get current second
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getSecond($) {
  # parameters
  my $self = shift;

  return $self->{second};
} # Method getSecond

#----------------------------------------------------------------------------
#
# Method:      getMinute
#
# Description: Get current minute
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getMinute($) {
  # parameters
  my $self = shift;

  return $self->{minute};
} # Method getMinute

#----------------------------------------------------------------------------
#
# Method:      getHour
#
# Description: Get current hour
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getHour($) {
  # parameters
  my $self = shift;

  return $self->{hour};
} # Method getHour

#----------------------------------------------------------------------------
#
# Method:      getDay
#
# Description: Get current day
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getDay($) {
  # parameters
  my $self = shift;

  return $self->{day};
} # Method getDay

#----------------------------------------------------------------------------
#
# Method:      getMonth
#
# Description: Get current month
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getMonth($) {
  # parameters
  my $self = shift;

  return $self->{month};
} # Method getMonth

#----------------------------------------------------------------------------
#
# Method:      getYear
#
# Description: Get current year
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getYear($) {
  # parameters
  my $self = shift;

  return $self->{year};
} # Method getYear

#----------------------------------------------------------------------------
#
# Method:      getTime
#
# Description: Get current time
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getTime($) {
  # parameters
  my $self = shift;

  return $self->{time};
} # Method getTime

#----------------------------------------------------------------------------
#
# Method:      getHHMMSS
#
# Description: Get current time HH:MM:SS
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getHHMMSS($) {
  # parameters
  my $self = shift;

  return $self->{time} . ':' . $self->{second};
} # Method getHHMMSS

#----------------------------------------------------------------------------
#
# Method:      getDate
#
# Description: Get current date
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getDate($) {
  # parameters
  my $self = shift;

  return $self->{date};
} # Method getDate

#----------------------------------------------------------------------------
#
# Method:      getWeek
#
# Description: Get number of current week
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getWeek($) {
  # parameters
  my $self = shift;

  return $self->{week};
} # Method getWeek

#----------------------------------------------------------------------------
#
# Method:      getWeekday
#
# Description: Get current week
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getWeekday($) {
  # parameters
  my $self = shift;

  return $self->{weekday};
} # Method getWeekday

#----------------------------------------------------------------------------
#
# Method:      getSystime
#
# Description: Get system time of last tick
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getSystime($) {
  # parameters
  my $self = shift;

  return $self->{systime};
} # Method getSystime

#----------------------------------------------------------------------------
#
# Method:      getSleep
#
# Description: Get sleep time in seconds
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getSleep($) {
  # parameters
  my $self = shift;

  return $self->{sleep};
} # Method getSleep

#----------------------------------------------------------------------------
#
# Method:      setLocked
#
# Description: Set session locked
#
# Arguments:
#  - Object reference
#  - Locked information
# Returns:
#  -

sub setLocked($$) {
  # parameters
  my $self = shift;
  my ($locked) = @_;

  $self->{locked} = $locked;
} # Method setLocked

#----------------------------------------------------------------------------
#
# Method:      quit
#
# Description: Stop sending of subscriptions
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub quit($) {
  # parameters
  my $self = shift;

  for my $key (keys(%{$self->{-repeat}})) {
    $self->{-repeat}{$key} = undef;
  } # for #
  for my $key (keys(%{$self->{-timeout}})) {
    @{$self->{-timeout}{$key}} = ();
  } # for #
  return 0;
} # Method quit

1;
__END__
