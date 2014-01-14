#
package TitleClock;
#
#   Document: Running clock for timing and visible clock
#   Version:  1.7   Created: 2013-05-27 19:35
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: TitleClock.pmx
#

my $VERSION = '1.7';
my $DATEVER = '2013-05-27';

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
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent TidBase;

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
# Object data
#
#  -calculate  Reference calculator
#
# Private data
#
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
#  weekdaytxt  Current day name       M�ndag .. S�ndag
#  locked      Session locked
#
#  -display    Hash with displays were the clock is displayed
#              'name' => Reference to Tk widget to display in
#  -repeat     Hash with running timers
#              -day     List of timers to run every midnight
#              -hour    List of timers to run once an new hour
#              -minute  List of timers to run once a minute

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
              date   => 0,
              hour   => 0,
              minute => 0,
             };

  bless($self, $class);

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      setDisplay
#
# Description: Set display for the clock
#
# Arguments:
#  0 - Object reference
#  1 - Name of the clock
#  2 - Widget were to display the clock
#      Disable this clock if not defined
# Returns:
#  -

sub setDisplay($$$) {
  # parameters
  my $self = shift;
  my ($name, $disp) = @_;

  $self->{-display}{$name} = $disp;
  return 0;
} # Method setDisplay

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


  my @wt = localtime(time);
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

      my $date = $self->{-calculate}->yyyyMmDd($wt[5], $wt[4]+1, $wt[3]);

      if ($date ne $self->{date}) {
        $self->{date} = $date;
        ($self->{year}, $self->{month}, $self->{day}) = split('-', $date);
        $self->{monthtxt}   = $self->{-calculate}->monthStr($self->{month});
        $self->{week}       = $self->{-calculate}->weekNumber($date);
        $self->{weekday}    = $wt[6];
        $self->{weekdaytxt} = $self->{-calculate}->dayStr($wt[6]);

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

  } # if #

  if ($self->{-display}) {
    my $t = join(' ',           $self->{weekdaytxt},
                      'Vecka:', $self->{week},
                      'Datum:', $self->{date},
                      (
                       $self->{locked} ?
                          ' Tidbox �r l�st!'   :
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

1;
__END__