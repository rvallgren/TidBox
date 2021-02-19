#
package Calculate;
#
#   Document: Calculator for TidBox
#   Version:  1.11   Created: 2019-09-27 17:46
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Calculate.pmx
#

my $VERSION = '1.11';
my $DATEVER = '2019-09-27';

# History information:
#
# 1.4  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
#      Corrected removal of short event after paus in _adjustOneDay
# 1.5  2008-04-15  Roland Vallgren
#      Corrected calculation of year in weekNumber
# 1.6  2008-09-07  Roland Vallgren
#      Get problems in adjust week before closing undo set
# 1.7  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.8  2009-07-08  Roland Vallgren
#      Improved regexp handling
# 1.9  2011-05-01  Roland Vallgren
#      Impacted handled ranges wrong
# 1.10  2017-10-16  Roland Vallgren
#       References to other objects in own hash
# 1.11  2019-08-29  Roland Vallgren
#       Code improvements: Do not use event from times directly
#       Correction of remove short events when workday is adjusted
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use integer;
use Carp;

use Time::Local;

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

# Times in seconds
use constant TWENTYFOURHOURS => 24 * 60 * 60;    # 86400 seconds

# Registration analysis constants
my $YEAR  = '\d{4}';
my $MONTH = '\d{2}';
my $DAY   = '\d{2}';
my $DATE = $YEAR . '-' . $MONTH . '-' . $DAY;

my $HOUR   = '\d{2}';
my $MINUTE = '\d{2}';
my $TIME   = $HOUR . ':' . $MINUTE;

my $TYPE = qr/[BEPW][AENOV][DEGRU][EIKNPS][ADEKNORSTUVW]*/;

# Event analysis constants
# Actions are choosen to be sorted alphabetically, sort 1, 2, 3, 4, 5, 6
# This only applies to actions registered on the same time and
# normally it is only when it is meaningful as time it is OK to do so
# Like this:
#   BEGINWORK should be befor any other action
#   ENDPAUS or ENDEVENT should be before EVENT or PAUS
#   WORKEND should be after any other
my $WORKDAYDESC         = 'Arbetsdagen';
my $WORKDAY             = 'WORK';
my $BEGINWORKDAY        = 'BEGINWORK';      # Sort 1
my $ENDWORKDAY          = 'WORKEND';        # Sort 6

my $PAUSDESC            = 'Paus';
my $BEGINPAUS           = 'PAUS';           # Sort 5
my $ENDPAUS             = 'ENDPAUS';        # Sort 3

my $EVENTDESC           = 'Händelse';
my $BEGINEVENT          = 'EVENT';          # Sort 4
my $ENDEVENT            = 'ENDEVENT';       # Sort 2

# Hash to store common texts
my %TEXT = (
             $BEGINWORKDAY => 'Börja arbetsdagen',
             $ENDWORKDAY   => 'Sluta arbetsdagen',

             $BEGINPAUS    => 'Börja paus',
             $ENDPAUS      => 'Sluta paus',

             $BEGINEVENT   => 'Börja händelse',
             $ENDEVENT     => 'Sluta händelse',
           );

# Event formatting
my $TXT_BEGIN       = ' började';
my $TXT_END         = ' slutade';

# Month weekday strings
my @WEEKDAYS = qw/Söndag Måndag Tisdag Onsdag Torsdag Fredag Lördag/;
my @MONTHS = qw/Januari Februari Mars April Maj Juni
                Juli Augusti September Oktober November December/;

#----------------------------------------------------------------------------
#
# Object data
#
#  -clock        Clock object
#  -event_cfg    Event configuration object
#  -times        Times data object

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
             };

  bless($self, $class);

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      dayStr
#
# Description: Return weekday string of weekday number
#
# Arguments:
#  0 - Object reference
#  1 - Weekday
# Returns:
#  Weekday string

sub dayStr($$) {
  # parameters
  my $self = shift;
  my ($d) = @_;

  return $WEEKDAYS[$d];
} # Method dayStr

#----------------------------------------------------------------------------
#
# Method:      monthStr
#
# Description: Return month name of month number
#
# Arguments:
#  0 - Object reference
#  1 - month
# Returns:
#  string

sub monthStr($$) {
  # parameters
  my $self = shift;
  my ($m) = @_;

  return $MONTHS[$m-1];
} # Method monthStr

#----------------------------------------------------------------------------
#
# Method:      yyyyMmDd
#
# Description: YYYY-MM-DD
#
# Arguments:
#  0 - Object reference
#  1 - Year
#  2 - Month
#  3 - Date
# Returns:
#  Date string: YYYY-MM-DD
#  undef if not valid date: 30th of february

sub yyyyMmDd($$$$) {
  # parameters
  my $self = shift;
  my ($y, $m, $d) = @_;

  $y = ($y < 1000 ? 1900 + $y : $y);
  eval { my $s = timelocal(1, 1, 1, $d, $m-1, $y)};
  return undef if $@;

  return $y . '-' .
         (length($m) < 2 ? '0'.$m : $m) . '-' .
         (length($d) < 2 ? '0'.$d : $d);
} # Method yyyyMmDd

#----------------------------------------------------------------------------
#
# Method:      _deltaMinutes
#
# Description: Calculate delta time in minutes between two times
#
# Arguments:
#  - Object reference
#  - Start time
#  - End time
# Returns:
#  Time between start and end in minutes

sub _deltaMinutes($$$) {
  # parameters
  my $self = shift;
  my ($start_time, $end_time) = @_;

  my ($end_hour,   $end_minute  ) = split(':', $end_time  );
  my ($start_hour, $start_minute) = split(':', $start_time);
  return ($end_hour - $start_hour) * 60 + $end_minute - $start_minute;
} # Method _deltaMinutes

#----------------------------------------------------------------------------
#
# Method:      stepTimeDate
#
# Description: Step date and time a number of seconds
#              If date or time not specified, use current date or time
#
# Arguments:
#  0 - Object reference
#  1 - Delta in seconds
# Optional arguments:
#  2 - Time
#  3 - Date
# Returns:
#  -

sub stepTimeDate($$;$$) {
  # parameters
  my $self = shift;
  my ($delta, $time, $date) = @_;


  my ($hour, $minu);
  if ($time) {
    ($hour, $minu) = split(':', $time);
  } else {
    $hour = $self->{erefs}{-clock}->getHour();
    $minu = $self->{erefs}{-clock}->getMinute();
  } # if #

  my ($year, $month, $day);
  if ($date) {
    ($year, $month, $day) = split('-', $date);
  } else {
      $year  = $self->{erefs}{-clock}->getYear() ;
      $month = $self->{erefs}{-clock}->getMonth();
      $day   = $self->{erefs}{-clock}->getDay()  ;
  } # if #

  # Carefully try if the date or time is valid
  my $t;
  eval { $t = timelocal(1, $minu, $hour, $day, $month-1, $year) };
  return undef if $@ or $t<0;
  eval { $t += $delta };
  return undef if $@ or $t<0;
  my @t;
  eval { @t = localtime($t) };
  return undef if $@;

  $time = ($t[2] < 10 ? '0'.$t[2] : $t[2]) . ':' .
          ($t[1] < 10 ? '0'.$t[1] : $t[1]);

  return $time unless wantarray();

  # ? Also calculate delta in years, days, hours, minutes, seconds
  $date = $self->yyyyMmDd($t[5], $t[4]+1, $t[3]);
  return ($time, $date);

} # Method stepTimeDate

#----------------------------------------------------------------------------
#
# Method:      stepDate
#
# Description: Step date a number of days
#              Default step one day forward
#
# Arguments:
#  0 - Object reference
#  1 - Date to step
# Optional Arguments:
#  2 - Number of days to step
# Returns:
#  Found date after step

sub stepDate($$;$) {
  # parameters
  my $self = shift;
  my ($date, $days) = @_;

  $days = 1 unless defined($days);
  # Use stepTimeDate for the extended exception handling
  (undef, $date) =
      $self->stepTimeDate((TWENTYFOURHOURS * $days), '1:1', $date);
  return $date;
} # Method stepDate

#----------------------------------------------------------------------------
#
# Method:      weekDay
#
# Description: Find out weekday from date
#
# Arguments:
#  0 - Object reference
#  1 - Date
# Returns:
#  weekday

sub weekDay($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  my ($year, $month, $day) = split('-', $date);
  my $system_time = timelocal(1, 1, 1, $day, $month-1, $year);
  my @wt = localtime($system_time);
  return $wt[6];
} # Method weekDay

#----------------------------------------------------------------------------
#
# Method:      weekNumber
#
# Description: Find out week number for given date
#
# Arguments:
#  0 - Object reference
#  1 - date
# Returns:
#  If array expected, year and week
#  week number

sub weekNumber($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  my ($year, $month, $day) = split('-', $date);
  my $st = timelocal(1, 1, 1, $day, $month-1, $year);
  my @wt = localtime($st);
  if ($wt[6] == 0) {
    $st -= 3 * TWENTYFOURHOURS;
  } else {
    $st += (4 - $wt[6]) * TWENTYFOURHOURS;
  } # if #
  @wt = localtime($st);
  return int($wt[7]/7 + 1)
    unless (wantarray());

  return (substr($self->yyyyMmDd($wt[5], $wt[4]+1, $wt[3]), 0, 4),
          int($wt[7]/7 + 1));

} # Method weekNumber

#----------------------------------------------------------------------------
#
# Method:      dayInWeek
#
# Description: Find out date for a day in week,
#              Same day as today unless a weekday is specified
#
# Arguments:
#  0 - Object reference
#  1 - Year of the week
#  2 - Number of week to find date of
# Optional arguments:
#  3 - Weekday in week
# Returns:
#  Date

sub dayInWeek($$$;$) {
  # parameters
  my $self = shift;
  my ($year, $week, $weekday) = @_;


  # Find out week number for first day of the year
  my $w1 = $self->weekNumber("$year-1-1");
  $week -= 1 if ($w1 == 1);   # Week started at end of previous year

  # Find out system time of specified week
  my $st = timelocal(1, 1, 1, 1, 0, $year) + $week * 7 * TWENTYFOURHOURS;
  my @wt = localtime($st);

  # Handle that week begins on Monday
  if ($wt[6] == 0) {
    $st -= 3 * TWENTYFOURHOURS;
  } else {
    $st += (4 - $wt[6]) * TWENTYFOURHOURS;
  } # if #

  # OK, now we have Thursday of specified week
  # If no weekday is specified use today of the week
  $weekday = $self->{erefs}{-clock}->getWeekday() unless (defined($weekday));

  # Sunday is last day in week
  $weekday = 7 unless ($weekday);
  $st += ($weekday - 4) * TWENTYFOURHOURS;

  @wt = localtime($st);

  return $self->yyyyMmDd($wt[5], $wt[4]+1, $wt[3]);
} # Method dayInWeek

#----------------------------------------------------------------------------
#
# Method:      hours
#
# Description: Calculate total time in minutes in hour and hundreths
#              Defauilt decimal separator is ','
#
# Arguments:
#  0 - Object reference
#  1 - Time in minutes
# Arguments:
#  2 - Decimal separator
# Returns:
#  hours,hundreths (padded with whitespace to 5 characters)

sub hours($$;$) {
  # parameters
  my $self = shift;
  my ($minutes, $separator) = @_;


  $separator = ',' unless $separator;
  return '0' . $separator . '00' unless $minutes;
  return 'minus' if $minutes < 0;
  my $hour  = int($minutes / 60);
  my $minut = $minutes % 60;
  my $frac  = int(($minut * 100) / 60);

  $frac  = '0' . $frac if (length($frac) < 2);
  return $hour . $separator . $frac;
} # Method hours

#----------------------------------------------------------------------------
#
# Method:      deltaHours
#
# Description: Calculate delta time in hours and hundreths between two times
#
# Arguments:
#  - Object reference
#  - Start time
#  - End time
# Returns:
#  Time between start and end in hours and hundreths

sub deltaHours($$$) {
  # parameters
  my $self = shift;
  my ($start_time, $end_time) = @_;

  return 
    $self->hours($self->_deltaMinutes($start_time, $end_time));
} # Method deltaHours

#----------------------------------------------------------------------------
#
# Method:      findYear
#
# Description: Find out year, add missing digits from this year.
#
# Arguments:
#  0 - Object reference
#  1 - Year to format
# Returns:
#  Year: YYYY

sub findYear($;$) {
  # parameters
  my $self = shift;
  my ($y) = @_;

  return $self->{erefs}{-clock}->getYear() unless defined($y);
  return substr($self->{erefs}{-clock}->getYear(), 0, 4-length($y)) . $y;
} # Method findYear

#----------------------------------------------------------------------------
#
# Method:      findWeekday
#
# Description: Find out day number from weekday text
#
# Arguments:
#  0 - Object reference
#  1 - String with weekday
# Returns:
#  undef : Not uniq weekday
#  1-7: Måndag .. Söndag

sub findWeekday($;$) {
  # parameters
  my $self = shift;
  my $d = qr/^\Q$_[0]/i;

  my $i=0;
  my @d;
  for my $day (@WEEKDAYS) {
    push @d, $i if ($day =~ $d);
    $i++;
  } # for #

  return undef if @d != 1;

  return 7 unless $d[0];
  return $d[0];
} # Method findWeekday

#----------------------------------------------------------------------------
#
# Method:      findMonth
#
# Description: Find out month number from month text
#
# Arguments:
#  0 - Object reference
#  1 - String with month
# Returns:
#  undef : Not a month
#  1-12: Januari .. December

sub findMonth($;$) {
  # parameters
  my $self = shift;
  my $m = qr/^\Q$_[0]/i;

  my $i=1;
  my @m;
  for my $mon (@MONTHS) {
    push @m, $i if ($mon =~ $m);
    $i++;
  } # for #

  return undef if @m != 1;

  return $m[0];
} # Method findMonth

#----------------------------------------------------------------------------
#
# Method:      impactedDate
#
# Description: Analyze if change in date impacts date or dates
#
# Arguments:
#  0 - Object reference
#  1 - One date or reference to array of dates
#  2 - Reference to modified dates array
# Returns:
#  -

sub impactedDate($$@) {
  # parameters
  my $self = shift;
  my ($check, @dates) = @_;


  return 0
      unless (@dates);

  if (ref($check)) {
    if ($dates[0] eq '-') {
      # Check if any part of the updated range is in the observed range
      return 1
          unless ($dates[2] le $check->[0] or
                  $check->[1] le $dates[1]);
      return 0;
    } # if #

    for my $date (@dates) {
      return 1
          if ($check->[0] le $date and $date le $check->[1]);
    } # for #

  } else {
    if ($dates[0] eq '-') {

      # This is a range of dates, check if edit is in the range
      return 1
          if ($dates[1] le $check and $check le $dates[2]);

    } else {

      for my $date (@dates) {
        return 1
          if ($check eq $date);
      } # for #

    } # if #
  } # if #

  return 0;
} # Method impactedDate

#----------------------------------------------------------------------------
#
# Method:      evalTimeDate
#
# Description: Evaluate entered date and time from user
#              An undefined date or time is ignored
#              An invalid entry is returned as undef
#
# Arguments:
#  0 - Object reference
#  1 - Reference to routine to show fault
#  2 - time
#  3 - date
# Returns:
#  (time, date)

sub evalTimeDate($;$$$) {
  # parameters
  my $self = shift;
  my ($show_fault, $time_info, $date_info) = @_;


  my ($time_res, $date_res);

  # Check date if wanted
  if (defined($date_info)) {
    $date_info =~ s/^\s+//o;
    $date_info =~ s/\s+$//o;
    $date_info = lc($date_info);

    if (length($date_info) == 0 or $date_info eq 'idag') {
      # No date given, use today
      $date_res = $self->{erefs}{-clock}->getDate();

    } elsif ($date_info eq 'igår') {
      # Yesterday
      $date_res = $self->stepDate($self->{erefs}{-clock}->getDate(), -1);

    } elsif ($date_info eq 'imorgon') {
      # Tomorrow
      $date_res = $self->stepDate($self->{erefs}{-clock}->getDate(), +1);

    } elsif ($date_info =~ /^(?:[1-9]|[0-2]\d|3[01])$/o) {
      # One or two digits, only a day in current month
      $date_res = $self
          -> yyyyMmDd(
                      $self->{erefs}{-clock}->getYear(),
                      $self->{erefs}{-clock}->getMonth(),
                      $date_info,
                     );

    } elsif ($date_info =~ /^
               (0?[1-9]|1[0-2])          # Month
               [-\s:,.\/]?               # Possible separator
               (0?[1-9]|[12]\d|3[01])    # Day in month
                           $/ox) {
      # More than two digits or separator, month and day
      $date_res = $self
          -> yyyyMmDd($self -> findYear(),
                      $1,
                      $2,
                     );

    } elsif ($date_info =~ /^
               (\d\d|\d{1,4})            # Year
               [-\s:,.\/]?               # Possible separator
               (0?[1-9]|1[0-2])          # Month
               [-\s:,.\/]?               # Possible separator
               (0?[1-9]|[12]\d|3[01])    # Day in month
                           $/ox) {
      $date_res = $self
          -> yyyyMmDd($self -> findYear($1), $2, $3);

    } elsif ($date_info =~ /^
               [wv]                      # Week ("w" is not swedish)
               (|\d|\d\d|\d{1,4})        # Possible year
               [-\s:,.\/]?               # Possible separator
               (0?[1-9]|[1-4]\d|5[0-3])  # Week number
               [-\s:,.\/]?               # Possible separator
               (|[mtofls][adeginorsåö]*) # Possible weekday in text
                           $/iox or
             $date_info =~ /^
               (\d{1,4})                 # Year
               [wv]                      # Week ("w" is not swedish)
               (0?[1-9]|[1-4]\d|5[0-3])  # Week number
               [-\s:,.\/]?               # Possible separator
               (|[mtofls][adeginorsåö]*) # Possible weekday in text
                           $/iox) {
      # Week number, optionally year and/or weekday
      my $year = $self -> findYear($1);
      my $w = $2;
      if (defined($3) and $3) {
        my $day = $self -> findWeekday($3);
        $date_res = $self -> dayInWeek($year, $w, $day)
            if $day;
      } else {
        $date_res = $self -> dayInWeek($year, $w);
      } # if #

    } elsif ($date_info =~ /^([mtofls][adeginorsåö]*)$/io) {
      # Weekday
      my $day = $self -> findWeekday($1);
      $date_res = $self
          -> dayInWeek(
                       $self->{erefs}{-clock}->getYear(),
                       $self->{erefs}{-clock}->getWeek(),
                       $day
                      )
          if $day;

    } elsif ($date_info =~ /^
               ([adfjmnos][abcegijklmnoprstuv]*)  # Month text
               [-\s:,.\/]?                        # Possible separator
               (0?[1-9]|[12]\d|3[01])             # Day in month
               $/iox) {
      # Month date
      my ($month, $date) = ($self -> findMonth($1), $2);
      $date_res = $self
          -> yyyyMmDd(
                      $self->{erefs}{-clock}->getYear(),
                      $month,
                      $date
                     )
          if $month;

    } elsif ($date_info =~ /^
               (\d{1,4})                         # Year
               [-\s:,.\/]?                       # Possible separator
               ([adfjmnos][abcegijklmnoprstuv]*) # Month
               [-\s:,.\/]?                       # Possible separator
               (0?[1-9]|[12]\d|3[01])            # Day
                           $/iox) {
      my ($year, $month, $date) = ($1, $self -> findMonth($2), $3);
      $date_res = $self -> yyyyMmDd($self -> findYear($year), $month, $date)
          if $month;

    } # if #
    unless ($date_res) {
      $self->callback($show_fault, 'Ogiltigt datum: ' . $date_info);
      return (undef, undef);
    } # unless #

  } # if #

  # Check time if wanted
  if (defined($time_info)) {
    $time_info =~ s/^\s+//o;
    $time_info =~ s/\s+$//o;

    if (length($time_info) == 0) {
      # No time, use current time
      $time_res = $self->{erefs}{-clock}->getTime(),

    } elsif ($time_info =~ /^
               ([01]?\d|2[0-3]|)[\s:.\/]?([0-5]?\d)   # hours, minutes
               ([-+])                                 # delta
               (\d{1,2}[\s:,.\/]|)(\d+)               # [hours,] minutes
                           $/ox) {
      # Time and Delta time

      # Digits and possibly a separator and delta time
      $time_res = '0' . $1 . ':' . '0' . $2;

      # Delta time
      my $delta_sec = $5;
      if (not $4 or (substr($4, -1) ne ',' and substr($4, -1) ne '.')) {
        # Minutes
        $delta_sec *= 60;
        $delta_sec += substr($4, 0, -1) * (60 * 60) if $4;
      } else {
        # Hours and decimals of hours
        $delta_sec *= 10 if (length($delta_sec) == 1);
        $delta_sec *= 36;
        $delta_sec += substr($4, 0, -1) * (60 * 60);
      } # if #
      $delta_sec  = -$delta_sec    if $3 eq '-';

      if ($date_res) {
        ($time_res, $date_res) =
             $self->stepTimeDate($delta_sec, $time_res, $date_res);
      } else {
        $time_res = $self->stepTimeDate($delta_sec, $time_res);
      } # if #

    } elsif ($time_info =~ /^
               ([-+])                     # delta
               (\d{1,2}[\s:,.\/]|)(\d+)   # [hours,] minutes
                           $/ox) {
      # Delta time
      my $delta_sec = $3;
      if (not $2 or (substr($2, -1) ne ',' and substr($2, -1) ne '.')) {
        $delta_sec *= 60;
        $delta_sec   += substr($2, 0, -1) * (60 * 60) if $2;
      } else {
        # Hours and decimals of hours
        $delta_sec *= 10 if (length($delta_sec) == 1);
        $delta_sec *= 36;
        $delta_sec += substr($2, 0, -1) * (60 * 60);
      } # if #
      $delta_sec    = -$delta_sec    if $1 eq '-';

      if ($date_res) {
        ($time_res, $date_res) =
             $self -> stepTimeDate($delta_sec, undef, $date_res);
      } else {
        $time_res =
             $self -> stepTimeDate($delta_sec);
      } # if #

    } elsif ($time_info =~ /^([01]?\d|2[0-3]|)[ :,.\/]?([0-5]?\d)$/o) {
      # Digits and possibly a separator
      my $h = ($1 ? $1 : 0);
      $time_res = (length($h) < 2 ? '0'.$h : $h) . ':' .
                  (length($2) < 2 ? '0'.$2 : $2);

    } # if #
    unless ($time_res) {
      $self->callback($show_fault, 'Ogiltig tid: ' . $time_info);
      return (undef, undef);
    } # unless #
  } # if #

  return ($time_res, $date_res);
} # Method evalTimeDate

#----------------------------------------------------------------------------
#
# Method:      format
#
# Description: Formats a registration record for presentation
#
# Arguments:
#  0 - Object reference
#  1 - The record to format or date or undef
# Optional arguments:
#  2 - Time
#  3 - Type
#  4 - Text
# Returns:
#  Formatted record

sub format($$;$$$) {
  # parameters
  my $self = shift;
  my ($record, $time, $type, $desc) = @_;

  my $line = "";
  my $text;
  if ($time and $time eq ':') {
    return '(Ingenting registrerat hittills idag.)';
  } elsif ($record and $record =~
           /^($DATE),($TIME),($TYPE),(.*)$/o) {
    $line = $1 . ' ';
    $time = $2;
    $type = $3;
    $desc = $TEXT{$3};
    $text = $4;
  } elsif (defined($type)) {
    $line = $record . ' ' if (defined($record));
    if ($type eq $BEGINEVENT) {
      $desc = $EVENTDESC unless ($desc);
    } elsif ($type eq $ENDEVENT) {
      $desc = $EVENTDESC;
    } elsif ($type =~ /$BEGINPAUS/o) {
      $desc = $PAUSDESC unless ($text);
    } elsif ($type =~ /$WORKDAY/o) {
      $desc = $WORKDAYDESC;
    } # if #
    if ($type =~ /END/o) {
      $desc .= $TXT_END;
    } else {
      $desc .= $TXT_BEGIN;
    } # if #
  } # if #
  $line .= $time if(defined($time));
  $line .= '    ' . $desc if(defined($desc));
  if (($type eq $BEGINEVENT) and defined($text)) {
    $line .= '  ' . $text unless $text eq $EVENTDESC;
  } # if #
  $line =~ s/\s+$//;

  return $line;
} # Method format

#----------------------------------------------------------------------------
#
# Method:      dayWorkTimes
#
# Description: Calculate times for the activities during a day
#
# Arguments:
#  0 - Object reference
#  1 - Date to calculate for
#  2 - Condensed setting
# Optional Arguments:
#  3 - Callback for detected problems
#  4 - Reference to week events hash
#  5 - Reference to week comments hash
#  6 - Reference to week week comment length hash
# Returns:
#  Reference to day hash
#    time            System time for the day
#    date            Date for the day
#    paus_time       Paus time during the workday
#    events          Events hash      ???
#                       event      Time for the event
#    activities      Activities hash
#                       activity   Time for the activity
#    event_number    Number of events ???
#    event_time      Time for events  ???
#    whole_time      Whole registered time of the day, work time and paus time
#    work_time       Work time
#    not_event_time  Work time that is not event time
#    event_max       Max length of event text
#    comment_max     Max length of event comments
#
#    state           State of the day after calculation
#    ERROR           If not zero: Problems were detected in calculation

sub dayWorkTimes($$$;$$$$) {
  # parameters
  my $self = shift;
  my ($date, $condensed, $problem,
      $week_events_r, $week_comments_r, $week_com_length_r) = @_;

  # local constants

  # States of workday
  use constant BEFOREWORK   => 0;
  use constant WORK         => 1;
  use constant EVENT        => 2;
  use constant PAUS         => 3;
  use constant AFTERWORK    => 4;


  # Initiate data for the day
  my $day_r = {
               event_number   => 1,    # Event and activity handling
               events         => {},
               activities     => {},
               whole_time     => 0,    # Whole time of day, including breaks
               work_time      => 0,    # Work hours
               event_time     => 0,    # Activity hours
               not_event_time => 0,    # Other time not registered as activity
               paus_time      => 0,    # Time for breaks
               date           => $date,
               ERROR          => 0,    # Counts problems detected
              };

  # Intialize max comment lengths
  my $match_string = $self->{erefs}{-event_cfg}->matchString($condensed, $date);

  # Default shortest event text length
  my $event_text_max_length = 0;
  my $comment_text_max_length = 0;

  # Intialize calculations
  my $state = BEFOREWORK;
  my $begin_time;
  my $end_time;
  my ($time, $typ, $txt);
  my ($paus_begin_time, $paus_time);
  my ($event_begin_time, $event_time, $event_text);

  # Get time artifacts from registered time
  my $times = $self->{erefs}{-times}->getSortedRegistrationsForDate($date);
  for my $ref (@$times) {
    $time = $ref->{time};
    $typ  = $ref->{type};
    $txt  = $ref->{text};

    if ($state == BEFOREWORK) {

      # Probably start of workday
      $begin_time = $time;
      if ($typ eq $BEGINWORKDAY or
          $typ eq $ENDPAUS) {
        $state = WORK;
      } elsif ($typ eq $BEGINPAUS) {
        $paus_begin_time = $time;
        $state = PAUS;
      } elsif ($typ eq $BEGINEVENT) {
        $event_begin_time = $time;
        if ($txt) {
          $event_text = $txt;
        } else {
          $event_text = $EVENTDESC . $day_r->{event_number};
          $day_r->{event_number}++;
        } # if #
        $state = EVENT;
      } elsif ($typ eq $ENDEVENT) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Händelse slutar utom arbetstid.");
      } elsif ($typ eq $ENDWORKDAY) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Arbetsdagen slutar utan att ha börjat.");
      } # if #

    } elsif ($state == WORK) {

      # Workday ongoing
      if ($typ eq $BEGINWORKDAY) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Arbetsdagen börjar igen.");
      } elsif ($typ eq $BEGINPAUS) {
        $paus_begin_time = $time;
        $state = PAUS;
      } elsif ($typ eq $ENDPAUS) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Paus slutar utan början.");
      } elsif ($typ eq $BEGINEVENT) {
         $event_begin_time = $time;
        if ($txt) {
          $event_text = $txt;
        } else {
          $event_text = $EVENTDESC . $day_r->{event_number};
          $day_r->{event_number}++;
        } # if #
        $state = EVENT;
      } elsif ($typ eq $ENDEVENT) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Händelse slutar utan början.");
      } elsif ($typ eq $ENDWORKDAY) {
        $state = AFTERWORK;
        $end_time = $time;
      } # if #

    } elsif ($state == EVENT) {

      # Event ongoing
      if ($typ eq $BEGINWORKDAY) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Arbetsdagen börjar under en händelse.");
      } elsif (($typ eq $BEGINPAUS)  or
               ($typ eq $BEGINEVENT) or
               ($typ eq $ENDEVENT)   or
               ($typ eq $ENDWORKDAY)) {
        $event_time = $self->_deltaMinutes($event_begin_time, $time);
        $day_r->{events}{$event_text} += $event_time;
        if ($event_text =~ /$match_string/) {
          $day_r->{activities}{$1} += $event_time;
          if ($week_comments_r) {
            if ($condensed and not exists($week_comments_r->{$1}{$2})) {
              $week_comments_r->{$1}{$2} = 1;
              $week_com_length_r->{$1} += length($2) + 2;
              $comment_text_max_length = $week_com_length_r->{$1}
                  if($comment_text_max_length < $week_com_length_r->{$1});
            } # if #
          } # if #
          if ($condensed) {
            $event_text_max_length = length($1)
                if (length($1) > $event_text_max_length);
          } elsif (length($event_text) > $event_text_max_length) {
            $event_text_max_length = length($event_text);
          } # if #
        } elsif (length($event_text) > $event_text_max_length) {
          $event_text_max_length = length($event_text);
        } # if #

        $week_events_r->{$event_text} += $event_time if $week_events_r;
        $day_r->{event_time} += $event_time;

        if ($typ eq $BEGINPAUS) {
          $paus_begin_time = $time;
          $state = PAUS;
        } elsif ($typ eq $BEGINEVENT) {
          $event_begin_time = $time;
          if ($txt) {
            $event_text = $txt;
          } else {
            $event_text = $EVENTDESC . $day_r->{event_number};
            $day_r->{event_number}++;
          } # if #
          $state = EVENT;
        } elsif ($typ eq $ENDEVENT) {
          $state = WORK;
        } elsif ($typ eq $ENDWORKDAY) {
          $state = AFTERWORK;
          $end_time = $time;
        } # if #

      } elsif ($typ eq $ENDPAUS) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Händelse slutar med slut på paus.");
      } # if #


    } elsif ($state == PAUS) {

      # Paus ongoing
      if ($typ eq $BEGINWORKDAY) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Arbetsdagen börjar under en paus.");
      } elsif ($typ eq $BEGINPAUS) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Paus börjar igen.");
      } elsif ($typ eq $ENDPAUS) {
        $day_r->{paus_time} += $self->_deltaMinutes($paus_begin_time, $time);
        $state = WORK;
      } elsif ($typ eq $BEGINEVENT) {
        $day_r->{paus_time} += $self->_deltaMinutes($paus_begin_time, $time);
        $event_begin_time = $time;
        if ($txt) {
          $event_text = $txt;
        } else {
          $event_text = $EVENTDESC . $day_r->{event_number};
          $day_r->{event_number}++;
        } # if #
        $state = EVENT;
      } elsif ($typ eq $ENDEVENT) {
        $day_r->{ERROR}++;
        $self->callback($problem,
               "$date $time Paus slutar med slut på händelse.");
      } elsif ($typ eq $ENDWORKDAY) {
        $day_r->{paus_time} += $self->_deltaMinutes($paus_begin_time, $time);
        $state = AFTERWORK;
        $end_time = $time;
      } # if #

    } elsif ($state == AFTERWORK) {

      # Workday is over, nothing more might happen
      $day_r->{ERROR}++;
      $self->callback($problem,
               "$date: Något är registrerat efter arbetsdagens slut?");


    } # if #
  } # for #

  if ($state != BEFOREWORK) {
    # If end of day not is set and today, set end of day now
    unless ($end_time) {
      if ($date eq $self->{erefs}{-clock}->getDate()) {
        $end_time = $self->{erefs}{-clock}->getTime();
      } else {
        $end_time = $time;
        # Consider last event to be end of workday
        # This does not work on today
        $state = AFTERWORK;
      } # if #
    } # unless #

    # Calculate worktime
    if ($state == PAUS) {

      $day_r->{paus_time} += $self->_deltaMinutes($paus_begin_time, $time);

    } elsif ($state == EVENT) {

      $event_time = $self->_deltaMinutes($event_begin_time, $end_time);
      $day_r->{events}{$event_text} += $event_time;
      if ($event_text =~ /$match_string/) {
        $day_r->{activities}{$1} += $event_time;
        if ($week_comments_r) {
          if ($condensed and not exists($week_comments_r->{$1}{$2})) {
            $week_comments_r->{$1}{$2} = 1;
            $week_com_length_r->{$1} += length($2) + 2;
            $comment_text_max_length = $week_com_length_r->{$1}
              if($comment_text_max_length < $week_com_length_r->{$1});
          } # if #
        } # if #
          if ($event_text =~ /$match_string/) {
            if ($condensed) {
              $event_text_max_length = length($1)
                  if (length($1) > $event_text_max_length);
            } elsif (length($event_text) > $event_text_max_length) {
              $event_text_max_length = length($event_text);
            } # if #
          } elsif (length($event_text) > $event_text_max_length) {
            $event_text_max_length = length($event_text);
          } # if #
      } elsif(length($event_text) > $event_text_max_length) {
        $event_text_max_length = length($event_text);
      } # if #
      $week_events_r->{$event_text} += $event_time if $week_events_r;
      $day_r->{event_time} += $event_time;

    } # if #

    $day_r->{whole_time} = $self->_deltaMinutes($begin_time, $end_time);

    $day_r->{work_time} = $day_r->{whole_time} - $day_r->{paus_time};
    $day_r->{not_event_time} = $day_r->{work_time} - $day_r->{event_time};

  } # if #

  # Keep max lengths and las state of the day
  $day_r->{event_max} = $event_text_max_length;
  $day_r->{comment_max} = $comment_text_max_length;
  $day_r->{state} = $state;


  return $day_r;
} # Method dayWorkTimes

#----------------------------------------------------------------------------
#
# Method:      weekWorkTimes
#
# Description: Calculate worktimes for whole week
#
# Arguments:
#  0 - Object reference
#  1 - Date to calculate for
#  2 - Condense setting
# Optional Arguments:
#  3 - Callback for detected problems
#  4 - Reference to week events hash
#  5 - Reference to week comments hash
#  6 - Reference to week week comment length hash
# Returns:
#  Reference to hash with time artifacts

sub weekWorkTimes($$$;$$$$) {
  # parameters
  my $self = shift;
  my ($date, $condense, $problem,
      $week_events_r, $week_comments_r, $week_com_length_r) = @_;

  my ($year, $month, $day) = split('-', $date);
  my @wt = localtime(timelocal(1, 1, 1, $day, $month-1, $year));

  if($wt[6] > 1) {
    $date = $self->stepDate($date, - ($wt[6] - 1));
  } elsif ($wt[6] == 0) {
    $date = $self->stepDate($date, -6);
  } # if #

  # Default shortest event text length
  my $event_text_max_length = 12;
  $event_text_max_length = 10
      if ($condense);
  my $comment_text_max_length = 0;

  my $total_time = 0;
  my ($day_r, @weekdays);

  for my $i (0..6) {

    $day_r =
        $self->dayWorkTimes($date,
                            $condense,
                            $problem,
                            $week_events_r,
                            $week_comments_r,
                            $week_com_length_r);

    $weekdays[$i] = $day_r;

    $event_text_max_length = $day_r->{event_max}
        if ($event_text_max_length < $day_r->{event_max});

    $comment_text_max_length = $day_r->{comment_max}
        if ($comment_text_max_length < $day_r->{comment_max});

    $total_time += $day_r->{work_time}
        if exists($day_r->{work_time});

    $date = $self->stepDate($date, 1);

    last unless $date;

  } # for #

  return (\@weekdays, $event_text_max_length, $comment_text_max_length)
      if wantarray();
  return $total_time;
} # Method weekWorkTimes

#----------------------------------------------------------------------------
#
# Method:      _adjustEvent
#
# Description: Adjust time for an event
#              Fails if change would cause step into another date
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event to change
#  2 - Delta time in minutes
# Optional Arguments:
#  3 - Callback for detected problems
# Returns:
#  New time for the event
#  undef if no change is made due to date problem

sub _adjustEvent($$$;$) {
  # parameters
  my $self = shift;
  my ($ref, $step, $problem) = @_;

  my $new = $$ref;
  return substr($new, 11, 5) unless ($step);
  my $date = substr($new, 0, 10);
  my ($new_time, $new_date) =
      $self -> stepTimeDate($step * 60, substr($new, 11, 5), $date);
  if ($new_date ne $date) {
    $self->callback($problem,
           "Problem med midnatt för $date, justering avbröts.");
    return undef;
  } # if #
  substr($new, 11, 5) = $new_time;
  $self->{erefs}{-times}->change($ref, $new);
  return $new_time;
} # Method _adjustEvent

#----------------------------------------------------------------------------
#
# Method:      _adjustOneDay
#
# Description: Adjust work times during a day to whole tenths of an hour
#              First the end of the work day is moved forward to get the whole
#              ADJUST_LEV : Number of minutes to adjust to (CFG?)
#              TO_SHORT   : Remove events with shorter worktime
#
# TODO
# Improvement ideas: - It should be possible to adjust the worktime on the
#                      fly. When an event is adjusted, the number of minutes
#                      is known, and can be added or removed from the
#                      impacted work time on next event
#                    - We should actually find out removal candidates before
#                      any changes are made, to avoid shorting one event and
#                      then removing it
#
# Arguments:
#  0 - Object reference
#  1 - Date to adjust
#  2 - Adjust level
# Optional Arguments:
#  3 - Callback for detected problems
# Returns:
#  0 - 0: Success
#      1: Failed: Something is wrong with the day, not adjusting tried
#      2: Failed: Had to terminate adjusting for some reason
#  1 - Number of changed events
#  2 - Number of removed events

sub _adjustOneDay($$$;$) {
  # parameters
  my $self = shift;
  my ($date, $adjust, $problem) = @_;

  # Get references to all events, sorted by time, this day
  my $times = $self->{erefs}{-times}->getSortedRegistrationsForDate($date);

  # Skip end of the workday
  if (@$times == 1) {
    $self->callback($problem,
           "Endast en händelse för $date, kan inte justera");
    return (1, 0, 0);
  } # if #
  my @refs = reverse(@$times);
  shift @refs;

  # Initialize
  my $to_short = $adjust;   # Remove events that are to short
  my $condensed = 0;

  my $chgd = 0;
  my $rmvd = 0;

  my $changed = 1;   # Force recalculation the first time

  my %adjusted;   # Only adjust an event one time
  my ($frac, $time, $step, $prev_time, $new_time);
  my $day_r;
  my (%short, $short_cnt);

  # From end of day, adjust work times that have fraction
  while (@refs) {
    my $r = shift(@refs);
    # Recalculate worktime if something was changed in last loop
    if ($changed) {
      $day_r = $self->dayWorkTimes($date, $condensed, $problem);

      # Problems during calculation or no acceptable end detected
      return (1, $chgd, $rmvd)
          if ($day_r->{ERROR});
      if (($day_r->{state} == EVENT) or ($day_r->{state} == WORK)) {
        $self->callback($problem,
               "Arbetstid pågår fortfarande för idag, kan inte justera");
        return (1, $chgd, $rmvd);
      } # if #

      # Workday to short, can not adjust
      if ($day_r->{work_time} and $day_r->{work_time} < $to_short) {
        $self->callback($problem,
               "Det finns för lite arbetstid för $date, kan inte justera");
        return (1, $chgd, $rmvd);
      } # if #

      # Register any short events that should be removed
      unless (defined($short_cnt)) {
        $short_cnt = 0;
        while (my ($key, $val) = each(%{$day_r->{events}})) {
          next
              if $val >= $to_short;
          $short_cnt++;
          $short{$key} = 1;
        } # while #
      } # unless #

      $changed = 0;
    } # if #


    # Skip paus not impacting worktime
    next if ($r->{type} eq $BEGINPAUS);

    # Find worktime for the event
    if ($r->{text}) {
      $time = $day_r->{events}{$r->{text}};
    } else {
      next
          unless ($day_r->{not_event_time});
      $time = $day_r->{not_event_time};
    } # if #


    # If negative time detected, end this try as something fishy is going on
    if ($time < 0) {
      $self->callback($problem, "Negativ tid för $date $r->{text}");
      return (2, $chgd, $rmvd);
    } # if #

    # Remove If not first event of the day and event time is to short
    if (@refs) {
      if (($r->{text} and exists($short{$r->{text}})) or      # Known to short event
          (not $r->{text} and ($time < $to_short))    # Other, and not beginning of day
         )
      {
        $self->{erefs}{-times}->change($r->{ref});
        $rmvd++;
        $changed = 1;

        # If previous is pause move the beginning of the pause
        # to include the removed time
        if ($time and
            ($refs[0]{type} eq $BEGINPAUS)
           ) {
          $step = ($refs[0]{type} eq $BEGINPAUS) ? $time : $time - $to_short;
          $new_time = $self->_adjustEvent($refs[0]->{ref}, $step, $problem);
          return (2, $chgd, $rmvd) unless $new_time;
          shift(@refs);
          $chgd++;
        } # if #
        next;
      } # if #
    } # if #

    # Find out fraction and skip if no fraction
    $frac = $time % $adjust;
    next if $frac == 0;

    # Find out how much backwards the time for the event should be adjusted
    # $frac is less than $adjust, hence negative step
    $step = $frac - $adjust;

    # Adjust the worktime
    $new_time = $self->_adjustEvent($r->{ref}, $step, $problem);
    return (2, $chgd, $rmvd) unless $new_time;
    $chgd++;
    $changed = 1;
    $adjusted{$r->{text}} = 1
        if $r->{text};

    # Adjust any events that might have been overtaken by this change
    $prev_time = $r->{time};

    # Here take actions if a change caused one event to step onto
    # or over another event
    # We also move beginning of pause if end of pause was moved
    # That way the length of the pause will not be changed
    # Events on the same time as last changed will be moved with it

    for $r (@refs) {
      # If paus or already adjusted or on same time,
      #    Adjust as much as last adjust
      # Paus should be adjusted to avoid that the length of the workday is
      #   increased
      if (($r->{type} eq $BEGINPAUS) or
          ($r->{text} and $adjusted{$r->{text}}) or
          ($prev_time eq $r->{time}))
      {
        $prev_time = $r->{time};
        $new_time = $self->_adjustEvent($r->{ref}, $step, $problem);
        return (2, $chgd, $rmvd) unless $new_time;
        $chgd++;
        $changed = 1;
        next;
      } # if #

      # We are done if time is before the last adjusted time
      last if $r->{time} lt $new_time;

      # Adjust as much as needed to keep order
      $step = -$self->_deltaMinutes($new_time, $r->{time});

      # Keep events separated in time to make sure the order not is changed
      $step--
          if ($r->{type} eq $BEGINEVENT);

      # 0 minutes is no change
      next
          unless ($step);

      $new_time = $self->_adjustEvent($r->{ref}, $step, $problem);
      return (2, $chgd, $rmvd) unless $new_time;
      $chgd++;
      $changed = 1;

    } # for #

  } # for #

  return (0, $chgd, $rmvd);
} # Method _adjustOneDay

#----------------------------------------------------------------------------
#
# Method:      adjustDays
#
# Description: Adjust work times during of days to whole tenths of an hour
#              First the end of the work day is moved forward to get the whole
#              working hours adjusted
#
# Arguments:
#  0 - Object reference
#  1 - Date of first day to adjust
#  2 - Adjust level
# Optional Arguments:
#  3 - Number of days to adjust
#  4 - Callback for detected problems
# Returns:
#  0 - 0: Success
#      1: Failed: Something is wrong with the day, not adjusting tried
#      2: Failed: Had to terminate adjusting for some reason
#  1 - Number of changed events
#  2 - Number of removed events
#  3 - String with problems detected

sub adjustDays($$$;$$) {
  # parameters
  my $self = shift;
  my ($start_date, $adjust, $days, $problem) = @_;


  # Setup an undo set for day times adjust
  $self->{erefs}{-times}->undoSetBegin();

  # Adjust all days, as long as no problems are encountered
  my ($chgd, $rmvd) = (0, 0);
  my $result = 0;
  my $date = $start_date;
  $days = 1 unless $days;
  while ($days) {
    my ($rs, $ch, $rm) = $self->_adjustOneDay($date, $adjust, $problem);
    $result = $rs;
    last
        if ($rs);
    $chgd += $ch;
    $rmvd += $rm;
    $date = $self->stepDate($date);
    $days--;
  } # while #

  # End the undo set depending on result
  my $str = 'Period ' . $start_date . ' - ' . $date;
  $str   .= "\nTid ändrad för " . $chgd . ' händelser'
      if $chgd;
  $str   .= "\n" . $rmvd . ' korta händelser borttagna'
      if $rmvd;
  $self->callback($problem, $str);

  my $prb = join("\n", @{$self->callback($problem)});

  $str = 'Försök att justera tid avbröts för ' . $date . "\n" . $str
      if $result;

  if ($chgd or $rmvd) {
    $self->{erefs}{-times} ->
        undoSetEnd('justering av arbetstid:,' . $str);
  } else {
    $self->{erefs}{-times} ->
        undoSetEnd('inga justeringar gjordes:,' . $str);
  } # if #

  return ($result, $chgd, $rmvd, $prb);
} # Method adjustDays

1;
__END__
