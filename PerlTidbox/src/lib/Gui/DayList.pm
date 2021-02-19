#
package Gui::DayList;
#
#   Document: Gui::DayList
#   Version:  1.8   Created: 2019-11-11 09:43
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: DayList.pmx
#

my $VERSION = '1.8';
my $DATEVER = '2019-11-11';

# History information:
#
# 1.0  2009-02-10  Roland Vallgren
#      First issue.
# 1.1  2011-03-31  Roland Vallgren
#      New method quit
# 1.2  2013-04-28  Roland Vallgren
#      Use isLocked to check lock status
# 1.3  2017-05-03  Roland Vallgren
#      Return or space in listbox shows event
#      Mouse wheel works in day list
#      Use Tk::Adjuster to allow change of width
#      Scrollbar only shows if part of list not shows
# 1.4  2017-10-16  Roland Vallgren
#      References to other objects in own hash
# 1.5  2019-02-26  Roland Vallgren
#      Use Scrolled to handle scrollbars on Listbox
#      Listbox handles "itemconfigure" in Tk version 804.034
#      => Removed highlighting by "<<" at end of line.
# 1.6  2019-04-01  Roland Vallgren
#      Removed print
# 1.7  2019-05-22  Roland Vallgren
#      _show provides an information message
#      Split see into see, select and activate
#      New methods highlite and highlited to highlite an event without
#      selecting it
# 1.8  2019-11-11  Roland Vallgren
#      Code improvement: Object orientation
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
use Tk::Adjuster;

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
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      _show
#
# Description: Get entry data and have callback display it
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _show($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  my $win_r = $self->{win};

  $win_r->{list_box}->focus();
  my $cur_selection = $win_r->{list_box}->curselection();

  if (defined($cur_selection)) {
    my $refs = $self->{refs};
    my $event = $win_r->{list_box}->get($cur_selection);

    $self->callback($self->{-showEvent}, $refs->{$event}, 'Visar: ' . $event);

  } # if #

  return 0;
} # Method _show

#----------------------------------------------------------------------------
#
# Method:      clear
#
# Description: Clear list box selection
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub clear($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  $win_r->{list_box}->selectionClear(0, 'end');

  if ($self->{highlited} > -1 and
          $self->{highlited} < $win_r->{list_box}->index('end')) {
    $win_r->{list_box}->itemconfigure($self->{highlited},
                                      -background => $self->{background});
    $self->{highlited} = -1;
  } # if #

  return 0;
} # Method clear

#----------------------------------------------------------------------------
#
# Method:      update
#
# Description: Update day list when changes are recorded
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Dates of change
# Returns:
#  -

sub update($;@) {
  # parameters
  my $self = shift;
  my (@dates) = @_;


  return 0
      if (@dates and
          not $self->{erefs}{-calculate}->impactedDate($self->{date}, @dates));

  my $win_r = $self->{win};
  my $list_box = $win_r->{list_box};

  my ($scroll_pos) = $list_box->Subwidget("yscrollbar")->get();
  my $cur_selection = $list_box->curselection();

  $self->clear();
  $self->callback($self->{-showEvent})
      if ($cur_selection);

  my $refs = $self->{refs};
  %{$refs} = ();

  $list_box->delete(0, 'end');

  my $repeated = 1;
  my $date = $self->{date};
  my $times = $self->{erefs}{-times}->getSortedRegistrationsForDate($date);

  for my $evRef (@$times) {

    my $entry = $self->{erefs}{-calculate}->
       format(undef, $evRef->{time}, $evRef->{type}, $evRef->{text});

#    unless (exists($refs->{$entry})) {
#       TODO Same entry text repeated on other times will confuse
#            the list. However removing the reset of $repeat will cause number
#            to step on different entries.
#            Either do this or include time in entry
#      $repeated = 1;
#      ;
#    } else {
    if (exists($refs->{$entry})) {
      $entry = ' -"-    "' . $evRef->{text} . '"   Upprepning: ' . $repeated;
      $repeated++;
    } # if #

    $refs->{$entry} = $evRef->{ref};
    $list_box -> insert("end", $entry);

  } # for #

  $list_box -> yviewMoveto($scroll_pos)
      if ($scroll_pos);

  if ($list_box->size()) {
    $list_box -> configure(-width => -1);
  } else {
    # TODO Default width 20 is too small, can we calculate from last events?
    $list_box -> configure(-width => 50);
  } # if #

  # Update lock display

  if ($self->{erefs}{-cfg}->isLocked($date)) {
    $self->{background} = 'lightgrey';
  } else {
    $self->{background} = 'white';
  } # if #
  $list_box->configure(-background => $self->{background});

  if ($self->{erefs}{-clock} and
      $self->{erefs}{-clock}->getSecond() < 57) {
    $self->{erefs}{-clock}->
                 timeout(-second => 2,
                         -callback => [$self => 'ongoing']);
  } # if #
  return 0;
} # Method update

#----------------------------------------------------------------------------
#
# Method:      setDate
#
# Description: Set new date, use today if no date is provided
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - New date
# Returns:
#  -

sub setDate($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  if ($date) {
    $self->{date} = $date;
  } elsif (exists($self->{erefs}{-clock})) {
    $self->{date} = $self->{erefs}{-clock}->getDate()
  } # if #

  $self->update();
  return 0;
} # Method setDate

#----------------------------------------------------------------------------
#
# Method:      curselection
#
# Description: Get reference to selected event
#
# Arguments:
#  0 - Object reference
# Returns:
#  Selected line

sub curselection($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  my $cur_selection = $win_r->{list_box}->curselection();
  return ($self->{refs}{$win_r->{list_box}->get($cur_selection)})
    if (defined($cur_selection));

  return (undef);
} # Method curselection

#----------------------------------------------------------------------------
#
# Method:      _findEvent
#
# Description: Find an event
#
# Arguments:
#  - Object reference
#  - Reference to event to find
# Returns:
#  - Index of found event
#  - undef if not found

sub _findEvent($$) {
  # parameters
  my $self = shift;
  my ($fnd) = @_;

  my $win_r = $self->{win};

  my $refs = $self->{refs};

  for my $key (keys(%$refs)) {
    next
        unless ($fnd eq $refs->{$key});

    for my $i (0 .. $win_r->{list_box}->index('end')) {
      return $i
          if ($win_r->{list_box}->get($i) eq $key);
    } # for #

    return undef;
  } # for #
  return undef;
} # Method _findEvent

#----------------------------------------------------------------------------
#
# Method:      _findTime
#
# Description: Find an event at or before specified time
#
# Arguments:
#  - Object reference
#  - Time to search
# Returns:
#  - Index of found event
#  - undef if not found

sub _findTime($$) {
  # parameters
  my $self = shift;
  my ($time) = @_;

  my $win_r = $self->{win};

  for my $i (reverse(0 .. $win_r->{list_box}->index('end'))) {
    my $e = $win_r->{list_box}->get($i);
    next
        if (not $e or ($time lt substr($e, 0, 5)));
    return $i;
  } # for #
  return undef;
} # Method _findTime

#----------------------------------------------------------------------------
#
# Method:      active
#
# Description: Get reference to active event
#
# Arguments:
#  - Object reference
# Returns:
#  - Referens to active event

sub active($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};
  my $cur_active = $win_r->{list_box}->index('active');
  return ($self->{refs}{$win_r->{list_box}->get($cur_active)})
      if (defined($cur_active));

  return (undef);
} # Method active

#----------------------------------------------------------------------------
#
# Method:      highlited
#
# Description: Get reference to highlited event
#
# Arguments:
#  - Object reference
# Returns:
#  - Reference to highlited event

sub highlited($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  my $h = $self->{highlited};

  return ($self->{refs}{$win_r->{list_box}->get($h)})
      if ($h > -1 and
          $h < $win_r->{list_box}->index('end'));

  return undef;
} # Method highlite

#----------------------------------------------------------------------------
#
# Method:      highlite
#
# Description: Highlite an event selected by index
#
# Arguments:
#  - Object reference
#  - Index of event that should be highlited
#      If no index is provided remove highlite
# Returns:
#  -

sub highlite($;$) {
  # parameters
  my $self = shift;
  my ($index) = @_;


  my $win_r = $self->{win};
  $win_r->{list_box}->itemconfigure($self->{highlited},
                                    -background => $self->{background})
      if ($self->{highlited} > -1 and
          $self->{highlited} < $win_r->{list_box}->index('end'));

  if (defined($index)) {
    $win_r->{list_box}->itemconfigure($index, -background => 'lightblue');
    $self->{highlited} = $index;
    $win_r->{list_box}->see($index);
  } else {
    $self->{highlited} = -1;
  } # if #

  return 0;
} # Method highlite

#----------------------------------------------------------------------------
#
# Method:      seeTime
#
# Description: Make event for a time visible and highlited
#
# Arguments:
#  - Object reference
#  - Time that should be visible
# Returns:
#  -

sub seeTime($$) {
  # parameters
  my $self = shift;
  my ($time) = @_;


  my $index = $self->_findTime($time);
  return undef
      unless (defined($index));
  my $win_r = $self->{win};
  $self->highlite($index);
  $win_r->{list_box}->activate($index);
  return 0;
} # Method seeTime

#----------------------------------------------------------------------------
#
# Method:      ongoing
#
# Description: Show the event that is ongoing in light green color
#
# Arguments:
#  - Object reference
# Returns:
#  - undef if no event is found or no clock is availabel

sub ongoing($$) {
  # parameters
  my $self = shift;


  return undef
      unless (exists($self->{erefs}{-clock}));
  my $index = $self->_findTime($self->{erefs}{-clock}->getTime());
  return undef
      unless (defined($index));

  my $win_r = $self->{win};
  $win_r->{list_box}->itemconfigure($self->{ongoing},
                                    -background => $self->{background})
      if ($self->{ongoing} != $index and
          $self->{ongoing} > -1      and
          $self->{ongoing} < $win_r->{list_box}->index('end'));

  $win_r->{list_box}->itemconfigure($index, -background => 'lightgreen');
  $self->{ongoing} = $index;

  return 0;
} # Method ongoing

#----------------------------------------------------------------------------
#
# Method:      seeOngoing
#
# Description: Make ongoing visible, turn of highlited
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub seeOngoing($) {
  # parameters
  my $self = shift;


  $self->highlite();
  my $win_r = $self->{win};
  $win_r->{list_box}->see($self->{ongoing})
      if (exists($self->{erefs}{-clock}) and
          $self->{ongoing} > -1 and
          $self->{ongoing} < $win_r->{list_box}->index('end') and
          not defined($win_r->{list_box}->curselection())
         );
  return 0;
} # Method seeOngoing

#----------------------------------------------------------------------------
#
# Method:      selectEvent
#
# Description: Select an event
#
# Arguments:
#  - Object reference
#  - Event that should be selected
# Returns:
#  True if event was found and selected

sub selectEvent($$) {
  # parameters
  my $self = shift;
  my ($fnd) = @_;


  my $index = $self->_findEvent($fnd);
  return 0
      unless (defined($index));

  my $win_r = $self->{win};
  $self->clear();
  $win_r->{list_box}->selectionSet($index);
  $win_r->{list_box}->see($index);
  return 1;

} # Method selectEvent

#----------------------------------------------------------------------------
#
# Method:      activateEvent
#
# Description: Activate an event
#
# Arguments:
#  - Object reference
#  - Event that should be activated
# Returns:
#  True if event was found and activated

sub activateEvent($$) {
  # parameters
  my $self = shift;
  my ($fnd) = @_;


  my $index = $self->_findEvent($fnd);
  return 0
      unless (defined($index));

  my $win_r = $self->{win};

  $self->clear();
  $self->highlite($index);
  $win_r->{list_box}->activate($index);
  $win_r->{list_box}->see($index);
  return 1;

} # Method activateEvent

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create list of events for one day
#
# Arguments:
#  0 - Object prototype
# -area        Area to show up in
# -side        Pack side
# -showEvent   Callback for show event
# -times       Reference to times data
# -calculate   Reference to the calculator
# -clock       Reference to the clock, list will show today
# -cfg         Reference to the configuration
# -parentName  Name of parent window
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;
  my (%args) = @_;

  my $win_r = {};

  my $self = {%args,
              win        => $win_r,
              refs       => {},
              highlited  => -1,
              ongoing    => -1,
              background => 'white',
             };

  bless($self, $class);

  ### Listbox ###
  $win_r->{list_area} = $args{-area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => $args{-side}, -expand => '1', -fill => 'both');

  $win_r->{list_area_adjuster} = $args{-area}
      -> Adjuster()
      -> packAfter($win_r->{list_area}, -side => $args{-side});

  $win_r->{list_box} = $win_r->{list_area}
       -> Scrolled('Listbox', -scrollbars => 'oe')
       -> pack(-side => 'right', -expand => '1', -fill => 'both');
  $win_r->{list_box} -> configure(
                                  -exportselection => 0,
                                  -height => 10,
                                  -selectmode => 'single'
                                 );

  # Tk makes a Tk::Callback object of a given callback, hence copy array
  $win_r->{list_box}
      -> bind('<Escape>' => [ @{$args{-showEvent}} ]);
  $win_r->{list_box}
      -> bind('<<ListboxSelect>>' => [$self => '_show']);

  # . Subscribe to updated event data
  $self->{erefs}{-times}->
          setDisplay($self->{-parentName} . 'dl', [$self, 'update']);

  if ($self->{erefs}{-clock}) {
    # . Register change date for midnight ticks
    $self->{erefs}{-clock}->repeat(-date => [$self, 'setDate']);
    # . Register minute ticks for ongoing
    $self->{erefs}{-clock}->repeat(-minute => [$self, 'ongoing']);
  } # if #

  return $self;
} # Method new

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
  $win_r->{list_box}  -> configure(-state => 'disabled');
  return 0;
} # Method quit

1;
__END__
