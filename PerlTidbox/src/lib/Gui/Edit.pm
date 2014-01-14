#
package Gui::Edit;
#
#   Document: Edit day
#   Version:  2.1   Created: 2013-05-18 16:04
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Edit.pmx
#

my $VERSION = '2.1';
my $DATEVER = '2013-05-18';

# History information:
#
# 1.0  2006-06-17  Roland Vallgren
#      First issue.
# 2.0  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Listbox moved to DayList class.
# 2.1  2013-05-18  Roland Vallgren
#      Use isLocked to check lock
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent Gui::Base;

use strict;
use warnings;
use Carp;
use integer;

use Tk;

use Gui::Confirm;
use Gui::DayList;

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
#              Create edit GUI
#
# Arguments:
#  0 - Object prototype
# Additional arguments as hash
#  -data       Reference to common data hash
#  -cfg        Reference to configuration hash
#  -event_cfg  Event configuration object
#  -parent_win Parent window
#  -title      Tool title
#  -times      Reference to times object
#  -calculate  Reference to calculator
#  -clock      Reference to clock
#  -earlier    Reference to earlier object
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              @_,
              win      => {name => 'edit'},
              date     => '',
              forw     => [],
              back     => [],
             };

  $self->{-title} .= ': Redigera tider';

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _message
#
# Description: Show message
#
# Arguments:
#  0 - Object reference
#  1 - Message to show
# Returns:
#  -

sub _message($$) {
  # parameters
  my $self = shift;
  my ($msg) = @_;


  $self->{win}{event_msg_msg} -> configure(-text=>$msg);

  return 0;
} # Method _message

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear entry edit
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  $win_r->{time_area}->set('', $self->{date});
  $self->{type_setting} = 0;
  $self->{-event_cfg}->clearData($win_r, 1);

  $win_r->{day_list}->clear();

  $win_r->{entry_button_change} -> configure(-state => 'disabled');
  $win_r->{entry_button_delete} -> configure(-state => 'disabled');
  $win_r->{entry_button_add}    -> configure(-state => 'disabled');
  $win_r->{entry_button_search_f} -> configure(-state => 'disabled');
  $win_r->{entry_button_search_b} -> configure(-state => 'disabled');
  $self->_message('');

  return 0;
} # Method _clear

#----------------------------------------------------------------------------
#
# Method:      _get
#
# Description: Get entry data
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Supplied problem message callback
# Returns:
#  0 - Entry data line
#  1 - Action text, for event
#  2 - Date for registration
#  3 - Time for registration

sub _get($;$) {
  # parameters
  my $self = shift;
  my ($msg) = @_;


  my $win_r = $self->{win};

  my $action_text = '';

  if ($self->{type_setting} eq $BEGINEVENT) {

    $action_text =
        $self->{-event_cfg}->getData($win_r, $msg, $win_r->{date});

    return undef unless (defined($action_text));

  } # if

  my ($time, $date) = $win_r->{time_area}->get();
  return undef
      unless (defined($time) and
              defined($date) and
              $self->{type_setting});

  return (join(',', $date, $time, $self->{type_setting}, $action_text),
          $action_text, $date, $time);
} # Method _get

#----------------------------------------------------------------------------
#
# Method:      _enableAdd
#
# Description: Enable add button
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _enableAdd($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};
  $win_r->{entry_button_add}      -> configure(-state => 'normal');
  $win_r->{entry_button_search_f} -> configure(-state => 'normal');
  $win_r->{entry_button_search_b} -> configure(-state => 'normal');
  return 0;
} # Method _enableAdd

#----------------------------------------------------------------------------
#
# Method:      _validate
#
# Description: Validate entry text
#              No actual validation is performed
#              Improvements might add validation if needed
#              Radiobutton change
#
# Arguments as received from text validation callback:
#  0 - The proposed value of the entry.
#  1 - The characters to be added (or deleted).
#  2 - The current value of entry i.e. before the proposed change.
#  3 - Index of char string to be added/deleted, if any. -1 otherwise
#  4 - Type of action. 1 == INSERT, 0 == DELETE, -1 if it's a forced
# Returns:
#  0 - True, edit is allways allowed
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _validate {
  # parameters
  my $self = shift;

  $self->{type_setting} = $BEGINEVENT;
  $self->_enableAdd();
  return 1;
} # Method _validate

#----------------------------------------------------------------------------
#
# Method:      show
#
# Description: Show entry data in entry box
#              Clear unless data is provided
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Reference to event to show
#  - Event text from day list
# Returns:
#  -

sub show($;$$) {
  # parameters
  my $self = shift;
  my ($ref, $text) = @_;

  my $win_r = $self->{win};

  if (ref($ref) and
      (${$ref} =~ /^($DATE),($TIME),($TYPE),(.*)$/o))
  {
    my ($date, $time, $type, $event_data) = ($1, $2, $3, $4);
    $win_r->{time_area}->set($time, $date);
    if (defined($event_data) and ($type eq $BEGINEVENT)) {
      $self->{-event_cfg}->putData($win_r, $event_data)
    } else {
      $self->{-event_cfg}->clearData($win_r, 1);
    } # if #
    $self->{type_setting} = $type;
    $self->_message("Info: " . $text);
    $win_r->{entry_button_change} -> configure(-state => 'normal');
    $win_r->{entry_button_delete} -> configure(-state => 'normal');
    $self->_enableAdd();

  } else {
    $self->_clear();

  } # if #

  return 0;
} # Method show

#----------------------------------------------------------------------------
#
# Method:      undo
#
# Description: Update undo button status when undo list is changed
#
# Arguments:
#  0 - Object reference
#  1 - Number of undo steps performed,
#      0 no undo, only update button
#      <0 New undo event added
#      >0 Number of undo events performed
#  2 - Length of undo list
# Returns:
#  -

sub undo($$$) {
  # parameters
  my $self = shift;
  my ($steps, $size) = @_;


  my $win_r = $self->{win};

  return 0 if $win_r->{win}->state() eq 'withdrawn';

  # Withdraw confirm popup
  $win_r->{confirm} -> withdraw();


  $self->_message('Ångrade ' . $steps . ' steg')
      if ($steps > 0);

  $win_r->{undo}
     -> configure(-state =>
                  ($size ? 'normal' : 'disabled')
                 );

  return 0;
} # Method undo

#----------------------------------------------------------------------------
#
# Method:      update
#
# Description: Update edit list
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 .. n - Dates that were changed
# Returns:
#  -

sub update($;@) {
  # parameters
  my $self = shift;
  my @dates = @_;

  my $win_r = $self->{win};


  return 0
      unless (Exists($win_r->{win}));
  return 0
      if $win_r->{win}->state() eq 'withdrawn';

  return 0
      if (@dates and
          not $self->{-calculate}->impactedDate($self->{date}, @dates));

  my $date = $self->{date};
  $win_r->{day_list}->setDate($date);

  $self->_clear();

  # Update lock display
  my ($lock, $locked) = $self->{-cfg}->isLocked($self->{date});

  if (($self->{date} eq $self->{-clock}->getDate()) and
      (not $lock))
  {

    $self->{-clock}->setDisplay($win_r->{name}, $win_r->{title});

  } else {

    $self->{-clock}->setDisplay($win_r->{name}, undef);

    $win_r->{title}
        -> configure(
      -text =>
        $self->{-calculate}
           -> dayStr($self->{-calculate}->weekDay($self->{date})) .
        ' Vecka: ' . $self->{-calculate}->weekNumber($self->{date}) .
        ' Datum: ' . $self->{date} .
        '  ' . $locked
                    );
  } # if #

  # Update undo button
  $self->undo(0, $self->{-times}->undoGetLength());

  return 0;
} # Method update

#----------------------------------------------------------------------------
#
# Method:      _search
#
# Description:
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Backward
# Returns:
#  -

sub _search($;$) {
  # parameters
  my $self = shift;
  my ($back) = @_;


  my $win_r = $self->{win};

  return $self->_message('Sökning kan bara göras på händelse')
      unless ($self->{type_setting} eq $BEGINEVENT);

  my ($line, $action_text) = $self->_get();

  return $self->_message('Kan inte söka på ingenting')
      unless ($action_text);

  my $search_text = $action_text;

  # "PERLify" user entered wildcards if no perl regexps detected
  unless ($search_text =~ /(?:[\\[\]{}+^]|\.\*)/) {
    $search_text =~ s/\./\\./g;
    $search_text =~ s/\?/./g;
    $search_text =~ s/\*/.*?/g;
  } # unless #

  # Make empty fields wildcard
  $search_text =~ s/,+$//;
  $search_text =~ s/,(?=,)/,.*?/g;
  $search_text = '.*?' . $search_text
      if(substr($search_text, 0, 1) eq ',');

  # Case insensitive search
  $search_text = '(?i)' . $search_text;

  return $self->_message('Kan inte söka på ingenting')
      unless ($search_text);

  # Get time and date if selection is active
  my $ref = $win_r->{day_list}->curselection();
  my $date_time;
  if (ref($ref)) {
    $date_time = substr($$ref, 0, 16);
  } else {
    $date_time = substr($line, 0, 16);
  } # if #

  # Search in event data
  my $fnd;

  if ($back) {
    for my $ref (reverse($self->{-times}
        -> getSortedRefs(join(',',$DATE,$TIME,$BEGINEVENT,$search_text))
                ))
    {
      next
          if ($date_time le substr($$ref, 0, 16));
      $fnd = $ref;
      last;
    } # for #

  } else {
    for my $ref ($self->{-times}
        -> getSortedRefs(join(',',$DATE,$TIME,$BEGINEVENT,$search_text))
                )
    {
      next
          if ($date_time ge substr($$ref, 0, 16));
      $fnd = $ref;
      last;
    } # for #
  } # if #

  return $self->_message('Hittade ingenting')
      unless ($fnd);

  # Display the found event
  $self->_display(substr($$fnd, 0, 10));

  if ($win_r->{day_list}->see($fnd)) {
    $self->{-earlier}->add($action_text);
    $self->{-event_cfg}->putData($win_r, $action_text, 1);
  } # if #

  return 0;
} # Method _search

#----------------------------------------------------------------------------
#
# Method:      _previous
#
# Description: Add previous event text in event box
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event to add
# Returns:
#  -

sub _previous($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  $self->{type_setting} = $BEGINEVENT;
  $self->{-event_cfg}->putData($self->{win}, $$ref);
  $self->_enableAdd();
  $self->_message('');
  return 0;
} # Method _previous

#----------------------------------------------------------------------------
#
# Method:      _doAdd
#
# Description: Add a new event from th entry box
#
# Arguments:
#  0 - Object reference
#  1 - Action to add
#  2 - Action text
#  3 - Date
# Returns:
#  -

sub _doAdd($$$$) {
  # parameters
  my $self = shift;
  my ($line, $action_text, $date) = @_;


  $self->{-times}->add($line);
  $self->{-earlier}->add($action_text);

  $self->update();


  if ($date eq $self->{date}) {
    $self->_message('Ny registrering tillagd');

  } elsif ($date eq $self->{-clock}->getDate()) {
    $self->_message('Ny registrering tillagd idag');

  } else {
    $self->_message('Ny registrering tillagd till ' . $date);

  } # if #

  return 0;
} # Method _doAdd

#----------------------------------------------------------------------------
#
# Method:      _add
#
# Description: Add an entry in the edit list box
#              Ask for confirmation add to another date than edit or today
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _add($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  my ($line, $action_text, $date) = $self->_get([$self, '_message']);
  if ($line) {
    if ($self->{-cfg}->isLocked($date, $win_r)) {
      # The date is locked, can not complete operation

    } elsif ($date eq $self->{date}) {
      $self->_doAdd($line, $action_text, $date);

    } else {
      $win_r->{confirm}
          -> popup(-title  => 'bekräfta',
                   -text   => ['Lägg till för annan dag?'],
                   -data   => [$self->{-calculate}->format($line)],
                   -action => [$self, '_doAdd', $line, $action_text, $date],
                  );

    } # if #
  } # if #

  return 0;
} # Method _add

#----------------------------------------------------------------------------
#
# Method:      _doChange
#
# Description: Change data for an entry
#
# Arguments:
#  0 - Object reference
#  1 - Reference to action to change
#  2 - New action
#  3 - New action text
#  4 - Date
# Returns:
#  -

sub _doChange($@) {
  # parameters
  my $self = shift;
  my ($event_ref, $line, $action_text, $date) = @_;


  $self->{-earlier}->add($action_text);

  $self->{-times}->change($event_ref, $line);

  $self->update();

  if ($date eq $self->{date}) {
    $self->_message('Registrering ändrad');

  } elsif ($date eq $self->{-clock}->getDate()) {
    $self->_message('Registrering flyttat till idag');

  } else {
    $self->_message('Registrering flyttat till ' . $date);

  } # if #

  return 0;
} # Method _doChange

#----------------------------------------------------------------------------
#
# Method:      _change
#
# Description:
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _change($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  my $event_ref = $win_r->{day_list}->curselection();

  if (ref($event_ref)) {

    my ($line, $action_text, $date) = $self->_get([$self, '_message']);

    if ($line) {
      # One of from or to date is locked, can not complete operation
      return 0
          if ($self->{-cfg}->isLocked($date, $win_r) or
              $self->{-cfg}->isLocked($self->{date}, $win_r));

      if (${$event_ref} ne $line) {

        if ($date eq $self->{date}) {
          $self->_doChange($event_ref, $line, $action_text, $date);

        } else {
            $win_r->{confirm}
                -> popup(-title  => 'bekräfta',
                         -text   => ['Flytta till annan dag?'],
                         -data   => [$self->{-calculate}->format($line)],
                         -action => [$self, '_doChange',
                                     $event_ref, $line, $action_text, $date],
                        );
        } # if #

      } else {
        # No change, but unselect the entry anyway as time and date
        # are cleared when _get gets the time
        $self->_clear();
        $self->_message('Ingen ändring');

      } # if #
    } # if #

  } else {
    $self->_add();
  } # if #

  return 0;
} # Method _change

#----------------------------------------------------------------------------
#
# Method:      _delete
#
# Description: Delete an entry in the edit list box
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _delete($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  my $event_ref = $win_r->{day_list}->curselection();

  if (ref($event_ref)) {

    return 0
        if ($self->{-cfg}->isLocked($self->{date}, $win_r));

    $self->{-times}->change($event_ref);

    $self->update();

    $self->_message('Registrering borttagen');

  } else {
    $self->_message('Ingen registrering vald');
  } # if #
  return 0;
} # Method _delete

#----------------------------------------------------------------------------
#
# Method:      _forw
#
# Description: Go forward in remembered dates
#              If date is provided, discard forwards
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Date
# Returns:
#  -

sub _forw($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  push(@{$self->{back}}, $self->{date});
  if ($date) {
    @{$self->{forw}} = ();
  } else {
    $date = pop(@{$self->{forw}});
    $self->_display($date, 1);
  } # if #

  my $win_r = $self->{win};
  $win_r->{back} -> configure(-state => 'normal');
  $win_r->{forw} -> configure(-state => 'disabled')
      unless @{$self->{forw}};

  return 0;
} # Method _forw

#----------------------------------------------------------------------------
#
# Method:      _back
#
# Description: Go backward in remembered dates
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _back($) {
  # parameters
  my $self = shift;

  push(@{$self->{forw}}, $self->{date});
  my $date = pop(@{$self->{back}});
  $self->_display($date, 1);

  my $win_r = $self->{win};
  $win_r->{back} -> configure(-state => 'disabled')
      unless @{$self->{back}};
  $win_r->{forw} -> configure(-state => 'normal');

  return 0;
} # Method _back

#----------------------------------------------------------------------------
#
# Method:      _goto
#
# Description: Goto specified edit day
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _goto($) {
  # parameters
  my $self = shift;


  my $date = $self->{win}{time_area}->get(1);
  $self->_display($date)
      if $date;
  return 0;
} # Method _goto

#----------------------------------------------------------------------------
#
# Method:      _prev
#
# Description: Edit previous day
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _prev($) {
  # parameters
  my $self = shift;


  my $date = $self->{win}{time_area}->get(1);
  $self->_display(
           $self->{-calculate}->stepDate($date, -1))
      if $date;
  return 0;
} # Method _prev

#----------------------------------------------------------------------------
#
# Method:      _next
#
# Description: Edit next day
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _next($) {
  # parameters
  my $self = shift;


  my $date = $self->{win}{time_area}->get(1);
  $self->_display(
           $self->{-calculate}->stepDate($date, 1))
      if $date;
  return 0;
} # Method _next

#----------------------------------------------------------------------------
#
# Method:      _done
#
# Description: Save times data when edit is withdrawn
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub done($) {
  # parameters
  my $self = shift;


  $self->{-times}->save();

  return 0;
} # Method done

#----------------------------------------------------------------------------
#
# Method:      _earlierAdd
#
# Description: Add earlier menu
#
# Arguments:
#  0 - Object reference
#  1 - Area were button should be added
# Returns:
#  -

sub _earlierAdd($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;

  $self->{-earlier}->create($area, 'right', [ $self, '_previous' ]);
  return 0;
} # Method _earlierAdd

#----------------------------------------------------------------------------
#
# Method:      _setup
#
# Description: Setup the contents of the edit window
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _setup($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  # Set some defaults
  $self->{textboxwidth} = 0;

  ### Listbox ###
  $win_r->{day_list} =
    new Gui::DayList(-area       => $win_r->{area},
                     -side       => 'left',
                     -showEvent  => [$self => 'show'],
                     -times      => $self->{-times},
                     -calculate  => $self->{-calculate},
                     -cfg        => $self->{-cfg},
                     -parentName => $win_r->{name},
                    );
  ### Entry edit ###
  ### Entry edit area ###
  $win_r->{entry_area} = $win_r->{area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'left', -fill => 'both');

  ### Entry edit time ###
  $win_r->{time_area} =
    new Gui::Time(
                  -area      => $win_r->{entry_area},
                  -calculate => $self->{-calculate},
                  -time      => [$self, '_change'],
                  -date      => [$self => '_goto'],
                  -invalid   => [$self => '_message'],
                 );

  ### Entry edit type ###
  $win_r->{type_title_area} = $win_r->{entry_area}
      -> Frame()
      -> pack(-side => 'top', -fill => 'both');

  $win_r->{type_title_text} = $win_r->{type_title_area}
      -> Label(-text => 'Typ:')
      -> pack(-side => 'left');

  $win_r->{entry_type_area} = $win_r->{entry_area}
      -> Frame()
      -> pack(-side => 'top', -fill => 'both');


  $self->{type_setting} = 0;

  $win_r->{entry_wd} = $win_r->{entry_type_area}
      -> Radiobutton(-text     => $TEXT{$BEGINWORKDAY},
                     -command  => [_enableAdd => $self],
                     -variable => \$self->{type_setting},
                     -value    => $BEGINWORKDAY,
                    );

  $win_r->{entry_wd} -> grid( $win_r->{entry_type_area}
      -> Radiobutton(-text     => $TEXT{$ENDWORKDAY},
                     -command  => [_enableAdd => $self],
                     -variable => \$self->{type_setting},
                     -value    => $ENDWORKDAY,
                    ),
      -sticky => 'w'
    );

  $win_r->{entry_paus} = $win_r->{entry_type_area}
      -> Radiobutton(-text     => $TEXT{$BEGINPAUS},
                     -command  => [_enableAdd => $self],
                     -variable => \$self->{type_setting},
                     -value    => $BEGINPAUS,
                    );

  $win_r->{entry_paus} -> grid( $win_r->{entry_type_area}
      -> Radiobutton(-text     => $TEXT{$ENDPAUS},
                     -command  => [_enableAdd => $self],
                     -variable => \$self->{type_setting},
                     -value    => $ENDPAUS,
                    ),
      -sticky => 'w'
    );

  $win_r->{entry_event} = $win_r->{entry_type_area}
      -> Radiobutton(-text     => $TEXT{$BEGINEVENT},
                     -command  => [_enableAdd => $self],
                     -variable => \$self->{type_setting},
                     -value    => $BEGINEVENT,
                    );

  $win_r->{entry_event} -> grid( $win_r->{entry_type_area}
      -> Radiobutton(-text     => $TEXT{$ENDEVENT},
                     -command  => [_enableAdd => $self],
                     -variable => \$self->{type_setting},
                     -value    => $ENDEVENT,
                    ),
      -sticky => 'w'
    );

  ### Entry edit text ###
  $win_r->{entry_event_area} = $win_r->{entry_area}
      -> Frame(-bd => '1', -relief => 'raised')
      -> pack(-side => 'top', -fill => 'both');
  $win_r->{entry_evbutt_area} = $self->{-event_cfg}
      -> createArea(-win      => $win_r,
                    -area     => $win_r->{entry_event_area},
                    -validate => [$self => '_validate'],
                    -buttons  => [$self => '_earlierAdd'],
                    -return   => [$self => '_change'],
                    -date     => $self->{-clock}->getDate(),
                   );

  ### Entry edit message ###
  $win_r->{entry_msg_area} = $win_r->{entry_area}
      -> Frame(-bd => '2', -relief => 'sunken')
      -> pack(-side => 'top', -fill => 'both');

  $win_r->{event_msg_msg} = $win_r->{entry_msg_area}
      -> Label()
      -> pack(-side => 'left');

  ### Entry edit Buttons ###
  $win_r->{entry_button_area} = $win_r->{entry_area}
      -> Frame()
      -> pack(-side => 'top', -fill => 'both');

  # Change button
  $win_r->{entry_button_change} = $win_r->{entry_button_area}
      -> Button(-text => 'Ändra',
                -command => [_change => $self],
               )
      -> pack(-side => 'left');

  # Add button
  $win_r->{entry_button_add} = $win_r->{entry_button_area}
      -> Button(-text => 'Lägg till',
                -command => [_add => $self],
               )
      -> pack(-side => 'left');

  # Delete button
  $win_r->{entry_button_delete} = $win_r->{entry_button_area}
      -> Button(-text => 'Ta bort',
                -command => [_delete => $self],
               )
      -> pack(-side => 'left');

  # Clear button
  $win_r->{entry_button_clear} = $win_r->{entry_button_area}
      -> Button(-text => 'Rensa',
                -command => [_clear => $self],
               )
      -> pack(-side => 'right');

  # Search forward button
  $win_r->{entry_button_search_f} = $win_r->{entry_button_area}
      -> Button(-text => 'Sök framåt',
                -command => [$self, '_search'],
               )
      -> pack(-side => 'right');

  # Search backward button
  $win_r->{entry_button_search_b} = $win_r->{entry_button_area}
      -> Button(-text => 'Sök bakåt',
                -command => [$self, '_search', 'b'],
               )
      -> pack(-side => 'right');

  ### Button area ###

  # Previous day button
  $win_r->{prev} = $win_r->{button_area}
      -> Button(-text => 'Föregående dag',
                -command => [_prev => $self],
               )
      -> pack(-side => 'left');

  # Next day button
  $win_r->{next} = $win_r->{button_area}
      -> Button(-text => 'Nästa dag',
                -command => [_next => $self],
               )
      -> pack(-side => 'left');

  # Goto day button
  $win_r->{goto} = $win_r->{button_area}
      -> Button(-text => 'Gå till',
                -command => [_goto => $self],
               )
      -> pack(-side => 'left');

  # Goto backward edit day button
  $win_r->{back} = $win_r->{button_area}
      -> Button(-text => 'Bakåt',
                -command => [_back => $self, 'b'],
                -state => 'disabled',
               )
      -> pack(-side => 'left');

  # Goto forward edit day button
  $win_r->{forw} = $win_r->{button_area}
      -> Button(-text => 'Framåt',
                -command => [_forw => $self],
                -state => 'disabled',
               )
      -> pack(-side => 'left');

  # Done button
  $win_r->{done} = $win_r->{button_area}
      -> Button(-text => 'Klart',
                -command => [$self => 'withdraw'],
               )
      -> pack(-side => 'right');
  $self->{done} = [$self => 'done'];

  # UnDo button
  $win_r->{undo} = $win_r->{button_area}
      -> Button(-text => 'Ångra senaste',
                -command => [$self->{-times} => 'undo'],
               )
      -> pack(-side => 'right');
  $win_r->{undo} -> configure(-state => 'disabled')
      unless($self->{-times}->undoGetLength());

  # Register for events from times and undo
  $self->{-times}->setUndo($win_r->{name}, [$self => 'undo']);

  return 0;
} # Method _setup

#----------------------------------------------------------------------------
#
# Method:      _display
#
# Description: Display times for date
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - New date to display
#  2 - Backward or forward
# Returns:
#  -

sub _display($;$$) {
  # parameters
  my $self = shift;
  my ($date, $bwfw) = @_;


  my $win_r = $self->{win};
  if ($date) {
    # Do not edit an archived week
    return
        $win_r->{confirm}
            -> popup(-title  => 'arkiverade',
                     -text  => ['Kan inte redigera för ' . $date,
                                'Registreringar till och med ' .
                                    $self->{-cfg}->get('archive_date') .
                                    ' är arkiverade.'],
                    )
        if ($date le $self->{-cfg}->get('archive_date'));

    $self->_forw($date)
        if (not $bwfw     and
            $self->{date} and
            $self->{date} ne $date);
    $self->{date} = $date;

  } else {
    $date = $self->{date};

  } # if #

  # Save times data
  $self->{-times}->save();

  # Update event configuration
  $self->{-event_cfg} -> modifyArea($win_r, $date);

  # List recorded of a day and update lock
  $self -> update();

  # No current edit line
  $self->{win}{time_area}->set(undef, $date);

  return 0;
} # Method _display

1;
__END__
