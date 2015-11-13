#
package Gui::Main;
#
#   Document: Main window
#   Version:  2.8   Created: 2015-10-14 12:01
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Main.pmx
#

my $VERSION = '2.8';
my $DATEVER = '2015-10-14';

# History information:
#
# 1.0  2006-06-29  Roland Vallgren
#      First issue.
# 1.1  2008-06-16  Roland Vallgren
#      Use status field to report calculate problems
# 1.2  2008-09-06  Roland Vallgren
#      Add earlier menu to show data
# 2.0  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Show day list to the left
# 2.1  2009-04-06  Roland Vallgren
#      Added handling of modify in _validate
#      Use error popup when fault is detected in week worktime
#      Improved status message: configurable timeout and clear by Clear
# 2.2  2006-12-19  Roland Vallgren
#      Dont updatedaylist if no daylist is shown
# 2.3  2011-03-27  Roland Vallgren
#      Save files before GUI is closed
# 2.4  2012-08-19  Roland Vallgren
#      Do not disable buttons on edit. New button remove
# 2.5  2012-09-10  Roland Vallgren
#      Remove button should check for lock
# 2.6  2013-05-18  Roland Vallgren
#      Handle lock of session
# 2.7  2013-10-15  Roland Vallgren
#      Corrected unlock time
# 2.8  2015-09-29  Roland Vallgren
#      Use joinAdd method in Times
#      Stop repeat from clock when Tidbox quit
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
#              Create main GUI
#
# Arguments:
#  0 - Object prototype
# Additional arguments as hash
#  -cfg        Reference to configuration hash
#  -event_cfg  Event configuration object
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

  my $self = {@_,
              win     => {name => 'main'},
              message => 0,
             };

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      showWarn
#
# Description: Use main window confirm popup
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub showWarn($%) {
  # parameters
  my $self = shift;


  $self->{win}{confirm} -> popup(@_)
      if exists($self->{win}{confirm});

  return 0;
} # Method showWarn

#----------------------------------------------------------------------------
#
# Method:      _status
#
# Description: Show status
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Force update, override message
# Returns:
#  -

sub _status($;$) {
  # parameters
  my $self = shift;
  my ($update) = @_;


  $self->{message} = 0
      if ($update);

  my $now_date = $self->{-clock}->getDate();
  my $now_hour = $self->{-clock}->getHour();
  my $now_minu = $self->{-clock}->getMinute();

  my $win_r = $self->{win};
  $win_r->{day_list}->see(undef, $now_hour . ':' . $now_minu)
      if ($win_r->{day_list});

  return $self->{message}--
      if ($self->{message});

  my $entry_text;
  my $show_data_text = '';
  my $last_state = '';
  my $last_event = '';
  my ($last_hour, $last_minu) = (0, 0);

  # Find out ongoing activity
  for my $ref (reverse($self->{-times}->getSortedRefs($now_date))) {

    next unless (substr($$ref, 17) =~ /^($TYPE),(.*)$/);
    my ($state, $text) = ($1, $2);
    my $hour = substr($$ref, 11, 2);
    my $minu = substr($$ref, 14, 2);

    next if ((($now_hour == $hour) and ($now_minu < $minu)) or
             ($now_hour < $hour));

    if (not defined($entry_text)) {
      if ($self->{-cfg}->get('show_reg_date')) {
        $show_data_text=
            $self->{-calculate}->format($now_date, $hour.':'.$minu, $state, $text);
      } else {
        $show_data_text=
            $self->{-calculate}->format(undef, $hour.':'.$minu, $state, $text);
      } # if #

      if ($state eq $BEGINEVENT or
          $state eq $ENDEVENT or
          $state eq $BEGINWORKDAY or
          $state eq $ENDPAUS)
      {
        $last_state = $WORKDAY;
        $last_event = $text
            if $state eq $BEGINEVENT;
      } else {
        $last_state = $state;
      } # if #
      ($last_hour, $last_minu) = ($hour, $minu);
      $entry_text = $text;

    } elsif ($state eq $BEGINEVENT and $entry_text ne $text) {
      $self->{-earlier}->setPrev($text);
      last;
    } # if #

  } # for #


  my $show_data = $self->{-cfg}->get('show_data');

  if ($last_state eq $BEGINPAUS and $show_data == 3) {
    # Show paus time
    $win_r->{show_data}
        -> configure(-text=> 'Paus : ' .
        $self->{-calculate}->hours(
               $self->{-calculate}->deltaMinutes($last_hour, $last_minu,
                                                 $now_hour , $now_minu )
                         ) . ' timmar');

  } elsif ($last_state eq $WORKDAY and
           $self->{-supervision}->is($last_event))
  {
    # Show time for supervised activity
    my ($m, $e) = $self->{-supervision}->calc();
    $win_r->{show_data}
        -> configure(-text=> 'Bevaka: ' .
                     $self->{-calculate}->hours($m) .
                     ' timmar: ' .
                     $e
                    );

  } elsif ($last_state eq $WORKDAY and $show_data) {
    $self->{-supervision}->clear();
    if ($show_data == 1) {
      # Show worktime for today
      my $day_r = $self->{-calculate}
          -> dayWorkTimes($now_date, 0, $self->{-error_popup});
      $win_r->{show_data}
          -> configure(-text =>
                       'Arbetstid idag: ' .
                       $self->{-calculate}->hours($day_r->{work_time}) .
                       ' timmar');

    } elsif ($show_data == 2) {
      # Show worktime for this week
      $win_r->{show_data}
          -> configure(-text =>
                 'Arbetstid denna vecka: ' .
                 $self->{-calculate}->hours(scalar(
                     $self->{-calculate}->weekWorkTimes($now_date, 0,
                                                        $self->{-error_popup})
                 )) .
                 ' timmar');

    } elsif ($show_data == 3) {
      # Show time for current activity
      $entry_text = 'Arbete' unless $entry_text;
      $win_r->{show_data}
          -> configure(-text=> $entry_text . ' : ' .
          $self->{-calculate}->hours(
                 $self->{-calculate}->deltaMinutes($last_hour, $last_minu,
                                                   $now_hour , $now_minu )
                           ) . ' timmar');

    } # if #

  } else {
    # Show ongoing activity
    $win_r->{show_data} -> configure(-text=>$show_data_text);

  } # if #
  return 0;
} # Method _status

#----------------------------------------------------------------------------
#
# Method:      _message
#
# Description: Show message
#
# Arguments:
#  0 - Object reference
#  1 - Text to show
# Returns:
#  -

sub _message($$) {
  # parameters
  my $self = shift;
  my ($text) = @_;


  $self->{win}{show_data} -> configure(-text=>$text);
  $self->{message} = $self->{-cfg}->get('show_message_timeout');

  return 0;
} # Method _message

#----------------------------------------------------------------------------
#
# Method:      _msgUpdate
#
# Description: Show message and update Gui
#              If called without text dots are added
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Text to show
# Returns:
#  -

sub _msgUpdate($;$) {
  # parameters
  my $self = shift;
  my ($text) = @_;


  if ($text) {
    $self->{message_text} = $text;
  } else {
    $self->{message_text} .= '.';
  } # if #

  $self->_message($self->{message_text});
  $self->{win}{win}->update();

  return 0;
} # Method _msgUpdate

#----------------------------------------------------------------------------
#
# Method:      _enableButtons
#
# Description: Enable buttons
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _enableButtons($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  if ($win_r->{event_modify} and not $self->{edit_event_ref}) {
    $win_r->{event_modify} -> configure(-state => 'disabled');
    $win_r->{event_delete} -> configure(-state => 'disabled');
  } # if #

  # Also clear messages
  $self->_status(1);

  return 0;
} # Method _enableButtons

#----------------------------------------------------------------------------
#
# Method:      _disableButtons
#
# Description: Disable buttons
#
# Arguments:
#  0 - Object reference
# Optional Arguments
#  1 - If true all buttons are disabled
# Returns:
#  -

sub _disableButtons($;$) {
  # parameters
  my $self = shift;
  my ($all) = @_;


  my $win_r = $self->{win};

  $win_r->{day_start}   -> configure(-state => 'disabled');
  $win_r->{day_end}     -> configure(-state => 'disabled');
  $win_r->{paus_start}  -> configure(-state => 'disabled');
  $win_r->{paus_end}    -> configure(-state => 'disabled');
  $win_r->{event_end}   -> configure(-state => 'disabled');

  return 0;
} # Method _disableButtons

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear event text
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - If set clear event radio buttons
# Returns:
#  -

sub _clear($;$) {
  # parameters
  my $self = shift;
  my ($clear) = @_;


  my $win_r = $self->{win};

  $self->{-event_cfg} -> clearData($win_r, $clear);
  if ($self->{edit_event_ref}) {
    $win_r->{time_area}->clear();
    $win_r->{day_list}->clear();
    $self->{edit_event_type} = undef;
    $self->{edit_event_ref} = undef;
  } # if #

  $self->_enableButtons();

  # Also clear messages
  $self->_status(1);

  return 0;
} # Method _clear

#----------------------------------------------------------------------------
#
# Method:      _isLocked
#
# Description: Handle lock in status
#
# Arguments:
#  0 - Object reference
#  1 - Date to check lock
# Returns:
#  Lock status from Configuration

sub _isLocked($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  my ($lock, $locked) = $self->{-cfg}->isLocked($date);
  $self->_message($lock == 1 ? "$date är låst" : $locked)
      if ($lock);
  return $lock;
} # Method _isLocked

#----------------------------------------------------------------------------
#
# Method:      _get
#
# Description: Get event data from Gui
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Action
#  - Reference to event text to use
# Returns:
#  Event

sub _get($;$$) {
  # parameters
  my $self = shift;
  my ($action, $ref) = @_;


  my $win_r = $self->{win};

  my ($time, $date) = $win_r->{time_area}->get();

  return undef
      unless (defined($time) and defined($date));

  return undef
    if ($self->_isLocked($date));

  unless ($action eq $BEGINEVENT) {

    $win_r->{time_area}->clear();
    $self->_clear();

    return (join(',', $date,
                      $time,
                      $action,
                      '')
           );
  } # unless #

  if (ref($ref)) {

    # Return event from earlier menu or button
    $win_r->{time_area}->clear();
    $self->_clear();

    $self->{-earlier}->add($$ref);

    return (join(',', $date,
                      $time,
                      $action,
                      $$ref)
           );
  } # if #

  my $action_text = $self->{-event_cfg}->getData($win_r, [$self, '_message']);

  return undef
      unless (defined($action_text));

  $win_r->{time_area}->clear();
  $self->_clear();

  $self->{-earlier}->add($action_text);

  return (join(',', $date,
                    $time,
                    $BEGINEVENT,
                    $action_text)
         );
} # Method _get

#----------------------------------------------------------------------------
#
# Method:      _add
#
# Description: Add a new event
#
# Arguments:
#  - Object reference
#  - Type of event to register
# Optional Arguments:
#  - Reference to event text, for example from earlier meny
# Returns:
#  -

sub _add($$;$) {
  # parameters
  my $self = shift;
  my ($action, $ref) = @_;


  my $line = $self->_get($action, $ref);

  return 0
      unless (defined($line));

  $self->{-times}->add($line);
  $self->_message('Ny registrering tillagd');
  return 0;
} # Method _add

#----------------------------------------------------------------------------
#
# Method:      _modify
#
# Description: Modify the shown event
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - True => Return pressed
# Returns:
#  -

sub _modify($;$) {
  # parameters
  my $self = shift;
  my ($return) = @_;


  return $self->_add($BEGINEVENT)
      if ($return and not $self->{edit_event_ref});

  return $self->_message('Inget markerat att ändra')
      unless (ref($self->{edit_event_ref}));

  # Get reference as _get clears the reference
  my $event_ref = $self->{edit_event_ref};

  my $line = $self->_get($self->{edit_event_type});

  return 0
      unless (defined($line));

  return $self->_message('Ingen ändring')
      if (${$event_ref} eq $line);

  $self->{-times}->change($event_ref, $line);
  $self->_message('Registrering ändrad');
  return 0;
} # Method _modify

#----------------------------------------------------------------------------
#
# Method:      _delete
#
# Description: Delete the shown event
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _delete($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  my ($time, $date) = $win_r->{time_area}->get();

  return undef
      unless (defined($time) and defined($date));

  return undef
      if ($self->_isLocked($date));

  return $self->_message('Inget markerat att ta bort')
      unless (ref($self->{edit_event_ref}));

  $self->{-times}->change($self->{edit_event_ref});
  $self->_message('Registrering borttagen');
  return 0;
} # Method _delete

#----------------------------------------------------------------------------
#
# Method:      _updated
#
# Description: This is the callback for whenever the times data is updated
#
# Arguments:
#  0 - Object reference
#    1 .. n - Dates impacted by the update
#    1, 2, 3 - '-', d1, d2 Range of dates impacted by the update
# Returns:
#  -

sub _updated($@) {
  # parameters
  my $self = shift;
  my (@dates) = @_;


  $self->_status(1)
      if ($self->{-calculate}->impactedDate($self->{-clock}->getDate(), @dates));

  return 0;
} # Method _updated

#----------------------------------------------------------------------------
#
# Method:      _buttons
#
# Description: Add buttons in the event cfg area
#
# Arguments:
#  0 - Object reference
#  1 - Area where buttons should be added
# Returns:
#  -

sub _buttons($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;


  my $win_r = $self->{win};

  $win_r->{evbutt_area} = $area;

  $win_r->{event_clear} = $area
      -> Button(-text => 'Rensa', -command => [$self, '_clear'])
      -> pack(-side => 'right');

  $win_r->{event_end} = $area
      -> Button(-text => 'Sluta', -command => [$self, '_add', $ENDEVENT])
      -> pack(-side => 'right');

  $win_r->{event_start} = $area
      -> Button(-text => 'Börja', -command => [$self, '_add', $BEGINEVENT])
      -> pack( -side=>'right');

  if ($win_r->{day_list}) {
    $win_r->{event_modify} = $area
        -> Button(-text => 'Ändra',
                  -command => [$self, '_modify'],
                  -state => 'disabled')
        -> pack( -side=>'right');

    $win_r->{event_delete} = $area
        -> Button(-text => 'Ta bort',
                  -command => [$self, '_delete'],
                  -state => 'disabled')
        -> pack( -side=>'right');
  } # if #

  return 0;
} # Method _buttons

#----------------------------------------------------------------------------
#
# Method:      _validate
#
# Description: Handle a change in the event area
#              Changed text is lightly analysed
#              Radiobutton change
#
# Arguments:
#  0 - Object reference
# Validation Arguments, if text is changed, otherwise undef:
#  1 - The proposed value of the entry.
#  2 - The characters to be added (or deleted).
#  3 - The current value of entry i.e. before the proposed change.
#  4 - Index of char string to be added/deleted, if any. -1 otherwise
#  5 - Type of action. 1 == INSERT, 0 == DELETE, -1 if it's a forced
# Returns:
#  0 - True, event is allways allowed
#
# Returns:
#  -

sub _validate($$$$$$) {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;


  my ($len, undef) = $self->{-event_cfg}->getData($self->{win});

  if (defined($proposed)) {

    # Handle text entry
    # ??? Handle strange version of Tk
    $insert -= 7 if $insert > 1;
    unless ($insert == 1 or
            ($insert == 0 and $len > 1))
    {
      return 1;
    } # unless #
  } # if #

  $self->{edit_event_type} = $BEGINEVENT
      if ($self->{edit_event_ref});

  return 1;
} # Method _validate

#----------------------------------------------------------------------------
#
# Method:      _earlier
#
# Description: Callback for earlier menu. Event is either added or inserted.
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event to add
# Returns:
#  -

sub _earlier($$) {
  # parameters
  my $self = shift;
  my ($text, $date, $time, $type, $event_data) = @_;


  my $win_r = $self->{win};

  # Data from earlier menu
  return $self->{-event_cfg}->putData($win_r, $$text)
      if (ref($text));

  return 0;
} # Method _earlier

#----------------------------------------------------------------------------
#
# Method:      _grabLock
#
# Description: Grab the lock from another session
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _grabLock($) {
  # parameters
  my $self = shift;

  my $date = $self->{-clock}->getDate();
  my $time = $self->{-clock}->getTime();
  $self->{-lock}->lock($date, $time, 1);
  $self->{-clock}->setLocked(undef);
  my $win_r = $self->{win};
  $win_r->{day_list}->update($date)
      if ($win_r->{day_list});
  $self->{-edit_win}->update();
  $self->{-week_win}->update();
  Version->register_locked_session("Du låste upp Tidbox:" .
                                   "\n  Datum: " . $date .
                                   "\n  Tid: " . $time
                                  );
  my $ev = $self->{-event_cfg}->getEmpty('Du låste upp Tidbox');
  $self->{-times}->joinAdd($date, $time, $BEGINEVENT, $ev);
  return 0;
} # Method _grabLock

#----------------------------------------------------------------------------
#
# Method:      show
#
# Description: Callback for daylist selection.
#              Date, time and event are inserted.
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event to show
# Returns:
#  -

sub show($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;


  if (ref($ref) and
      (${$ref} =~ /^($DATE),($TIME),($TYPE),(.*)$/o)) {
    my ($date, $time, $type, $event_data) = ($1, $2, $3, $4);
    $self->{edit_event_ref} = undef;
    $self->{edit_event_type} = undef;
    $self->_clear(1);
    my $win_r = $self->{win};
    $win_r->{time_area}->set($time, $date);
    $self->{-event_cfg}->putData($win_r, $event_data)
        if (defined($event_data) and ($type eq $BEGINEVENT));
    if ($win_r->{event_modify}) {
      $win_r->{event_modify} -> configure(-state => 'normal');
      $win_r->{event_delete} -> configure(-state => 'normal');
    } # if #
    $self->{edit_event_ref} = $ref;
    $self->{edit_event_type} = $type;
  } else {
    $self->_clear();
    $self->{edit_event_ref} = undef;
    $self->{edit_event_type} = undef;
  } # if #

  return 0;
} # Method show

#----------------------------------------------------------------------------
#
# Method:      showLocked
#
# Description: Show session locked dialog
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub showLocked($) {
  # parameters
  my $self = shift;

  # Show popup due to session lock
  $self->{win}->{confirm}
          -> popup(-title  => 'Tidbox är låst',
                   -text   => ["Tidbox är låst!\n" .
                               "En låsfil hittades:",
                               "En annan instans av Tidbox kan vara aktiv eller \n" .
                               "så finns låsfilen kvar efter att Tidbox har avslutats\n" .
                               "på ett felaktigt sätt.",
                               "Om du är helt övertygad om att ingen annan\n" .
                               "Tidbox är igång så kan du låsa upp och ta\n" .
                               "över låset.\n"
                              ],
                   -data   => [$self->{-lock}->get()],
                   -buttons => [
                                'Enbart läsning', undef,
                                'Lås upp',        [ $self, '_grabLock', 0 ],
                               ]

                  );
  return 0;
} # Method showLocked

#----------------------------------------------------------------------------
#
# Method:      _dated
#
# Description: Open a subwindow, get date
#
# Arguments:
#  0 - Object reference
#  1 - Reference to dated object to show
# Returns:
#  -

sub _dated($$) {
  # parameters
  my $self = shift;
  my ($ext) = @_;


  my $win_r = $self->{win};

  my $date = $win_r->{time_area}->get(1);
  return 0 unless $date;

  # Can not handle an archived week
  return
      $win_r->{confirm}
        -> popup(-title  => 'arkiverade',
                 -text  => ['Kan inte hantera ' . $date,
                            'Registreringar till och med ' .
                                $self->{-cfg}->get('archive_date') .
                                ' är arkiverade.'],
                )
      if ($date le $self->{-cfg}->get('archive_date'));

  $win_r->{time_area}->clear(1);
  $ext->display($date);

  return 0;
} # Method _dated

#----------------------------------------------------------------------------
#
# Method:      _setup
#
# Description: Setup the contents of the main window
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _setup($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  ### Heading ####
  $self->{-clock}->setDisplay($win_r->{name}, $win_r->{title});

  # Start timer for clock
  $win_r->{title_timer} = $win_r->{win}
      -> repeat(1000, [tick => $self->{-clock}]);

  ### Area for day list and main window ####
  if ($self->{-cfg}->get('main_show_daylist')) {
    $win_r->{left_area} = $win_r->{area}
        -> Frame()
        -> pack(-side => 'left', -expand => '1', -fill => 'both');
    $win_r->{right_area} = $win_r->{area}
        -> Frame()
        -> pack(-side => 'right', -expand => '1', -fill => 'both');
  } else {
    $win_r->{right_area} = $win_r->{area};
  } # if #

  # Day list listbox to the left
  $win_r->{day_list} =
    new Gui::DayList(-area => $win_r->{left_area},
                     -side => 'left',
                     -showEvent => [$self => 'show'],
                     -times     => $self->{-times},
                     -calculate => $self->{-calculate},
                     -clock     => $self->{-clock},  # List should show today
                     -cfg       => $self->{-cfg},
                     -parentName => $win_r->{name},
                    )
      if ($self->{-cfg}->get('main_show_daylist'));

  ## Time handling ##
  $win_r->{time_area} =
      new Gui::Time(
                    -area      => $win_r->{right_area},
                    -calculate => $self->{-calculate},
                    -time      => [$self, '_modify', 1],
                    -date      => [$self, '_dated', $self->{-edit_win}],
                    -invalid   => [$self, '_message'],
                   );

  ## Workday handling ##
  $win_r->{day_paus_area} = $win_r->{right_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $win_r->{day_text} = $win_r->{day_paus_area}
      -> Label(-text => 'Arbetsdagen:')
      -> pack(-side => 'left');

  $win_r->{day_start} = $win_r->{day_paus_area}
      -> Button(-text => 'Börja', -command => [$self, '_add', $BEGINWORKDAY])
      -> pack(-side => 'left');

  $win_r->{day_end} = $win_r->{day_paus_area}
      -> Button(-text => 'Sluta', -command => [$self, '_add', $ENDWORKDAY])
      -> pack(-side => 'left');

  ## Paus handling ##
  $win_r->{paus_end} = $win_r->{day_paus_area}
      -> Button(-text => 'Sluta', -command => [$self, '_add', $ENDPAUS])
      -> pack(-side => 'right');

  $win_r->{paus_start} = $win_r->{day_paus_area}
      -> Button(-text => 'Börja', -command => [$self, '_add', $BEGINPAUS])
      -> pack(-side => 'right');

  $win_r->{paus_text} = $win_r->{day_paus_area}
      -> Label(-text => 'Paus:')
      -> pack(-side => 'right');

  ## Configurable event handling ##
  $win_r->{event_area} = $win_r->{right_area}
      -> Frame(-bd => '1', -relief => 'raised')
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $win_r->{evbutt_area} = $self->{-event_cfg}
      -> createArea(-win      => $win_r,
                    -area     => $win_r->{event_area},
                    -validate => [$self, '_validate'],
                    -buttons  => [$self, '_buttons'],
                    -return   => [$self, '_modify', 1],
                   );

  ### Previous handling ###
  $win_r->{previous_area} = $win_r->{right_area}
      -> Frame(-bd => '2', -relief => 'sunken')
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $win_r->{previous_text} = $win_r->{previous_area}
      -> Label(-text => 'Tidigare:')
      -> pack(-side => 'left');

  ### Previous menu ###
  $win_r->{previous_add} = $self->{-earlier}->
      create($win_r->{previous_area},
             'left',
             [$self, '_add', $BEGINEVENT],
             'Lägg till');

  $win_r->{previous_show} = $self->{-earlier}->
      create($win_r->{previous_area},
             'left',
             [$self, '_earlier'],
             'Visa');

  ### Previous button ###
  $win_r->{previous_prevbut} = $self->{-earlier}->
      prevBut($win_r->{previous_area}, [$self, '_add', $BEGINEVENT]);

  ### Show data ###
  $win_r->{show_area} = $win_r->{right_area}
      -> Frame(-bd => '2', -relief => 'sunken')
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $win_r->{show_data} = $win_r->{show_area}
      -> Label()
      -> pack(-side => 'left');

  ### Buttons area ###
  # Show buttons below ordinary area to allow the daylist to grow besides
  # the buttons
  $win_r->{butt_area} = $win_r->{right_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  ## calculate whole week ##
  $win_r->{week} = $win_r->{butt_area}
      -> Button(-text => 'Veckan',
                -command => [$self, '_dated', $self->{-week_win}])
      -> pack(-side => 'left');

  ## Edit entrys ##
  $win_r->{edit} = $win_r->{butt_area}
      -> Button(-text => 'Redigera',
                -command => [$self, '_dated', $self->{-edit_win}])
      -> pack(-side => 'left');

  ## Settings ##
  $win_r->{sett} = $win_r->{butt_area}
      -> Button(-text => 'Inställningar',
                -command => [$self->{-sett_win} => 'display'])
      -> pack(-side => 'left');

  ## Quit ##
  $win_r->{quit} = $win_r->{butt_area}
      -> Button(-text => 'Avsluta',
                -command => [$self => 'destroy'])
      -> pack(-side => 'right');
  $self->{done} = [$self => '_quit'];

  # Now we have enough to show status:
  $self->_status();

  # . Subscribe to updated event data
  $self->{-times}->setDisplay($win_r->{name}, [$self, '_updated']);

  # . Set lock status in title clock
  my ($lock, $locked) = $self->{-cfg}->isSessionLocked();
  $self->{-clock}->setLocked($locked)
      if ($lock);

  # . Register _status for one minute ticks
  $self->{-clock}->repeat(-minute => [$self, '_status']);

  # Warnings during startup, show popup
  $self->callback($self->{-start_warning});

  return 0;
} # Method _setup

#----------------------------------------------------------------------------
#
# Method:      _display
#
# Description: Display ?
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _display($) {
  # parameters
  my $self = shift;

  return 0;
} # Method _display

#----------------------------------------------------------------------------
#
# Method:      _quit
#
# Description: Quit tidbox, quit all other windows
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _quit($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  $win_r->{win}  -> Busy(-recurse => 1);
  $self->_msgUpdate("Avslutar.");
  for my $w (qw(-year_win -sett_win -edit_win -week_win)) {
    $self->_msgUpdate();
    $self->{$w} -> quit();
    $self->{$w} -> withdraw();
  } # for #

  $self->_getPos();
  $self->_msgUpdate();

  $self->_disableButtons();

  $win_r->{event_modify} -> configure(-state => 'disabled');
  $win_r->{event_delete} -> configure(-state => 'disabled');
  $win_r->{event_start}  -> configure(-state => 'disabled');
  $win_r->{event_clear}  -> configure(-state => 'disabled');

#  $win_r->{day_text}      -> configure(-state => 'disabled');
#  $win_r->{paus_text}     -> configure(-state => 'disabled');
#  $win_r->{previous_text} -> configure(-state => 'disabled');

  $win_r->{week}  -> configure(-state => 'disabled');
  $win_r->{edit}  -> configure(-state => 'disabled');
  $win_r->{sett}  -> configure(-state => 'disabled');
  $win_r->{quit}  -> configure(-state => 'disabled');

#  $win_r->{day_list}->quit()
#      if ($win_r->{day_list});
  $win_r->{time_area}->quit();

  $self->{-event_cfg}->quit($win_r->{name});

  $win_r->{previous_add}     -> configure(-state => 'disabled');
  $win_r->{previous_show}    -> configure(-state => 'disabled');
  $win_r->{previous_prevbut} -> configure(-state => 'disabled');

  $self->{-clock}->quit();

  $self->_msgUpdate($self->{message_text}.'Sparar.');
  $self->{-fsv}->end([$self, '_msgUpdate']);
  $self->_msgUpdate('Avslutar');

  return 0;
} # Method _quit

1;
__END__
