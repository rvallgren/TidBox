#
package Gui::DayList;
#
#   Document: Gui::DayList
#   Version:  1.4   Created: 2018-02-01 16:28
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: DayList.pmx
#

my $VERSION = '1.4';
my $DATEVER = '2018-02-01';

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
    unless ($self->{itemconfig}) {
      $event = $1
          if ($event =~ /^(.*?)\s<<$/);
    } # unless #


    $self->callback($self->{-showEvent}, $refs->{$event}, $event);

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


  $self->{win}{list_box} -> selectionClear(0, 'end');

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

  my ($scroll_pos) = $win_r->{scrollbar}->get();
  my $cur_selection = $list_box->curselection();

  $self->clear();
  $self->callback($self->{-showEvent})
      if ($cur_selection);

  my $refs = $self->{refs};
  %{$refs} = ();

  $list_box->delete(0, 'end');
  $self->{highlited} = -1;

  my $repeated = 1;
  my $date = $self->{date};
  for my $ref ($self->{erefs}{-times}->getSortedRefs($date)) {

    next unless ($$ref =~ /^$date,($TIME),($TYPE),(.*)$/);

    my $entry = $self->{erefs}{-calculate}->format(undef, $1, $2, $3);

    unless (exists($refs->{$entry})) {
      $repeated = 1;
    } else {
      $entry = " -\"-    \"$3\"   Upprepning: $repeated";
      $repeated++;
    } # unless #

    $refs->{$entry} = $ref;
    $list_box -> insert("end", $entry);

  } # for #

  $list_box -> yviewMoveto($scroll_pos)
      if ($scroll_pos);

  if ($list_box->size()) {
    $list_box -> configure(-width => -1);
  } else {
    $list_box -> configure(-width => 20);
  } # if #

  # Show scrollbar if needed
  $list_box->idletasks();
  my ($x1, $y1, $w1, $h1) = $list_box->bbox(0);
  my ($x2, $y2, $w2, $h2) = $list_box->bbox('end');
  if ((defined($y1) and defined($y2))
      or
      not (defined($y1) or defined($y2))) {
    if ($win_r->{scrollbar_shown}) {
      $win_r->{scrollbar}->configure(-width => 0);
      $win_r->{scrollbar_shown} = 0;
    } # if #
  } else {
    unless ($win_r->{scrollbar_shown}) {
      $win_r->{scrollbar}->configure(-width => $win_r->{scrollbar_width});
      $win_r->{scrollbar_shown} = 1;
    } # unless #
  } # if #

  # Update lock display
  if ($self->{erefs}{-cfg}->isLocked($date)) {
    $list_box -> configure(-background => 'lightgrey');
  } else {
    $list_box -> configure(-background => 'white');
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
# Method:      see
#
# Description: Make selected line visible
#
# Arguments:
#  - Object reference
#  - Event that should be visible
# Optional Arguments:
#  - Time that should be visible
# Returns:
#  True if event was selected

sub see($$;$$) {
  # parameters
  my $self = shift;
  my ($fnd, $time) = @_;


  my $win_r = $self->{win};

  my $refs = $self->{refs};

  if ($fnd) {
    for my $key (keys(%$refs)) {
      next
          unless ($fnd eq $refs->{$key});

      for my $i (0 .. $win_r->{list_box}->index('end')) {
        next
            unless ($win_r->{list_box}->get($i) eq $key);
        $win_r->{list_box}->selectionSet($i);
        $win_r->{list_box}->see($i);
        return 1;
      } # for #

      return 0;
    } # for #
    return 0;
  } # if #

  # Show time
  for my $i (reverse(0 .. $win_r->{list_box}->index('end'))) {
# TODO Scrolls away from selected line
    my $e = $win_r->{list_box}->get($i);
    next
        if (not $e or ($time lt substr($e, 0, 5)));
    unless ($i == $self->{highlited}) {
      if ($self->{itemconfig}) {
        $win_r->{list_box}->itemconfigure($self->{highlited},
                                          -background => 'white')
             if ($self->{highlited} > -1);
        $win_r->{list_box}->itemconfigure($i, -background => 'lightgrey');
      } else {
        my $cur_selection = $win_r->{list_box}->curselection();
        if (($self->{highlited} > -1) and
            ($win_r->{list_box}->get($self->{highlited}) =~ /^(.*?)\s<<$/)
           )
        {
          $win_r->{list_box}->delete($self->{highlited});
          $win_r->{list_box}->insert($self->{highlited}, $1);
        } # if #
        my $line = $win_r->{list_box}->get($i);
        $win_r->{list_box}->delete($i);
        $win_r->{list_box}->insert($i, $line . ' <<');
        $win_r->{list_box}->selectionSet($cur_selection)
            if ($cur_selection);
      } # if #
      $self->{highlited} = $i;
    } # unless #
    $win_r->{list_box}->see($i);
    last;
  } # for #

  return 0;
} # Method see

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
              win       => $win_r,
              refs      => {},
              highlited => -1,
             };

  bless($self, $class);

  ### Listbox ###
  $win_r->{list_area} = $args{-area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => $args{-side}, -expand => '1', -fill => 'both');

  $win_r->{list_area_adjuster} = $args{-area}
      -> Adjuster()
      -> packAfter($win_r->{list_area}, -side => $args{-side});

  $win_r->{scrollbar} = $win_r->{list_area}
      -> Scrollbar()
      -> pack(-side => 'right', -fill => 'y');

  $win_r->{list_box} = $win_r->{list_area}
      -> Listbox(-height => 10, -exportselection => 0)
      -> pack(-side => 'right', -expand => '1', -fill => 'both');

  $win_r->{scrollbar}->configure(-command => ['yview', $win_r->{list_box}]);

  $win_r->{scrollbar_width} = $win_r->{scrollbar}->cget(-width);
  $win_r->{scrollbar}->configure(-width => 0);
  $win_r->{scrollbar_shown} = 0;

  $win_r->{list_box}
      -> bind('<<ListboxSelect>>' => [$self => '_show']);

  $win_r->{list_box}
      -> configure(-yscrollcommand => ['set', $win_r->{scrollbar}]);

  $self->{itemconfig} = $win_r->{list_box}->can('itemconfigure');

  # . Subscribe to updated event data
  $self->{erefs}{-times}->
          setDisplay($self->{-parentName} . 'dl', [$self, 'update']);

  if ($self->{erefs}{-clock}) {
    # . Register change date for midnight ticks
    $self->{erefs}{-clock}->repeat(-date => [$self, 'setDate']);
    # And show today
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
