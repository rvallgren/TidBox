#
package TbFile::Times;
#
#   Document: Times data
#   Version:  1.11   Created: 2018-12-07 17:46
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Times.pmx
#

my $VERSION = '1.11';
my $DATEVER = '2018-12-07';

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


  for my $ref ($self->getSortedRefs()) {
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

  $self->{erefs}{-log}->trace('Start date and end date:',
                              $startDate, $endDate)
      if ($self->{erefs}{-log});

  my @trefs = $self->getSortedRefs();
  my $ti = 0;
  my $tend = $#trefs;

  my $sNum = $source->getRecordNumber();
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
    $self->{erefs}{-log}->trace('Progress S Stp:', $sProgressSteps,
                                'Num:', $sNum)
        if ($self->{erefs}{-log});
    $self->{erefs}{-log}->trace('Progress T Stp:', $tProgressSteps,
                                'Num:', $tend)
        if ($self->{erefs}{-log});
  } # if #


  for my $sref ($source->getSortedRefs()) {

    $si++;

    if ($progress_ref) {
      $self->{erefs}{-log}->trace('Progress Times S:', $si, 'T:', $ti)
          if ($self->{erefs}{-log});
      if ($sProgressSteps > $tProgressSteps) {
        if ($si > $sProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $sProgressCnt += $sProgressSteps;
          $self->{erefs}{-log}->trace('Progress Step source:', $sProgressCnt)
              if ($self->{erefs}{-log});
        } # if #
      } else {
        if ($ti > $tProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $tProgressCnt += $tProgressSteps;
          $self->{erefs}{-log}->trace('Progress Step target:', $tProgressCnt)
              if ($self->{erefs}{-log});
        } # if #
      } # if #
    } # if #

    # Skip undefined items in source
    next
        unless (defined(${$sref}));

    $self->{erefs}{-log}->trace('Source to check', ${$sref});
    my $date = substr(${$sref},0,10);
    $self->{erefs}{-log}->trace('Source date', $date);
    next
        if ($date lt $startDate);
    last
        if ($date gt $endDate);

    if ($ti > $tend) {
      # End of target, add remaining from source
      $self->{erefs}{-log}->trace('End of target, add remaining from source');
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

      $self->{erefs}{-log}->trace('Target to check', ${$tref});
      if (${$tref} eq ${$sref}) {
        $self->{erefs}{-log}->trace('Equal, skip source');
        $ti++;
        ${$sref} = undef;
        last;
      } elsif (${$tref} lt ${$sref}) {
        $self->{erefs}{-log}->
            trace('Target less than source, check next');
        $ti++;
        if ($ti > $tend) {
          # End of target, add source
          $self->{erefs}{-log}->trace('End of target, add source');
          $self->add(${$sref}, 1);
          ${$sref} = undef;
          last;
        } # if #
        next;
      } elsif (${$tref} gt ${$sref}) {
        $self->{erefs}{-log}->
            trace('Target greater than source, add source');
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
  return ('-',
          substr($l, index($l, ' - ') - 10, 10),
          substr($l, index($l, ' - ') +3, 10),
         )
      if (substr($l, 0, 1) eq 'S');

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
# Method:      getSortedRefs
#
# Description: Return references to events for the regexp
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  ... Expression to match, Only return matching events
# Returns:
#  A reference to the times array

sub getSortedRefs($;@) {
  my $self = shift;
  return map(\$_, sort grep( defined($_) , @{$self->{times}}))
      unless(defined($_[0]));
  my $match = join(',', @_);
  return map(\$_, sort grep( $_ ? /^$match/ : 0 , @{$self->{times}}));
} # Method getSortedRefs

#----------------------------------------------------------------------------
#
# Method:      getRecordNumber
#
# Description: Return number of recorded events
#
# Arguments:
#  - Object reference
# Returns:
#  Number of records

sub getRecordNumber($) {
  my $self = shift;
  return scalar(@{$self->{times}});
} # Method getRecordNumber

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
  my $cnt=0;
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

    for my $ref (reverse($self->getSortedRefs($date))) {
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
  for my $ref (reverse($self->getSortedRefs($yesterday))) {

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
#              Add resume timer
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
