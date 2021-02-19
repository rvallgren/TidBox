#
package Gui::Edit;
#
#   Document: Edit day
#   Version:  2.10   Created: 2019-09-13 08:40
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Edit.pmx
#

my $VERSION = '2.10';
my $DATEVER = '2019-09-13';

# History information:
#
# 1.0  2006-06-17  Roland Vallgren
#      First issue.
# 2.0  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Listbox moved to DayList class.
# 2.1  2013-05-18  Roland Vallgren
#      Use isLocked to check lock
# 2.2  2015-09-29  Roland Vallgren
#      Time::getSortedRefs joins
#      Configuration.pm should not have any Gui code
# 2.3  2015-12-10  Roland Vallgren
#      Moved Gui for Event to own Gui class
# 2.4  2017-05-30  Roland Vallgren
#      Adaption for Tk::Adjuster used in DayList
#      Removed hardcoding of undo button to Gui::Edit
# 2.5  2017-10-16  Roland Vallgren
#      References to other objects in own hash
#      Improved handling of return in date field
# 2.6  2018-12-21  Roland Vallgren
#      Backward, forward failed, bug in _forw corrected
# 2.7  2019-01-25  Roland Vallgren
#      Code improvements
# 2.8  2019-04-10  Roland Vallgren
#      Enable search buttons after a search, when a search pattern is added
# 2.9  2019-05-14  Roland Vallgren
#      Control+w in date field starts week
#      Added Copy and Paste one day
#      Search and then return changes time of found event
#      this should only happen if the found event is equal with search string
#      Adapt to changed DayList change see to seeTime
# 2.10  2019-08-29  Roland Vallgren
#       Code improvements: TODO ExcoWord Included from TidBase
#       Code improvements: Reduce knowledge about Times data
#       Copy/Paste and search should be performed by TbFile::Times
#

#----------------------------------------------------------------------------
#
# Setup
#
use base Gui::Base;

use strict;
use warnings;
use Carp;
use integer;

use Tk;

use Gui::Confirm;
use Gui::DayList;
use Gui::Event;

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
#  -title      Tool title
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
# Method:      _isLocked
#
# Description: Check lock
#
# Arguments:
#  0 - Object reference
#  1 - Date to check lock for
# Returns:
#  0 if not locked

sub _isLocked($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  my ($lock, $txt, $lockdate) = $self->{erefs}{-cfg}->isLocked($date);
  if ($lock == 1) {
    $self->{win}->{confirm}
        -> popup(-title => 'information',
                 -text  => ['Kan inte ändra för: '. $date,
                            'Alla veckor till och med ' .
                                 $lockdate . ' är låsta.'],
                );

  } elsif ($lock == 2) {
    $self->{win}->{confirm}
        -> popup(-title => 'information',
                 -text  => ['Tidbox är låst av en annan Tidbox!'],
                );

  } # if #

  return $lock;
} # Method _isLocked

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
  $win_r->{event_handling}->clear(1);

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

    $action_text = $win_r->{event_handling}->get($msg);

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
      $win_r->{event_handling}->set($event_data);
    } else {
      $win_r->{event_handling}->clear(1);
    } # if #
    $self->{type_setting} = $type;
    $self->_message($text);
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
          not $self->{erefs}{-calculate}->impactedDate($self->{date}, @dates));

  my $date = $self->{date};
  $win_r->{day_list}->setDate($date);

  $self->_clear();

  # Update lock display
  my ($lock, $locked) = $self->{erefs}{-cfg}->isLocked($self->{date});

  if (($self->{date} eq $self->{erefs}{-clock}->getDate()) and
      (not $lock))
  {

    $self->{erefs}{-clock}->setDisplay($win_r->{name}, $win_r->{title});

  } else {

    $self->{erefs}{-clock}->setDisplay($win_r->{name}, undef);

    $win_r->{title}
        -> configure(
      -text =>
        $self->{erefs}{-calculate}
           -> dayStr($self->{erefs}{-calculate}->weekDay($self->{date})) .
        ' Vecka: ' . $self->{erefs}{-calculate}->weekNumber($self->{date}) .
        ' Datum: ' . $self->{date} .
        '  ' . $locked
                    );
  } # if #

  # Update undo button
  $self->undo(0, $self->{erefs}{-times}->undoGetLength());

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

  $self->{erefs}{-earlier}->add($action_text);

  my $search_text = $action_text;

  # "PERLify" user entered wildcards if no perl regexps detected
  unless ($search_text =~ /(?:[\\[\]{}+^]|\.[+*])/) {
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
  my $start_date;
  my $start_time;
  my $ref = $win_r->{day_list}->curselection();
  $ref = $win_r->{day_list}->highlited()
      unless ($ref);
  if (ref($ref)) {
    $start_date = substr($$ref, 0, 10);
    $start_time = substr($$ref, 11, 5);
  } else {
    $start_date = substr($line, 0, 10);
    $start_time = substr($line, 11, 5);
  } # if #

  # Search in event data
  my ($found_date, $found_time, $found_text, $fnd) =
       $self->{erefs}{-times}->
                    searchEvent($back, $start_date, $start_time, $search_text);

  return $self->_message('Hittade ingenting')
      unless (defined($found_date));

  # Display the date for the found event
  $self->_display($found_date)
      unless ($self->{date} eq $found_date);

  # Display the found event
  if ($action_text eq $found_text) {
    if ($win_r->{day_list}->selectEvent($fnd)) {
      $self->show($fnd, 'Sökt exakt: ' . $action_text);
    } # if #

  } else {
    $win_r->{day_list}->activateEvent($fnd);
    $win_r->{event_handling}->set($action_text, 1);
    $self->_validate();
    $win_r->{entry_button_change} -> configure(-state => 'disabled');
    $win_r->{entry_button_delete} -> configure(-state => 'disabled');
    $self->_message('Sökt match: ' . $action_text);
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
  $self->{win}->{event_handling}->set($$ref);
  $self->_enableAdd();
  $self->_message('');
  return 0;
} # Method _previous

#----------------------------------------------------------------------------
#
# Method:      copyDate
#
# Description: Copy all day, save todays date in copy attribute
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub copyDate($) {
  # parameters
  my $self = shift;

  $self->{win}{paste_date} -> configure(-state => 'normal')
      unless ($self->{copy_from});
  $self->{copy_from} = $self->{date};
  $self->_message('Kopiera ' . $self->{date});
  $self->{win}{paste_date} ->
                         configure(-text => 'Klistra in från ' . $self->{date});
  return 0;
} # Method copyDate

#----------------------------------------------------------------------------
#
# Method:      pasteDate
#
# Description: Paste date, that is copy all events from copy_from to today
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub pasteDate($) {
  # parameters
  my $self = shift;


  return undef
      unless ($self->{copy_from});

  my $res = 
      $self->{erefs}{-times}->copyPaste($self->{copy_from}, $self->{date});

  $self->update();
  if (not defined($res)) {
    $self->_message('Fel: Kunde inte kopiera')
  } elsif ($res eq '0') {
    $self->_message('Inga händelser kopierade')
  } else {
    $self->_message($res)
  } # if #
      
  return 0;
} # Method pasteDate

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


  $self->{erefs}{-times}->add($line);
  $self->{erefs}{-earlier}->add($action_text);

  $self->update();

  $self->{win}{day_list}->seeTime(substr($line, 11, 5))
      if ($date eq $self->{date});


  if ($date eq $self->{date}) {
    $self->_message('Ny registrering tillagd');

  } elsif ($date eq $self->{erefs}{-clock}->getDate()) {
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
    if ($self->_isLocked($date)) {
      # The date is locked, can not complete operation

    } elsif ($date eq $self->{date}) {
      $self->_doAdd($line, $action_text, $date);

    } else {
      $win_r->{confirm}
          -> popup(-title  => 'bekräfta',
                   -text   => ['Lägg till för annan dag?'],
                   -data   => [$self->{erefs}{-calculate}->format($line)],
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


  $self->{erefs}{-earlier}->add($action_text);

  $self->{erefs}{-times}->change($event_ref, $line);

  $self->update();

  $self->{win}{day_list}->seeTime(substr($line, 11, 5))
      if ($date eq $self->{date});

  if ($date eq $self->{date}) {
    $self->_message('Registrering ändrad');

  } elsif ($date eq $self->{erefs}{-clock}->getDate()) {
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
          if ($self->_isLocked($date) or
              $self->_isLocked($self->{date}));

      if (${$event_ref} ne $line) {

        if ($date eq $self->{date}) {
          $self->_doChange($event_ref, $line, $action_text, $date);

        } else {
            $win_r->{confirm}
                -> popup(-title  => 'bekräfta',
                         -text   => ['Flytta till annan dag?'],
                         -data   => [$self->{erefs}{-calculate}->format($line)],
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
        if ($self->_isLocked($self->{date}));

    $self->{erefs}{-times}->change($event_ref);

    $self->update();

    $self->_message('Registrering borttagen');

  } else {
    $self->_message('Ingen registrering vald');
  } # if #
  return 0;
} # Method _delete

#----------------------------------------------------------------------------
#
# Method:      _week
#
# Description: Open week window for the date
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _week($;$) {
  # parameters
  my $self = shift;


  my $date = $self->{win}{time_area}->get(1);

  $self->{erefs}{-week_win}->display($date)
      if $date;

  return 0;
} # Method _week

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
# Method:      _dateReturn
#
# Description: Return pressed in date, change event or goto specified edit day
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _dateReturn($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  my $event_ref = $win_r->{day_list}->curselection();

  if (ref($event_ref)) {

    my ($line, $action_text, $date) = $self->_get([$self, '_message']);

    return $self->_change(1)
        if (defined($line) and ${$event_ref} ne $line);
  } # if #

  my $date = $win_r->{time_area}->get(1);
  $self->_display($date)
      if $date;

  return 0;
} # Method _dateReturn

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
           $self->{erefs}{-calculate}->stepDate($date, -1))
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
           $self->{erefs}{-calculate}->stepDate($date, 1))
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


  $self->{erefs}{-times}->save();

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

  $self->{erefs}{-earlier}->create($area, 'right', [ $self, '_previous' ]);
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

  ### Daylist ###
  $win_r->{day_list} =
   Gui::DayList->new(-area       => $win_r->{area},
                     -side       => 'left',
                     -showEvent  => [$self => 'show'],
                     erefs => {
                       -times      => $self->{erefs}{-times},
                       -calculate  => $self->{erefs}{-calculate},
                       -cfg        => $self->{erefs}{-cfg},
                              },
                     -parentName => $win_r->{name},
                    );
  ### Entry edit ###
  ### Entry edit area ###
  $win_r->{entry_area} = $win_r->{area}
      -> Frame()
      -> pack(-side => 'left', -expand => '1', -fill => 'both');

  ### Entry edit time ###
  $win_r->{time_area} =
   Gui::Time->new(
                  -area      => $win_r->{entry_area},
                  erefs => {
                    -calculate => $self->{erefs}{-calculate},
                           },
                  -time      => [$self, '_change'],
                  -date      => [$self, '_dateReturn'],
                  -week      => [$self, '_week'],
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

  ### Entry edit configurable event ###
  $win_r->{entry_event_area} = $win_r->{entry_area}
      -> Frame(-bd => '1', -relief => 'raised')
      -> pack(-side => 'top', -fill => 'both');
  $win_r->{event_handling} =
     Gui::Event->new(
                    erefs => {
                      -event_cfg => $self->{erefs}{-event_cfg},
                      -date      => $self->{erefs}{-clock}->getDate(),
                             },
                    -area      => $win_r->{entry_event_area},
                    -validate  => [$self => '_validate'],
                    -buttons   => [$self => '_earlierAdd'],
                    -return    => [$self => '_change'],
                    -parentName => $win_r->{name},
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
                -command => [_back => $self],
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

  # Week window button
  $win_r->{week} = $win_r->{button_area}
      -> Button(-text => 'Veckan',
                -command => [_week => $self],
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
                -command => [$self->{erefs}{-times} => 'undo', $self, 'popup'],
               )
      -> pack(-side => 'right');
  $win_r->{undo} -> configure(-state => 'disabled')
      unless($self->{erefs}{-times}->undoGetLength());

  # Copy all events from today
  $win_r->{copy_button} = $win_r->{button_area}
      -> Button(-text => 'Kopiera dagen',
                -command => [copyDate => $self],
               )
      -> pack(-side => 'right');

  # Paste all events from copied date
  $win_r->{paste_date} = $win_r->{button_area}
      -> Button(-text => 'Klistra in dag',
                -command => [pasteDate => $self],
                -state => 'disabled',
               )
      -> pack(-side => 'right');

  # Register for events from times and undo
  $self->{erefs}{-times}->setUndo($win_r->{name}, [$self => 'undo']);

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
                                    $self->{erefs}{-cfg}->get('archive_date') .
                                    ' är arkiverade.'],
                    )
        if ($date le $self->{erefs}{-cfg}->get('archive_date'));

    $self->_forw($date)
        if (not $bwfw     and
            $self->{date} and
            $self->{date} ne $date);
    $self->{date} = $date;

  } else {
    $date = $self->{date};

  } # if #

  # Save times data
  $self->{erefs}{-times}->save();

  # Update event configuration
  $win_r->{event_handling}->modifyArea($date);

  # List recorded of a day and update lock
  $self->update();

  # No current edit line
  $self->{win}{time_area}->set(undef, $date);

  return 0;
} # Method _display

1;
__END__
