#
package TbFile::Times;
#
#   Document: Times data
#   Version:  1.14   Created: 2019-10-07 12:28
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Times.pmx
#

my $VERSION = '1.14';
my $DATEVER = '2019-10-07';

# History information:
#
# 1.0  2007-02-08  Roland Vallgren
#      First issue.
# 1.1  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
# 1.2  2007-06-17  Roland Vallgren
#      Added subscription of updates
# 1.3  2008-03-30  Roland Vallgren
#      Added support for archive
# 1.4  2008-09-06  Roland Vallgren
#      _getUndoDates returns if undo is empty
#      End of undo set displays changes
# 1.5  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.6  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
#      Session handles starttime, uptime, etc.
# 1.7  2012-06-04  Roland Vallgren
#      not_set_start => start_operation :  none, workday, event, end pause
# 1.8  2015-08-11  Roland Vallgren
#      Use own event as start operation
#      Added registration of end of sleep event
#      Removed check of old setting 'not_set_start'
#      New method joinAdd to add event data
# 1.9  2016-01-15  Roland Vallgren
#      setDisplay moved to TidBase
#      Added handling of midnight
# 1.10  2017-09-07  Roland Vallgren
#       Removed undo button hardcoded to Gui::Edit
#       Removed support for import of earlier Tidbox data
# 1.11  2017-10-05  Roland Vallgren
#       Move files to TbFile::<file>
#       Added merge to add unique times data into another Times
#       References to other objects in own hash
# 1.12  2019-02-07  Roland Vallgren
#       Removed log->trace
# 1.13  2019-05-17  Roland Vallgren
#       Handle copy/paste date in undo set
# 1.14  2019-08-29  Roland Vallgren
#       Code improvements: TODO ExcoWord Included from TidBase
#       Copy/Paste, search should be performed by TbFile::Times
#       Weeks moved from Year
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base TbFile::Base;

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
# Constants
#

use constant FILENAME  => 'times.dat';
use constant FILEKEY   => 'REGISTERED TIME EVENTS';

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
# Function section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Function:    _cmpTimes
#
# Description: Compare times, skip undef values
#
# Arguments:
#  -
# Returns:
#  -

sub _cmpTimes {
  return $a cmp $b if ($a and $b);
  return  1 if ($a);
  return -1 if ($b);
  return  0;
} # sub _cmpTimes

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create times data object
#
# Arguments:
#  0 - Object prototype
# Additional arguments as hash
#  -cfg        Reference to cfg data
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              times   => [],
              undo    => [],
              set     => undef,
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      undoClear
#
# Description: Empty undo list
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub undoClear($) {
  # parameters
  my $self = shift;

  @{$self->{undo}}  = ();

  return 0;
} # Method undoClear

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all times data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  @{$self->{times}} = ();
  $self->undoClear();

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Read times data from file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
# Returns:
#  0 if success

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;

  my $t_r = $self->{times};

  # Read times data

  while (defined(my $line = $fh->getline())) {

    $line =~ s/\s+$//;

    last
        unless $line;

    last
        unless ($line =~ /^$DATE,$TIME,$TYPE,/o);

    push @$t_r, $line;

  } # while #

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save times data to file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
# Returns:
#  -

sub _save($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  for my $line (sort _cmpTimes @{$self->{times}}) {
    $fh->print($line , "\n")
        if ($line);
  } # for #

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      _append
#
# Description: Append event to file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
#  2 - Event to add
# Returns:
#  -

sub _append($$$) {
  # parameters
  my $self = shift;
  my ($fh, $event) = @_;

  $fh->print($event, "\n");

  return 0;
} # Method _append

#----------------------------------------------------------------------------
#
# Method:      _getRecordCount
#
# Description: Return number of recorded events
#
# Arguments:
#  - Object reference
# Returns:
#  Number of records

sub _getRecordCount($) {
  my $self = shift;
  return scalar(@{$self->{times}});
} # Method _getRecordCount

#----------------------------------------------------------------------------
#
# Method:      _getSortedRefs
#
# Description: Return references to events for the regexp
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  date, time, event type, string  Arguments are joined by comma ','
#    ... Expression to match, Only return matching events
# Returns:
#  A list with references to to events in the times array

sub _getSortedRefs($;@) {
  my $self = shift;

  return map(\$_, sort grep( defined($_) , @{$self->{times}}))
      unless(defined($_[0]));
  my $match = join(',', @_);
  return map(\$_, sort grep( $_ ? /^$match/ : 0 , @{$self->{times}}));
} # Method _getSortedRefs

#----------------------------------------------------------------------------
#
# Method:      getSortedRegistrationsForDate
#
# Description: Return references to events for the regexp
#
# Arguments:
#  - Object reference
#  - Date of events to return
# Returns:
#  Events data for the requested date
#    - Time
#    - Type
#    - Event text
#    - Reference to registration

sub getSortedRegistrationsForDate($;@) {
  my $self = shift;
  my ($date) = @_;

  my $refs = [];
  for my $ref ($self->_getSortedRefs($date)) {
    # TODO Is it more effective to use a regexp to split the event?
    my $eventType;
    my $eventText;

    if (substr($$ref, 17, 5) eq $BEGINEVENT) {
      $eventType = $BEGINEVENT;
      $eventText = substr($$ref, 23);
    } else {
      $eventType = substr($$ref, 17, -1);
      $eventText = '';
    } # if #

    push @$refs,
      {
        time => substr($$ref, 11,  5),
        type => $eventType,
        text => $eventText,
        ref  => $ref,
      };
  } # for #

  return $refs;
} # Method getSortedRegistrationsForDate

#----------------------------------------------------------------------------
#
# Method:      move
#
# Description: Move times data from this to another Times object
#              If last date is specified move all events before the date
#              If first date is specified move all events after the date
#              Undo is cleared
#
# Arguments:
#  - Object reference
#  - Reference to times object move to
# Optional Arguments:
#  - Last date of to move
#  - First date of to move
# Returns:
#  -

sub move($$;$$) {
  # parameters
  my $self = shift;
  my ($target, $last_date, $first_date) = @_;


  for my $ref ($self->_getSortedRefs()) {
    my $d = substr($$ref, 0, 10);
    last
        if (defined($last_date) and
            ($last_date lt $d));
    next
        if (defined($first_date) and
            ($first_date gt $d));
    $target->add($$ref, 1);
    $$ref = undef;

  } # for #

  $self   -> undoClear();
  $self   -> dirty();
  $target -> undoClear();
  $target -> dirty();

  return 0;
} # Method move

#----------------------------------------------------------------------------
#
# Method:      _mergeData
#
# Description: Add times data from source times, skip duplicates
#              and times not between start and end date
#              Undo is cleared
#
# Arguments:
#  - Object reference
#  - Source object to merge from
#  - Start Date
#  - End Date
# Optional Arguments:
#  - Reference to progress handling hash
# Returns:
#  -

sub _mergeData($$$$;$) {
  # parameters
  my $self = shift;
  my ($source, $startDate, $endDate, $progress_ref) = @_;


  my @trefs = $self->_getSortedRefs();
  my $ti = 0;
  my $tend = $#trefs;

  my $sNum = $source->_getRecordCount();
  my $si = 0;

  # Progress bar handling
  my $sProgressSteps;
  my $sProgressCnt;
  my $tProgressSteps;
  my $tProgressCnt;
  if ($progress_ref) {
    $sProgressSteps = ( $sNum / $progress_ref->{-percent_part} ) || 1;
    $sProgressCnt = 0;
    $tProgressSteps = ( $tend / $progress_ref->{-percent_part} ) || 1;
    $tProgressCnt = 0;
  } # if #


  for my $sref ($source->_getSortedRefs()) {

    $si++;

    if ($progress_ref) {
      if ($sProgressSteps > $tProgressSteps) {
        if ($si > $sProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $sProgressCnt += $sProgressSteps;
        } # if #
      } else {
        if ($ti > $tProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $tProgressCnt += $tProgressSteps;
        } # if #
      } # if #
    } # if #

    # Skip undefined items in source
    next
        unless (defined(${$sref}));

    my $date = substr(${$sref},0,10);
    next
        if ($date lt $startDate);
    last
        if ($date gt $endDate);

    if ($ti > $tend) {
      # End of target, add remaining from source
      $self->add(${$sref}, 1);
      ${$sref} = undef;
      next;
    } # if #

    while ($ti <= $tend) {
      my $tref = $trefs[$ti];

      # Skip undefined items in target
      unless (defined(${$tref})) {
        $ti++;
        next;
      } # unless #

      if (${$tref} eq ${$sref}) {
        $ti++;
        ${$sref} = undef;
        last;
      } elsif (${$tref} lt ${$sref}) {
        $ti++;
        if ($ti > $tend) {
          # End of target, add source
          $self->add(${$sref}, 1);
          ${$sref} = undef;
          last;
        } # if #
        next;
      } elsif (${$tref} gt ${$sref}) {
        $self->add(${$sref}, 1);
        ${$sref} = undef;
        last;
      } # if #
    } # while #

  } # for #

  $self   -> undoClear();

  return 0;
} # Method _mergeData

#----------------------------------------------------------------------------
#
# Method:      setUndo
#
# Description: Set display undone number
#
# Arguments:
#  0 - Object reference
#  1 - Name of the display
#  2 - Callback to display
#      undef disables the named display

# Returns:
#  -

sub setUndo($$$) {
  # parameters
  my $self = shift;
  my ($name, $disp) = @_;

  $self->{-undo}{$name} = $disp;
  return 0;
} # Method setUndo

#----------------------------------------------------------------------------
#
# Method:      _getUndoDates
#
# Description: Get the dates from the top of the undo stack
#
# Arguments:
#  0 - Object reference
# Returns:
#  '-', d1, d2  The range impacted
#  d1, .. , dn  All dates impacted
#  undef if undo is empty
#

sub _getUndoDates($) {
  # parameters
  my $self = shift;


  return undef
      unless (@{$self->{undo}});

  my $l = $self->{undo}[$#{$self->{undo}}];

  if (ref($l)) {
    # Latest entry is change or delete

    # Latest entry is change
    return (substr(${$l->[0]}, 0, 10), substr($l->[1], 0, 10))
        if (defined(${$l->[0]}));

    # Latest entry is delete
    return (substr($l->[1], 0, 10));

  } # if #

  # Latest undo entry is lock
  return ('-', sort(substr($l,1,10), substr($l,11,10)))
      if (substr($l, 0, 1) eq 'L');

  # Latest undo entry is the end of an undo set
  if (substr($l, 0, 1) eq 'S') {
    my $pos = index($l, ' - ');
    #   2019-05-13 - 2019-05-19
    # It is an adjust undo set, get start and end dates
    return ('-',
            substr($l, $pos - 10, 10),
            substr($l, $pos + 3, 10),
           )
        if ($pos >= 0);

    $pos = index($l, ' till ');
    #   2019-05-13 till 2019-05-19
    # It is an copy/paste undo set, get to date
    return (substr($l, $pos + 6, 10))
        if ($pos >= 0);
  } # if #

  # Latest undo entry is a new registration
  return (substr($self->{times}[$l],0,10));


} # Method _getUndoDates

#----------------------------------------------------------------------------
#
# Method:      _doDisplay
#
# Description: Display event changes
#              Calls the registered handler with
#              '-', date 1, date 2 : Dates in range impacted
#              date 1, .. date n : Every listed date impacted
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 .. n - Dates array fetched earlier from by
# Returns:
#  -

sub _doDisplay($;@) {
  # parameters
  my $self = shift;
  my (@dates) = @_;


  return 0 if (defined($self->{set}));

  # Find out dates from top of undo stack unless specified
  @dates = $self->_getUndoDates()
      unless @dates;

  $self->SUPER::_doDisplay(@dates);
  return 0;
} # Method _doDisplay

#----------------------------------------------------------------------------
#
# Method:      _addUndo
#
# Description: Add an undo event
#
# Arguments:
#  0 - Object reference
#  1 - Undo event to add
# Returns:
#  Index of undo stack top

sub _addUndo($$) {
  # parameters
  my $self = shift;
  my ($event) = @_;


  push @{$self->{undo}}, $event;

  unless (defined($self->{set})) {
    for my $ref (values(%{$self->{-undo}})) {
      $self->callback($ref, -1, scalar(@{$self->{undo}}));
    } # for #
  } # unless #

  return ($#{$self->{undo}});
} # Method _addUndo

#----------------------------------------------------------------------------
#
# Method:      add
#
# Description: Add new event and add as an undo event
#
# Arguments:
#  0 - Object reference
#  1 - Data to add
# Optional Arguments:
#  2 - No undo, when used by archive
# Returns:
#  -
#

sub add($$;$) {
  # parameters
  my $self = shift;
  my ($event, $no_undo) = @_;


  push @{$self->{times}}, $event;

  return 0
      if $no_undo;

  $self->_addUndo($#{$self->{times}});

  $self->_doDisplay();

  $self->append($event);

  return 0;
} # Method add

#----------------------------------------------------------------------------
#
# Method:      joinAdd
#
# Description: Join event data and add new event and add as an undo event
#
# Arguments:
#  - Object reference
#  ... Data to add
# Returns:
#  -
#

sub joinAdd($@) {
  # parameters
  my $self = shift;

  return $self->add(join(',', @_));
} # Method joinAdd

#----------------------------------------------------------------------------
#
# Method:      change
#
# Description: Change times data for an entry and add an undo event
#              If no new value supplied a remove happens
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event to change
# Optional Arguments:
#  2 - Event after change
# Returns:
#  -

sub change($$;$) {
  # parameters
  my $self = shift;
  my ($ref, $event) = @_;


  $self->_addUndo([$ref, $$ref]);

  $$ref = $event;

  $self->_doDisplay();

  $self->dirty();

  return 0;
} # Method change

#----------------------------------------------------------------------------
#
# Method:      undoAddLock
#
# Description: Add an undo lock event
#
# Arguments:
#  0 - Object reference
#  1 - Old lock date
#  2 - New lock date
# Returns:
#  Index of undo stack top

sub undoAddLock($$$) {
  # parameters
  my $self = shift;
  my ($oldDate, $newDate) = @_;

  my $r = $self->_addUndo('L' . $oldDate . $newDate);
  $self->_doDisplay();
  return $r;
} # Method undoAddLock

#----------------------------------------------------------------------------
#
# Method:      undoSetEnd
#
# Description: End an undo set
#              Do not create an empty set
#
# Arguments:
#  0 - Object reference
#  1 - Set information
# Returns:
#  Index of undo stack top

sub undoSetEnd($$) {
  # parameters
  my $self = shift;
  my ($info) = @_;


  return 0 unless(defined($self->{set}));

  my $set = $self->{set};
  $self->{set} = undef;

  if ($set != $#{$self->{undo}}) {
    $self->_addUndo('S' . $set . ':' . $info);
    $self->_doDisplay();
  } # if #

  return 0;
} # Method undoSetEnd

#----------------------------------------------------------------------------
#
# Method:      undoSetBegin
#
# Description: Start an undo set with several events
#
# Arguments:
#  0 - Object reference
# Returns:
#  Index of undo event before undo set

sub undoSetBegin($) {
  # parameters
  my $self = shift;


  $self->undoSetEnd()
      if (defined($self->{set}));

  $self->{set} = $#{$self->{undo}};

  return $self->{set};
} # Method undoSetBegin

#----------------------------------------------------------------------------
#
# Method:      undoGetLength
#
# Description: Return lenght of the undo list
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub undoGetLength($) {
  # parameters
  my $self = shift;

  return scalar(@{$self->{undo}});
} # Method undoGetLength

#----------------------------------------------------------------------------
#
# Method:      _undoOne
#
# Description: Undo event on top of undo stack
#
# Arguments:
#  0 - Object reference
# Returns:
#  Index of top of undo stack after event is popped

sub _undoOne($) {
  # parameters
  my $self = shift;

  if (@{$self->{undo}}) {
    my $l = pop @{$self->{undo}};
    if (ref($l)) {
      ${$l->[0]} = $l->[1];

    } elsif (substr($l, 0, 1) eq 'L') {
      $self->{erefs}{-cfg}->set(lock_date => substr($l,1,10));

    } else {
      $self->{times}[$l] = undef;

    } # if #

  } # if #
  return $#{$self->{undo}};
} # Method _undoOne

#----------------------------------------------------------------------------
#
# Method:      _undoAction
#
# Description: Perform one undo action
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _undoAction($) {
  # parameters
  my $self = shift;


  return 0 unless (@{$self->{undo}});

  my @dates = $self->_getUndoDates();

  $self->_undoOne();

  $self->dirty();

  $self->_doDisplay(@dates);

  for my $ref (values(%{$self->{-undo}})) {
    $self->callback($ref, 1, scalar(@{$self->{undo}}));
  } # for #

  return 0;
} # Method _undoAction

#----------------------------------------------------------------------------
#
# Method:      _undoSet
#
# Description: Undo a set of undo actions
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _undoSet($) {
  # parameters
  my $self = shift;


  return 0 unless (@{$self->{undo}});

  my @dates = $self->_getUndoDates();

  my $l = pop @{$self->{undo}};
  my $start = substr($l, 1, index($l, ':')-1);
  my $cnt=1;
  while ($start < $self->_undoOne()) {
    $cnt++;
  } # while #

  $self->dirty();

  $self->_doDisplay(@dates);

  for my $ref (values(%{$self->{-undo}})) {
    $self->callback($ref, $cnt, scalar(@{$self->{undo}}));
  } # for #

  return 0;
} # Method _undoSet

#----------------------------------------------------------------------------
#
# Method:      undo
#
# Description: Display undo confirmation
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub undo($@) {
  # parameters
  my $self = shift;
  my ($ref, $popup) = @_;


  return 0 unless (@{$self->{undo}});

  my $l = $self->{undo}[$#{$self->{undo}}];

  if (ref($l)) {
    # Latest entry is change or delete
    if (defined(${$l->[0]})) {
      # Latest entry is change
      $self->callback([$ref->{win}{confirm}, $popup],
                 -title  => 'bekräfta',
                 -text   => ['Vill du ångra:',
                             'och återställa till:'],
                 -data   => [$self->{erefs}{-calculate}->format(${$l->[0]}),
                             $self->{erefs}{-calculate}->format($l->[1])],
                 -action => [$self, '_undoAction'],
                );

    } else {
      # Latest entry is delete
      $self->callback([$ref->{win}{confirm}, $popup],
                 -title  => 'bekräfta',
                 -text   => ['Vill du ångra borttagning av:'],
                 -data   => [$self->{erefs}{-calculate}->format($l->[1])],
                 -action => [$self, '_undoAction'],
                );

    } # if #
  } elsif (substr($l, 0, 1) eq 'L') {
    # Latest undo entry is lock
    my $o_date = substr($l,1,10);
    my $l_date = substr($l,11,10);
    my ($s, $w);
    if ($o_date lt $l_date) {
      $s = 'Vill du ångra lås av vecka:';
      $w = join(' Vecka: ', $self->{erefs}{-calculate}->weekNumber($l_date));
    } else {
      $s = 'Vill du ångra upplåsning av vecka:';
      $w = join(' Vecka: ', $self->{erefs}{-calculate}->weekNumber($o_date));
    } # if #
      $self->callback([$ref->{win}{confirm}, $popup],
                 -title  => 'bekräfta',
                 -text   => [$s],
                 -data   => [$w],
                 -action => [$self, '_undoAction'],
                );

  } elsif (substr($l, 0, 1) eq 'S') {
    # Latest undo entry is the end of an undo set
    my $i = index($l, ':', 2);
    my ($s, $w) = split(',', substr($l, $i + 1));

      $self->callback([$ref->{win}{confirm}, $popup],
                 -title  => 'bekräfta',
                 -text   => ['Vill du ångra ' . $s],
                 -data   => [$w],
                 -action => [$self, '_undoSet'],
                );

  } else {
    # Latest undo entry is a new registration
      $self->callback([$ref->{win}{confirm}, $popup],
                 -title  => 'bekräfta',
                 -text   => ['Vill du ångra registrering:'],
                 -data   =>
                     [$self->{erefs}{-calculate}->format($self->{times}[$l])],
                 -action => [$self, '_undoAction'],
                );

  } # if #

  return 0;
} # Method undo

#----------------------------------------------------------------------------
#
# Method:      copyPaste
#
# Description: Copy all events from date to date
#              The complete copy is registered as an undo set
#
# Arguments:
#  - Object reference
#  - From date
#  - To date
# Returns:
#  -

sub copyPaste($$$) {
  # parameters
  my $self = shift;
  my ($fromDate, $toDate) = @_;


  return undef
      unless ($fromDate and $toDate);

  # TODO Do not append to file as more than one append will be done in a very
  #      short time. Preferred way would be to have append wait short time,
  #      lets say about 30 seconds. Every append resets the timer.
  # Set dirty to avoid append to file for every single copied event
  $self->dirty();

  $self->undoSetBegin();

  my $cnt = 0;
  for my $ref ($self->_getSortedRefs($fromDate)) {
    $self->joinAdd($toDate, substr($$ref, 11));
    $cnt++;
  } # for #

  my $str = 'Kopierade från ' . $fromDate . ' till ' . $toDate;
  $str   .= "\nKlistrade in " . $cnt . ' händelser'
      if $cnt;

  $self->undoSetEnd('klistra in:,' . $str);

  return $cnt
      unless ($cnt);

  return 'Klistrade in ' . $cnt . ' händelser från ' . $fromDate;
} # Method copyPaste

#----------------------------------------------------------------------------
#
# Method:      findLastEvent
#
# Description: Find event on specifed date and on from time or earlier
#              Also find event text before last event
#              TODO Should it say event or action???
#
# Arguments:
#  - Object reference
#  - Date
#  - Time
# Returns:
#  Text of event
#  Presentation text of event
#  State of workday or not work
#  $last_event, $prev_event,
#  $last_time

sub findLastEvent($$$) {
  # parameters
  my $self = shift;
  my ($date, $from_time) = @_;

  my $show_data_text = '';
  my $last_state = '';
  my $last_event;
  my $last_time = '';
  my $prev_event;

  for my $ref (reverse($self->_getSortedRefs($date))) {

    next unless (substr($$ref, 17) =~ /^($TYPE),(.*)$/);
    my ($state, $text) = ($1, $2);
    my $time = substr($$ref, 11, 5);

    next
        if ($from_time lt $time);

    if (not defined($last_event)) {
      if ($self->{erefs}{-cfg}->get('show_reg_date')) {
        $show_data_text = $self->{erefs}{-calculate}
               -> format($date, $time, $state, $text);
      } else {
        $show_data_text = $self->{erefs}{-calculate}
                -> format(undef, $time, $state, $text);
      } # if #

      if ($state eq $BEGINEVENT or
          $state eq $ENDEVENT or
          $state eq $BEGINWORKDAY or
          $state eq $ENDPAUS)
      {
        $last_state = $WORKDAY;
      } else {
        $last_state = $state;
      } # if #
      $last_time = $time;
      $last_event = $text;

    } elsif ($state eq $BEGINEVENT and $last_event ne $text) {
      $prev_event = $text;
      last;
    } # if #

  } # for #
  return ($show_data_text, $last_state, $last_event, $prev_event, $last_time);
} # Method findLastEvent

#----------------------------------------------------------------------------
#
# Method:      searchEvent
#
# Description: Search for an event
#
# Arguments:
#  - Object reference
#  - Backward, search backwards if true
#  - Start date
#  - Start time
#  - Search expression
# Returns:
#  - Date
#  - Time
#  - Event
#  - Reference to found event

sub searchEvent($$$$$) {
  # parameters
  my $self = shift;
  my ($back, $start_date, $start_time, $expr) = @_;

  my $start_date_time = $start_date . ',' . $start_time;
  my $fnd;
  if ($back) {
    for my $ref (reverse($self->_getSortedRefs($DATE, $TIME, $BEGINEVENT, $expr)
                ))
    {
      next
          if ($start_date_time le substr($$ref, 0, 16));
      $fnd = $ref;
      last;
    } # for #

  } else {
    for my $ref ($self->_getSortedRefs($DATE, $TIME, $BEGINEVENT, $expr)
                )
    {
      next
          if ($start_date_time ge substr($$ref, 0, 16));
      $fnd = $ref;
      last;
    } # for #

  } # if #

  return (undef, undef, undef)
      unless ($fnd);

  my $found_date  = substr($$fnd,  0, 10);
  my $found_time  = substr($$fnd, 11,  5);
  my $found_event = substr($$fnd, 23);
  return ($found_date, $found_time, $found_event, $fnd);
} # Method searchEvent

#----------------------------------------------------------------------------
#
# Method:      getEventDates
#
# Description: Find dates were event is registered
#
# Arguments:
#  - Object reference
#  - Event to find
#  - Start date to search from
# Returns:
#  - Reference to sorted array with dates

sub getEventDates($$$) {
  # parameters
  my $self = shift;
  my ($event, $start) = @_;

  # Work from yesterday back until start date
  my $today   = $self->{erefs}{-clock}->getDate();
  my $checked = 0;
  my $dates   = [];

  for my $ref (reverse(
       $self->_getSortedRefs($DATE, $TIME, $BEGINEVENT, $event)
    ))
  {
    my $date = substr($$ref, 0, 10);

    next if $date eq $checked;
    next if $date ge $today;
    last if $date lt $start;

    $checked = $date;

    unshift @$dates, $date;

  } # for #
  return $dates;
} # Method getEventDates

#----------------------------------------------------------------------------
#
# Method:      getPreviousEvents
#
# Description: Get last events texts. Number of events specified at call
#
# Arguments:
#  - Object reference
#  - Number of events
# Returns:
#  Reference to hash with:
#    Key   = Event Text
#    Value = Number increasing for older event

sub getPreviousEvents($$) {
  # parameters
  my $self = shift;
  my ($number) = @_;

  my $previous_cnt = 0;
  my $previous = {};
  for my $ref (reverse(
               $self->_getSortedRefs($DATE, $TIME, $BEGINEVENT)
              )) {
    if ($$ref =~ /^$DATE,$TIME,$BEGINEVENT,(.+)$/o) {
      next
          if exists($previous->{$1});
      $previous->{$1} = $previous_cnt;
      $previous_cnt++;
      last
          if ($previous_cnt >= $number);
    } # if #
  } # for #
  return $previous;
} # Method getPreviousEvents

#----------------------------------------------------------------------------
#
# Method:      yearsWeeks
#
# Description: Update all years and all weeks
#              Search through dates to find all years and all weeks
#              Year and week number
#              First date and last date with registrations in each week is
#              recorded. Date of Sunday in the week is registered and wether
#              the week is locked.
#
# Arguments:
#  - Object reference
#  - Reference to year and weeks hash
#  - Reference to hash with constants for UNLOCKED, LOCKED and ARCHIVED
# Returns:
#  True if there are changes

sub yearsWeeks($$) {
  # parameters
  my $self = shift;
  my ($wref, $CONST) = @_;


  # Get constants
  my $UNLOCKED = $CONST->{UNLOCKED};
  my $LOCKED   = $CONST->{LOCKED}  ;
  my $ARCHIVED = $CONST->{ARCHIVED};

  my $calc = $self->{erefs}{-calculate};
  my $c = 0;

  my ($date, $t_y, $t_w, $t_yw, $t_d, $wr);
  my ($p_date, $p_yw)= ('', '');

  my $arch = $self->{erefs}{-cfg}->get('archive_date');
  my $lock = $self->{erefs}{-cfg}->get('lock_date');

  for my $ref ($self->_getSortedRefs()) {

    $date = substr($$ref, 0, 10);

    next
        if ($p_date eq $date);

    $p_date = $date;

    $t_d = substr($date, 5, 5);

    ($t_y, $t_w) = $calc->weekNumber($date);
    $t_yw = $t_y . 'v' . $t_w;

    if ($p_yw eq $t_yw) {

      if ($wr->{last} lt $t_d) {
        $wr->{last} = $t_d;
        $c = 1;
      } # if #

    } else {

      unless (exists($wref->{$t_y}{$t_w})) {
        $wref->{$t_y}{$t_w} =
              {
               first  => $t_d,
               last   => $t_d,
               sunday => $calc->dayInWeek($t_y, $t_w, 7),
               lock   => 0,
              };
        my $yr = $wref->{$t_y};
        $wr = $yr->{$t_w};

        unless (exists($yr->{last})) {
          $yr->{first} = $calc->dayInWeek($t_y, 1, 1);
          $yr->{last}  = $calc->stepDate(
                                         $calc->dayInWeek($t_y + 1, 1, 7),
                                         -7
                                        );
        } # unless #

        $c = 1;

      } else {

        $wr = $wref->{$t_y}{$t_w};

        if ($wr->{first} gt $t_d) {
          $wr->{first} = $t_d;
          $c = 1;
        } # if #

        if ($wr->{last} lt $t_d) {
          $wr->{last} = $t_d;
          $c = 1;
        } # if #

      } # unless #

      $p_yw = $t_yw;

    } # if #

    $self->{dirty}{$t_y} = 1
        if ($c);
  } # for #

  for $t_y (keys(%{$wref})) {
    next
        unless(ref($wref->{$t_y}));
    for $t_w (keys(%{$wref->{$t_y}})) {
      $wr = $wref->{$t_y}{$t_w};
      next
          unless(ref($wr));
      my $status;
      if ($wr->{sunday} le $arch) {
        $status = $ARCHIVED;

      } elsif ($wr->{sunday} le $lock) {
        $status = $LOCKED;

      } else {
        $status = $UNLOCKED;

      } # if #

      if ($status != $wr->{lock}) {
        $wr->{lock} = $status;
        $self->{dirty}{$t_y} = 1;
        $c = 1;
      } # if #
    } # for #
    $self->{dirty}{$t_y} = 1
        if ($c);
  } # for #

  return $c;
} # Method yearsWeeks

#----------------------------------------------------------------------------
#
# Method:      _addFixedStartResume
#
# Description: Register start of session
#  start_operation    How to register start of tidbox
#                       0:  No action
#                       1:  Register Start workday, if it is the first today
#                       2:  Register Start Event
#                       3:  Register End Pause
#
# Arguments:
#  - Object reference
#  - Date
#  - Time
#  - Operation
# Returns:
#  -

sub _addFixedStartResume($$$$) {
  # parameters
  my $self = shift;
  my ($date, $time, $op) = @_;


  if ($op == 1) {
    my $notfound = 1;

    for my $ref (reverse($self->_getSortedRefs($date))) {
      next
          unless (substr($$ref, 11, 5) le $time);
      $notfound = 0;
      last;
    } # for #
    $self->joinAdd($date, $time, $BEGINWORKDAY, '')
      if ($notfound);

  } elsif ($op == 3) {
    $self->joinAdd($date, $time, $ENDPAUS, '');

  } # if #

  return 0;
} # Method _addFixedStartResume

#----------------------------------------------------------------------------
#
# Method:      checkResume
#
# Description: Check if session was resumed and if so register resume
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub checkResume($) {
  # parameters
  my $self = shift;


  return 0
      if ($self->{erefs}{-clock}->getSleep() <
          $self->{erefs}{-cfg}->get('resume_operation_time') * 60);

  my $time = $self->{erefs}{-clock}->getTime();
  my $date = $self->{erefs}{-clock}->getDate();

  return 0
      if ($self->{erefs}{-cfg}->isLocked($date));

  my $op = $self->{erefs}{-cfg}->get('resume_operation');

  if ($op == 1 or $op == 3) {
    $self->_addFixedStartResume($date, $time, $op);

  } elsif ($op == 2 or $op == 4) {
    my $sh = $self->{erefs}{-calculate}->
        hours($self->{erefs}{-clock}->getSleep() / 60);
    my $ev;
    $ev = $self->{erefs}{-cfg}->get('resume_operation_event')
        if ($op == 4);
    $ev = $self->{erefs}{-event_cfg}->
            getEmpty('Återupptog tidbox efter')
        unless ($ev);
    $self->joinAdd($date, $time, $BEGINEVENT, $ev . ' ' . $sh . ' timmar');

  } # if #

  return 0;
} # Method checkResume

#----------------------------------------------------------------------------
#
# Method:      midnight
#
# Description: If worktime is ongoing at midnight end workday at 23:59
#              yesterday and continue ongoing activity at 00:00
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub midnight($) {
  # parameters
  my $self = shift;


  my $today = $self->{erefs}{-clock}->getDate();

  # Skip if today is locked
  return 0
      if ($self->{erefs}{-cfg}->isLocked($today));

  my $yesterday = $self->{erefs}{-calculate}->stepDate($today, -1);

  # Search yesterday backward to find ongoing activity
  for my $ref (reverse($self->_getSortedRefs($yesterday))) {

    next unless (substr($$ref, 17) =~ /^($TYPE),(.*)$/);
    my ($state, $text) = ($1, $2);

    # Do not add anything when no work or paus is ongoing
    last
        if ($state eq $ENDWORKDAY or
            $state eq $BEGINPAUS);

    # Register end workday yesterday 23:59 unless yesterday is locked
    $self->joinAdd($yesterday, '23:59', $ENDWORKDAY, '')
        unless ($self->{erefs}{-cfg}->isLocked($yesterday));

    if ($state eq $BEGINEVENT) {
      # Register event start at 00:00 with event that ended yesterday
      $self->joinAdd($today, '00:00', $state, $text);

    } else {
      # Register begin workday at 00:00 if state was work yesterday
      $self->joinAdd($today, '00:00', $BEGINWORKDAY, '');

    } # if #
    last;

  } # for #

  return 0;
} # Method midnight

#----------------------------------------------------------------------------
#
# Method:      startSession
#
# Description: Register start of session
#              Defined by configuration 'start_operation'
#              Add resume and midnight timer
#
# Arguments:
#  0 - Object reference
#  1 - Date
#  2 - Time
# Returns:
#  -

sub startSession($$$) {
  # parameters
  my $self = shift;
  my ($date, $time) = @_;


  $self->{erefs}{-clock}->repeat(-sleep => [$self => 'checkResume']);
  $self->{erefs}{-clock}->repeat(-date => [$self, 'midnight']);

  return 0
      if ($self->{erefs}{-cfg}->isLocked($date));


  my $op = $self->{erefs}{-cfg}->get('start_operation');

  if ($op == 1 or $op == 3) {
    $self->_addFixedStartResume($date, $time, $op);

  } elsif ($op == 2 or $op == 4) {
    my $ev;
    $ev = $self->{erefs}{-cfg}->get('start_operation_event')
        if ($op == 4);
    $ev = $self->{erefs}{-event_cfg}->getEmpty('Startade tidbox')
        unless ($ev);
    $self->joinAdd($date, $time, $BEGINEVENT, $ev);
  } # if #

  return 0;
} # Method startSession

1;
__END__
