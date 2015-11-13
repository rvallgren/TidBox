#
package Gui::Time;
#
#   Document: Time entry area
#   Version:  1.5   Created: 2011-04-05 19:49
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Time.pmx
#

my $VERSION = '1.5';
my $DATEVER = '2011-04-05';

# History information:
#
# PA1  2006-11-19  Roland Vallgren
#      First issue, extracted from tidbox.plx
# PA2  2007-03-17  Roland Vallgren
#      Removed not needed code
# 1.3  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
#      Week entry type added
#      Handling of allowed date range added
# 1.4  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.5  2011-03-31  Roland Vallgren
#      New method quit
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

use constant ONEMINUTE       => 60;                  # seconds
use constant ONEHOUR         => 60 * ONEMINUTE;      # 3600 seconds
use constant TWENTYFOURHOURS => 24 * ONEHOUR;        # 86400 seconds
use constant ONEWEEK         =>  7 * TWENTYFOURHOURS; # 604800 seconds

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
      -> pack(-side => 'top', -fill => 'both');

  my $self = {
              win        => $win_r,
             };

  for my $k ('-invalid', '-current', '-calculate', '-notify',
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
    $win_r->{date_data} -> bind('<Return>' => [$self => '_date']);
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
    $win_r->{week_data} -> bind('<Return>' => [$self => '_week']);
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
    $win_r->{time_data} -> bind('<Return>' => [$self => '_time']);
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

  $win_r->{date_data} -> delete(0, 'end') if (exists($win_r->{date_data}));
  $win_r->{week_data} -> delete(0, 'end') if (exists($win_r->{week_data}));
  return 0 if $date_only;
  $win_r->{time_data} -> delete(0, 'end') if (exists($win_r->{time_data}));

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
    $date_info = $win_r->{date_data} -> get();
    if ($date_only) {
      (undef, $date) = $self->{-calculate}
          -> evalTimeDate($self->{-invalid}, undef, $date_info);

      return (undef, $date);
    } # if #
  } # if #
  if (exists($win_r->{week_data})) {
    $date_info = $win_r->{week_data} -> get();
    if ($date_only) {
      (undef, $date) = $self->{-calculate}
          -> evalTimeDate($self->{-invalid}, undef, $date_info);
      (undef, $date) = $self->{-calculate}
          -> evalTimeDate(undef,
                          undef,
                          join('v', $self->{-calculate}->weekNumber($date)).'m',
                         );

      return (undef, $date);
    } # if #
  } # if #



  my $time_info = '';
  $time_info = $win_r->{time_data} -> get() if (exists($win_r->{time_data}));

  ($time, $date) = $self->{-calculate}
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

  $win_r->{time_data} -> insert(0, $time)
      if (exists($win_r->{time_data}) and defined($time));

  return 0 unless(defined($date));

  $win_r->{date_data} -> insert(0, $date)
      if (exists($win_r->{date_data}));

  $win_r->{week_data} -> insert(0,
                             join('v', $self->{-calculate}->weekNumber($date)))
      if (exists($win_r->{week_data}));

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

  my $win_r = $self->{win};

  $self->callback($self->{-week});

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

  my $win_r = $self->{win};

  $self->callback($self->{-date});

  return 0;
} # Method _date

#----------------------------------------------------------------------------
#
# Method:      _time
#
# Description: Return callback for time field
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _time($) {
  # parameters
  my $self = shift;


  return 0 unless($self->{-time});

  my $win_r = $self->{win};

  $self->callback($self->{-time});

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
             $self->{-calculate}->stepTimeDate(0)
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

sub _step($) {
  # parameters
  my $self = shift;
  my ($seconds) = @_;


  my ($time, $date) = $self->get();
  return 0 unless $date;
  ($time, $date) = $self->{-calculate}->stepTimeDate($seconds, $time, $date);
  return 0 unless $date;

  if (exists($self->{-min_date}) and $date lt $self->{-min_date}) {
    if ($self->{-week}) {
      $self->callback($self->{-invalid},
                      'Vecka före ' .
                      join('v', $self->{-calculate}->weekNumber($self->{-min_date})) .
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
                      join('v', $self->{-calculate}->weekNumber($self->{-max_date})) .
                      ' ej tillåtet');
    } else {
      $self->callback($self->{-invalid},
                      'Datum efter ' . $self->{-max_date} . ' ej tillåtet');
    } # if #

    return 0;
  } # if #


  $self -> set($time, $date);

  return 0;
} # Method _step

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
#  $win_r->{date_label}  -> configure(-state => 'disabled')
#      if ($win_r->{date_label});
  $win_r->{date_data}  -> configure(-state => 'disabled')
      if ($win_r->{date_data});
#  $win_r->{week_label}  -> configure(-state => 'disabled')
#      if ($win_r->{week_label});
  $win_r->{week_data}  -> configure(-state => 'disabled')
      if ($win_r->{week_data});
#  $win_r->{time_label}  -> configure(-state => 'disabled')
#      if ($win_r->{time_label});
  $win_r->{time_data}  -> configure(-state => 'disabled')
      if ($win_r->{time_data});
  $win_r->{_clear}  -> configure(-state => 'disabled');
  $win_r->{_show}   -> configure(-state => 'disabled');
  $win_r->{_incr}   -> configure(-state => 'disabled');
  $win_r->{_decr}   -> configure(-state => 'disabled');

  return 0;
} # Method quit

1;
__END__
