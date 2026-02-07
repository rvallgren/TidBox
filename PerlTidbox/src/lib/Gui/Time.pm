#
package Gui::Time;
#
#   Document: Time entry area
#   Version:  1.9   Created: 2026-02-01 19:08
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Time.pmx
#

my $VERSION = '1.9';
my $DATEVER = '2026-02-01';

# History information:
#
# 1.5  2011-03-31  Roland Vallgren
#      New method quit
# 1.6  2016-01-27  Roland Vallgren
#      Default action of <Return> in a field is to reevaluate the information
# 1.7  2017-10-16  Roland Vallgren
#      References to other objects in own hash
# 1.8  2019-05-14  Roland Vallgren
#      Keys bound to actions in entries
# 1.9  2023-12-22  Roland Vallgren
#      <shift - return> adds event, <Escape> clears time
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

use Tk;

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

use constant ONEMINUTE       =>  60;                   # seconds
use constant ONEHOUR         =>  60 * ONEMINUTE;       # 3600 seconds
use constant TWENTYFOURHOURS =>  24 * ONEHOUR;         # 86400 seconds
use constant ONEWEEK         =>   7 * TWENTYFOURHOURS; # 604800 seconds
use constant ONEMONTH        =>  30 * TWENTYFOURHOURS;
use constant ONEYEAR         => 365 * TWENTYFOURHOURS;

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create a time and date entry area
#
# Arguments:
#  0 - Object prototype
#  -area       Reference to parent frame
#  -pack_side  Side to pack, default top
#  -calculate  Reference calculator
#  -time       Create time if exists, return callback if reference
#  -date       Create date if exists, return callback if reference
#  -week       Create week if exists, return callback if reference
#  -invalid    Routine to call when invalid time or date is detected
#  -notify     Routine to call when the time or date is modified
#  -label      Label for the time entry
#  -max_date   Max allowed date
#  -min_date   Min allowed date
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;
  my %opt = @_;

  my $win_r = {area => $opt{-area}};

  $win_r->{time_area} = $win_r->{area}
      -> Frame()
      -> pack(-side => $opt{-pack_side} || 'top',
              -fill => 'both');

  my $self = {
              win        => $win_r,
             };

  for my $k ('erefs', '-invalid', '-current', '-notify',
             '-max_date', '-min_date') {
    $self->{$k} = $opt{$k}
        if exists($opt{$k});
  } # for #

  if ($opt{-date}) {
    $opt{-label} = 'Datum:' unless $opt{-label};
    $win_r->{date_label} = $win_r->{time_area}
        -> Label(-text => $opt{-label})
        -> pack(-side => 'left');
    $win_r->{date_data} = $win_r->{time_area}
        -> Entry(-width => '11')
        -> pack(-side => 'left');
    $win_r->{date_data}->bind('<Return>' => [$self => '_date']);
    $win_r->{date_data}->bind('<Escape>' => [$self => 'clear']);
    if ($opt{-week}) {
      $win_r->{date_data}->bind('<Control-w>' => [$self => '_week']);
      $self->{-week} = $opt{-week};
    } # if #
    $win_r->{date_data}->bind('<Up>'   =>[$self=>'_posStep', 'D']);
    $win_r->{date_data}->bind('<Down>' =>[$self=>'_posStep', 'd']);
    $win_r->{date_data}->bind('<Control-n>'=>[$self=>'_step', TWENTYFOURHOURS]);
    $win_r->{date_data}->bind('<Control-p>'=>[$self=>'_step',-TWENTYFOURHOURS]);
    $win_r->{date_data}->bind('<Shift-Up>'   => [$self => '_step', ONEWEEK]);
    $win_r->{date_data}->bind('<Shift-Down>' => [$self => '_step', -ONEWEEK]);
    $self->{-date} = $opt{-date};
    $win_r->{date_data}
        -> configure(-validate => 'key',
                     -validatecommand => [$self => '_notify'])
        if ($opt{-notify});

  } elsif ($opt{-week}) {
    $opt{-label} = 'Vecka:' unless $opt{-label};
    $win_r->{week_label} = $win_r->{time_area}
        -> Label(-text => $opt{-label})
        -> pack(-side => 'left');
    $win_r->{week_data} = $win_r->{time_area}
        -> Entry(-width => '10')
        -> pack(-side => 'left');
    $win_r->{week_data}->bind('<Return>' => [$self => '_week']);
    $win_r->{week_data}->bind('<Escape>' => [$self => 'clear']);
    $win_r->{week_data}->bind('<Up>'   => [$self => '_step', ONEWEEK]);
    $win_r->{week_data}->bind('<Down>' => [$self => '_step', -ONEWEEK]);
    $win_r->{week_data}->bind('<Control-n>' => [$self => '_step', ONEWEEK]);
    $win_r->{week_data}->bind('<Control-p>' => [$self => '_step', -ONEWEEK]);
    $self->{-week} = $opt{-week};
    $win_r->{week_data}
        -> configure(-validate => 'key',
                     -validatecommand => [$self => '_notify'])
        if ($opt{-notify});
  } # if #

  if ($opt{-time}) {
    $win_r->{time_label} = $win_r->{time_area}
        -> Label(-text => 'Tid:')
        -> pack(-side => 'left');
    $win_r->{time_data} = $win_r->{time_area}
        -> Entry(-width => '10')
        -> pack(-side => 'left');
    $win_r->{time_data}->bind('<Return>'  => [$self => '_time']);
    $win_r->{time_data}->bind('<Shift-Return>'  => [$self => '_time', 2]);
    $win_r->{time_data}->bind('<Escape>' => [$self => 'clear']);
    $win_r->{time_data}->bind('<Shift-equal>' => [$self => '_step', 0]);
    $win_r->{time_data}->bind('<equal>'       => [$self => '_step', 0]);
    $win_r->{time_data}->bind('<Up>'   =>[$self=>'_posStep', 'T']);
    $win_r->{time_data}->bind('<Down>' =>[$self=>'_posStep', 't']);
    $win_r->{time_data}->bind('<Control-n>' => [$self => '_step', ONEMINUTE]);
    $win_r->{time_data}->bind('<Control-p>' => [$self => '_step', -ONEMINUTE]);
    $win_r->{time_data}->bind('<Control-Up>'  =>[$self=>'_step', 10*ONEMINUTE]);
    $win_r->{time_data}->bind('<Control-Down>'=>[$self=>'_step',-10*ONEMINUTE]);
    $win_r->{time_data}->bind('<Shift-Up>'   => [$self => '_step', ONEHOUR]);
    $win_r->{time_data}->bind('<Shift-Down>' => [$self => '_step', -ONEHOUR]);
    $win_r->{time_data}->bind('<Shift-Control-Up>'
                                             => [$self => '_step', 10*ONEHOUR]);
    $win_r->{time_data}->bind('<Shift-Control-Down>'
                                             => [$self => '_step',-10*ONEHOUR]);
    $self->{-time} = $opt{-time};
    $win_r->{time_data}
        -> configure(-validate => 'key',
                     -validatecommand => [$self => '_notify'])
        if ($opt{-notify});
  } # if #

  $win_r->{_clear} = $win_r->{time_area}
      -> Button(-text => 'Rensa', -command => [clear => $self])
      -> pack(-side => 'right');

  $win_r->{_show} = $win_r->{time_area}
      -> Button(-text => 'Visa', -command => [_show => $self])
      -> pack(-side => 'right');

  $win_r->{_incr} = $win_r->{time_area}
      -> Button(-text => '+', -command => [_incr => $self])
      -> pack(-side => 'right');

  $win_r->{_decr} = $win_r->{time_area}
      -> Button(-text => '-', -command => [_decr => $self])
      -> pack(-side => 'right');

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      clear
#
# Description: Clear date and time
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Only clear date field
# Returns:
#  -

sub clear($;$) {
  # parameters
  my $self = shift;
  my ($date_only) = @_;

  my $win_r = $self->{win};

  if (exists($win_r->{date_data})) {
    $win_r->{date_data_insert} = $win_r->{date_data}->index('insert');
    $win_r->{date_data}->delete(0, 'end');
  } # if #

  if (exists($win_r->{week_data})) {
    $win_r->{week_data_insert} = $win_r->{week_data}->index('insert');
    $win_r->{week_data}->delete(0, 'end');
  } # if #

  return 0 if $date_only;

  if (exists($win_r->{time_data})) {
    $win_r->{time_data_insert} = $win_r->{time_data}->index('insert');
    $win_r->{time_data}->delete(0, 'end');
  } # if #

  return 0;
} # Method clear

#----------------------------------------------------------------------------
#
# Method:      get
#
# Description: Get time and date
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Only get date
# Returns:
#  time and date. undef if format is not valid
#

sub get($;$) {
  # parameters
  my $self = shift;
  my ($date_only) = @_;

  my $win_r = $self->{win};

  my ($time, $date);
  my $date_info = '';
  if (exists($win_r->{date_data})) {
    $win_r->{date_data_insert} = $win_r->{date_data}->index('insert');
    $date_info = $win_r->{date_data}->get();
    if ($date_only) {
      (undef, $date) = $self->{erefs}{-calculate}
          -> evalTimeDate($self->{-invalid}, undef, $date_info);

      return (undef, $date);
    } # if #
  } # if #
  if (exists($win_r->{week_data})) {
    $win_r->{week_data_insert} = $win_r->{week_data}->index('insert');
    $date_info = $win_r->{week_data}->get();
    if ($date_only) {
      (undef, $date) = $self->{erefs}{-calculate}
          -> evalTimeDate($self->{-invalid}, undef, $date_info);
      (undef, $date) = $self->{erefs}{-calculate}
          -> evalTimeDate(undef,
                          undef,
                          join('v',
                             $self->{erefs}{-calculate}->weekNumber($date)).'m',
                         );

      return (undef, $date);
    } # if #
  } # if #



  my $time_info = '';
  if (exists($win_r->{time_data})) {
    my $insert_pos = $win_r->{time_data}->index('insert');
    $time_info = $win_r->{time_data}->get();
    if (substr($time_info, $insert_pos-1, 1) eq '=') {
      $time_info = substr($time_info, 0, $insert_pos-1) .
                   substr($time_info, $insert_pos);
    } # if #
    $win_r->{time_data_insert} = $win_r->{time_data}->index('insert');
  } # if #


  ($time, $date) = $self->{erefs}{-calculate}
        -> evalTimeDate($self->{-invalid}, $time_info, $date_info);

  return ($time, $date);

} # Method get

#----------------------------------------------------------------------------
#
# Method:      set
#
# Description: Set time and date
#
# Arguments:
#  0 - Object reference
#  1 - Time to set
#  2 - Date to set
# Returns:
#  -

sub set($;$$) {
  # parameters
  my $self = shift;
  my ($time, $date) = @_;

  my $win_r = $self->{win};

  $self->clear(not defined($time));

  if (exists($win_r->{time_data}) and defined($time)) {
    $win_r->{time_data}->insert(0, $time);
    $win_r->{time_data}->icursor($win_r->{time_data_insert})
        if ($win_r->{time_data_insert});
  } # if #

  return 0 unless(defined($date));

  if (exists($win_r->{date_data})) {
    $win_r->{date_data}->insert(0, $date);
    $win_r->{date_data}->icursor($win_r->{date_data_insert})
        if ($win_r->{date_data_insert});
  } # if #

  if (exists($win_r->{week_data})) {
    $win_r->{week_data}->insert(0,
                    join('v', $self->{erefs}{-calculate}->weekNumber($date)));
    $win_r->{week_data}->icursor($win_r->{week_data_insert})
        if ($win_r->{week_data_insert});
  } # if #

} # Method set

#----------------------------------------------------------------------------
#
# Method:      update
#
# Description: Update a setting
#
# Arguments:
#  0 - Object reference
#  key, value
# Returns:
#  -

sub update($%) {
  # parameters
  my $self = shift;
  my (%arg) = @_;

  while (my ($key, $val) = each(%arg)) {
    $self->{$key} = $val;
  } # while #

  return 0;
} # Method update

#----------------------------------------------------------------------------
#
# Method:      _week
#
# Description: Return callback for week field
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _week($) {
  # parameters
  my $self = shift;


  return 0 unless($self->{-week});

  return $self->callback($self->{-week})
      if (ref($self->{-week}));

  $self->_step(0);
  return 0;
} # Method _week

#----------------------------------------------------------------------------
#
# Method:      _date
#
# Description: Return callback for date field
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _date($) {
  # parameters
  my $self = shift;


  return 0 unless($self->{-date});

  return $self->callback($self->{-date})
      if (ref($self->{-date}));

  $self->_step(0);
  return 0;
} # Method _date

#----------------------------------------------------------------------------
#
# Method:      _time
#
# Description: Return callback for time field
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Do add
# Returns:
#  -

sub _time($;$) {
  # parameters
  my $self = shift;
  my ($add) = @_;


  return 0 unless($self->{-time} or $self->{-timeadd});

  return $self->callback($self->{-timeadd})
      if ($add and ref($self->{-timeadd}));

  return $self->callback($self->{-time})
      if (ref($self->{-time}));

  $self->_step(0);
  return 0;
} # Method _time

#----------------------------------------------------------------------------
#
# Method:      _notify
#
# Description: Notify caller of key change
#
# Arguments:
#  0 - Object reference
# Arguments as received from text validation callback:
#  0 - The proposed value of the entry.
#  1 - The characters to be added (or deleted).
#  2 - The current value of entry i.e. before the proposed change.
#  3 - Index of char string to be added/deleted, if any. -1 otherwise
#  4 - Type of action. 1 == INSERT, 0 == DELETE, -1 if it's a forced
# Returns:
#  -

sub _notify($) {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;

  $self->callback($self->{-notify});

  return 1;
} # Method _notify

#----------------------------------------------------------------------------
#
# Method:      _show
#
# Description: Show time
#
# Arguments:
#  0 - Object reference
#
# Returns:
#  -

sub _show($) {
  # parameters
  my $self = shift;


  # OK, this is ugly so do NOT read!
  # Here we do not have current time and date.
  # So use use the calculator to get 0 seconds from now
  $self->set(
             $self->{erefs}{-calculate}->stepTimeDate(0)
            );
  return 0;
} # Method _show

#----------------------------------------------------------------------------
#
# Method:      _step
#
# Description: Step time
#
# Arguments:
#  0 - Object reference
#  1 - Number of seconds to step
#
# Returns:
#  -

sub _step($$) {
  # parameters
  my $self = shift;
  my ($seconds) = @_;


  my ($time, $date) = $self->get();
  return 0 unless $date;
  ($time, $date) =
              $self->{erefs}{-calculate}->stepTimeDate($seconds, $time, $date);
  return 0 unless $date;

  if (exists($self->{-min_date}) and $date lt $self->{-min_date}) {
    if ($self->{-week}) {
      $self->callback($self->{-invalid},
                      'Vecka före ' .
                        join('v',
                             $self->{erefs}{-calculate}->
                                    weekNumber($self->{-min_date})) .
                      ' ej tillåtet');
    } else {
      $self->callback($self->{-invalid},
                      'Datum före ' . $self->{-min_date} . ' ej tillåtet');
    } # if #

    return 0;
  } # if #

  if (exists($self->{-max_date}) and $date gt $self->{-max_date}) {
    if ($self->{-week}) {
      $self->callback($self->{-invalid},
                      'Vecka efter ' .
                      join('v',
                              $self->{erefs}{-calculate}->
                                  weekNumber($self->{-max_date})) .
                      ' ej tillåtet');
    } else {
      $self->callback($self->{-invalid},
                      'Datum efter ' . $self->{-max_date} . ' ej tillåtet');
    } # if #

    return 0;
  } # if #


  $self->set($time, $date);

  return 0;
} # Method _step

#----------------------------------------------------------------------------
#
# Method:      _posStep
#
# Description: Step time depending on position
#
# Arguments:
#  - Object reference
#  - Type: 'T' ++time, 't' --time, 'D' date, 'W' week
#
# Returns:
#  -

sub _posStep($$) {
  # parameters
  my $self = shift;
  my ($type) = @_;

  my $win_r = $self->{win};
  my $sign = (lc($type) eq $type) ? -1 : 1;

  if (lc($type) eq 't') {
    my $pos = $win_r->{time_data}->index('insert');
    # Step time
    if ($pos == 1) {
      return $self->_step($sign*10*ONEHOUR);
    } elsif ($pos == 2) {
      return $self->_step($sign*ONEHOUR);
    } elsif ($pos == 3 or $pos == 4) {
      return $self->_step($sign*10*ONEMINUTE);
    } else {
      return $self->_step($sign*ONEMINUTE);
    } # if #
  } # if #

  if (lc($type) eq 'd') {
    my $pos = $win_r->{date_data}->index('insert');
    # Step date
    if ($pos == 2) {
      return $self->_step($sign*(100*ONEYEAR+25*TWENTYFOURHOURS));
    } elsif ($pos == 3) {
      return $self->_step($sign*(10*ONEYEAR+2*TWENTYFOURHOURS));
    } elsif ($pos == 4) {
      return $self->_step($sign*ONEYEAR);
    } elsif ($pos == 5 or $pos == 6) {
      return $self->_step($sign*10*ONEMONTH);
    } elsif ($pos == 7) {
      return $self->_step($sign*ONEMONTH);
    } elsif ($pos == 8 or $pos == 9) {
      return $self->_step($sign*10*TWENTYFOURHOURS);
    } else {
      return $self->_step($sign*TWENTYFOURHOURS);
    } # if #
  } # if #

  if (lc($type) eq 'w') {
    my $pos = $win_r->{week_data}->index('insert');
    # Step date
    if ($pos == 6) {
      return $self->_step($sign*10*ONEWEEK);
    } else {
      return $self->_step($sign*ONEWEEK);
    } # if #
  } # if #
  return 0;
} # Method _posStep

#----------------------------------------------------------------------------
#
# Method:      _incr
#
# Description: Increment time
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _incr($) {
  # parameters
  my $self = shift;


  if (exists($self->{win}{time_data})) {
    $self->_step(ONEMINUTE);
  } elsif (exists($self->{win}{date_data})) {
    $self->_step(TWENTYFOURHOURS);
  } elsif (exists($self->{win}{week_data})) {
    $self->_step(ONEWEEK);
  } # if #

  return 0;
} # Method _incr

#----------------------------------------------------------------------------
#
# Method:      _decr
#
# Description: Decrement time
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _decr($) {
  # parameters
  my $self = shift;


  if (exists($self->{win}{time_data})) {
    $self->_step(-(ONEMINUTE));
  } elsif (exists($self->{win}{date_data})) {
    $self->_step(-(TWENTYFOURHOURS));
  } elsif (exists($self->{win}{week_data})) {
    $self->_step(-(ONEWEEK));
  } # if #

  return 0;
} # Method _decr

#----------------------------------------------------------------------------
#
# Method:      quit
#
# Description: Quit, disable widgets
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub quit($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};
  $win_r->{date_data} -> configure(-state => 'disabled')
      if ($win_r->{date_data});
  $win_r->{week_data} -> configure(-state => 'disabled')
      if ($win_r->{week_data});
  $win_r->{time_data} -> configure(-state => 'disabled')
      if ($win_r->{time_data});
  $win_r->{_clear}    -> configure(-state => 'disabled');
  $win_r->{_show}     -> configure(-state => 'disabled');
  $win_r->{_incr}     -> configure(-state => 'disabled');
  $win_r->{_decr}     -> configure(-state => 'disabled');

  return 0;
} # Method quit

1;
__END__
