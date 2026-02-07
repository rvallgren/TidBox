#
package TbFile::Archive;
#
#   Document: Archive data
#   Version:  1.6   Created: 2026-01-06 17:23
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Archive.pmx
#

my $VERSION = '1.6';
my $DATEVER = '2026-01-06';

# History information:
#
# 1.0  2008-03-12  Roland Vallgren
#      First issue.
# 1.1  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.2  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
# 1.3  2017-09-11  Roland Vallgren
#      Remove not used constants
#      Removed support for import of earlier Tidbox data
# 1.4  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      References to other objects in own hash
#      Added _mergeData to merge data from another archive
# 1.5  2019-01-25  Roland Vallgren
#      Code improvement
#      Removed log->trace
#      Corrected: -error_popup is an eref
# 1.6  2025-02-16  Roland Vallgren
#      Added schedule
#

# TODO What do we do with duplicated archive sets in archive file
# TODO What do we do with overlapping archive sets
# TODO What do we do with inconsistent archive sets
#      (dates before set start date or after set end date)
# TODO So far none of the mentioned problems above are handled
#      Archive sets are expected to be correct when created.
#      A solution could be to merge all sets
#      - When a set is added to the archive
#        = Merge times and eventcfg with all existing sets
#        = Correct start date and end date of added set
#        = Do not add set that is completely in other sets

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

use TbFile::EventCfg;
use TbFile::Schedule;
use TbFile::Times;

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

use constant NO_DATE => '0000-00-00';

use constant FILENAME  => 'archive.dat';
use constant FILEKEY   => 'ARCHIVED TIME EVENTS';

use constant ARCHIVE_INFO      => 'ARCHIVE INFORMATION';

# If loaded the archive sets is a data structure
# $self->{sets} refer to a hash:
#    Key   : End date for the set
#    Value : Reference to the set hash:
#       date_time     : When the archive set was created
#       start_date    : Date of first registration in the archive set
#       end_date      : Date of the last registration in the archive set
#       event_cfg     : Reference to set EventCfg
#       schedule      : Reference to set Schedule
#       times         : Reference to set Times

use constant
{
  ARCHIVE_EVENT_CFG => 'EVENT CONFIGURATION',
  ARCHIVE_SCHEDULE  => 'SCHEDULE CONFIGURATION',
  ARCHIVE_TIMES     => 'REGISTERED TIME EVENTS',
};

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create archive object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = {
              sets    => {},
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all archive data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  %{$self->{sets}} = ();

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Read archive data from file
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

  my $a_r = $self->{sets};
  my $set;

  while (defined(my $line = $fh->getline())) {

    $line =~ s/\s+$//;

    if ($line =~ /^\[([-.\w\s]+)\]\s*$/) {
      if ($1 eq ARCHIVE_INFO) {

        # New archive set
        $set = {};

        while (defined($line = $fh->getline())) {
          # Load archive information
          if ($line =~ /^(\w+)=(.+?)\s*$/) {
            $set->{$1} = $2;
            if ($1 eq 'end_date') {
              unless (exists($self->{sets}{$2})) {
                $self->{sets}{$2} = $set;
              } else {
                # TODO merge sets?
                carp "Duplicated archive set for date: $2";
              } # unless #

            } # if #
          } else {
            last;
          } # if #
        } # while #


      } elsif ($1 eq ARCHIVE_EVENT_CFG) {
        # Load EventCfg data
        $set->{event_cfg} = $self->{erefs}{-event_cfg}->clone();
        $set->{event_cfg}->_load($fh);

      } elsif ($1 eq ARCHIVE_SCHEDULE) {
        # Load Schedule data
        $set->{schedule} = $self->{erefs}{-schedule}->clone();
        $set->{schedule}->_load($fh);

      } elsif ($1 eq ARCHIVE_TIMES) {
        # Load times data
        $set->{times} = $self->{erefs}{-times}->clone();
        $set->{times}->_load($fh);

      } else {
        carp "Unknown type in archive: $1";

      } # if #


    } # if #

  } # while #

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _append
#
# Description: Append archive set to file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
#  2 - Set to append
# Returns:
#  -

sub _append($$$) {
  # parameters
  my $self = shift;
  my ($fh, $set) = @_;


  # Add set information
  $fh->print("\n" .
             '['. ARCHIVE_INFO. ']' . "\n" .
             'date_time='  , $set->{date_time}  , "\n" .
             'start_date=' , $set->{start_date} , "\n" .
             'end_date='   , $set->{end_date}   , "\n");

  # Add event configuration data
  $fh->print("\n" .
             '['. ARCHIVE_EVENT_CFG. ']' . "\n");
  $set->{event_cfg}->_save($fh);

  # Add schedule data
  $fh->print("\n" .
             '['. ARCHIVE_SCHEDULE. ']' . "\n");
  $set->{schedule}->_save($fh);

  # Add times data
  $fh->print("\n" .
             '['. ARCHIVE_TIMES. ']' . "\n");
  $set->{times}->_save($fh);

  return 0;
} # Method _append

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save archive data to file
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


  for my $key (sort(keys(%{$self->{sets}}))) {
    $self->_append($fh, $self->{sets}{$key});
  } # for #

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      getSets
#
# Description: Get dates of the archive sets
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Set to get date for
#  - Item to get from set
# Returns:
#  No date: A sorted array of archive set dates
#  No Item: Start date for set referred to by date
#  Item:set: A reference to the set
#  Selected Item

sub getSets($;$$) {
  # parameters
  my $self = shift;
  my ($date, $tag) = @_;

  return NO_DATE
      unless (exists($self->{sets}));
  return sort(keys(%{$self->{sets}}))
      unless $date;
  return NO_DATE
      unless (exists($self->{sets}{$date}));
  if ($tag) {
    return $self->{sets}{$date}
        if ($tag eq 'set');
    return $self->{sets}{$date}{$tag}
        if (exists($self->{sets}{$date}{$tag}));
  } # if #
  return $self->{sets}{$date}{start_date};
} # Method getSets

#----------------------------------------------------------------------------
#
# Method:      joinSets
#
# Description: Join selected set with previous
#              No check for duplicates, previous is only prepended
#
# Arguments:
#  0 - Object reference
#  1 - Date for set to join
# Returns:
#  -

sub joinSets($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  # Find previous set that should be joined
  my $p;
  for my $k (sort(keys(%{$self->{sets}}))) {
    last
        if ($date eq $k);
    $p = $k;
  } # for #

  return 0
      unless $p;

  my $set  = $self->{sets}{$date};
  my $prev = $self->{sets}{$p};

  # Move data to the target set
  $prev->{event_cfg} -> move($set->{event_cfg});
  $prev->{schedule}  -> move($set->{schedule});
  $prev->{times}     -> move($set->{times});

  # Update information about the joined set
  $set->{date_time}  = $self->{erefs}{-clock}->getDate() . ' ' .
                       $self->{erefs}{-clock}->getTime();
  $set->{start_date} = $prev->{start_date};

  # And remove the moved set
  delete($self->{sets}{$p});

  $self->save(1);

  return 0;
} # Method joinSets

#----------------------------------------------------------------------------
#
# Method:      addSet
#
# Description: Add an archive set to this archive
#              If the archive not is loaded the set is added to file
#              Archive date is updated if this set is later
#
# Arguments:
#  - Object reference
#  - Reference to archive set to add
# Returns:
#  -

sub addSet($$) {
  # parameters
  my $self = shift;
  my ($set) = @_;


  my $end_date = $set->{end_date};
  if ($self->isLoaded()) {
    # TODO This only works if the set will be unique,
    #      not overlapping another set
    $self->{sets}{$end_date} = $set;
    $self-> dirty();

  } else {
    $self->append($set);
  } # if #

  my $archiveDate = $self->{erefs}{-cfg}->get('archive_date');
  $self->{erefs}{-cfg}->set('archive_date', $end_date)
      if ($end_date gt $archiveDate);

  return 0;
} # Method addSet

#----------------------------------------------------------------------------
#
# Method:      createSet
#
# Description: Create an archive set
#
# Arguments:
#  - Object reference
#  - Start date, end date of previous set, archive date before this set
#  - End date
#  - Event Cfg
#  - Schedule
#  - Times
# Optional Arguments:
#  - Set date time
# Returns:
#  - New archive set

sub createSet($$$$$$;$) {
  # parameters
  my $self = shift;
  my ($start_date, $end_date, $event_cfg, $schedule, $times, $date_time) = @_;


  # TODO This is strange, we need a better way to move a set between archives
  unless ($date_time) {
    $date_time = $self->{erefs}{-clock}->getDate() . ' ' .
                 $self->{erefs}{-clock}->getTime();

    # TODO This is not always right?
    $start_date = $self->{erefs}{-calculate}->stepDate($start_date, 1)
        if ($start_date gt NO_DATE);
  } # unless #

  # Create an archive set
  my $set = {
             date_time  => $date_time ,
             start_date => $start_date,
             end_date   => $end_date  ,
            };

  # Add event cfg data for archive set
  $set->{event_cfg} = $self->{erefs}{-event_cfg}->clone();
  $event_cfg->move($set->{event_cfg}, $end_date, $start_date);

  # Add schedule for archive set
  $set->{schedule} = $self->{erefs}{-schedule}->clone();
  $schedule->move($set->{schedule}, $end_date, $start_date);

  # Add times data for archive set
  $set->{times} = $self->{erefs}{-times}->clone();
  $times->move($set->{times}, $end_date, $start_date);


  return $set;
} # Method createSet

#----------------------------------------------------------------------------
#
# Method:      move
#
# Description: Move archive sets from this archive to another
#              archive object
#              No check is made for overlapping sets
#              If no date is specified, move all sets
#                Only use this when target archive is empty
#
# Arguments:
#  - Object reference
#  - Reference to archive object to move to
# Optional Arguments:
#  - Set date to move
# Returns:
#  -

sub move($$;$) {
  # parameters
  my $self = shift;
  my ($target, $end_date) = @_;


  my @set_dates;
  if ($end_date) {
    push @set_dates, $end_date;
  } else {
    @set_dates = $self->getSets();
  } # if #

  for $end_date (@set_dates) {
    $target->addSet($self->{sets}{$end_date});
    delete($self->{sets}{$end_date});
  } # for #

  $self -> dirty();

  return 0;
} # Method move

#----------------------------------------------------------------------------
#
# Method:      _mergeSets
#
# Description: Merge data from source set to target set
#              Only data within target set dates is merged
# TODO Improvement: Skip if source dates is outside of target
#      Unless merge to solve inconsistnecy
#
# Arguments:
#  - Object reference
#  - Source set
#  - Target set
# Returns:
#  -

sub _mergeSets($$$) {
  # parameters
  my $self = shift;
  my ($source, $target) = @_;


  my $trgStartDate = $target->{start_date};
  my $trgEndDate   = $target->{end_date};

  $target->{event_cfg}->merge(-fromInst  => $source->{event_cfg},
                              -startDate => $trgStartDate,
                              -endDate   => $trgEndDate,
                              -noLoad    => 1,
                              );
  $target->{schedule}->merge(-fromInst  => $source->{schedule},
                             -startDate => $trgStartDate,
                             -endDate   => $trgEndDate,
                             -noLoad    => 1,
                             );
  $target->{times}->merge(-fromInst   => $source->{times},
                          -startDate => $trgStartDate,
                          -endDate   => $trgEndDate,
                          -noLoad    => 1,
                         );
  return 0;
} # Method _mergeSets

#----------------------------------------------------------------------------
#
# Method:      _mergeFromMain
#
# Description: Merge data from main into archive
#     TODO We could use archive date to avoid empty merging
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _mergeFromMain($) {
  # parameters
  my $self = shift;


  for my $set (values(%{$self->{sets}})) {
    # Merge archive data from main into this archive
    my $setStart    = $set->{start_date};
    my $setEnd      = $set->{end_date};
    my $setTimes    = $set->{times};
    my $setEventCfg = $set->{event_cfg};
    my $setSchedule = $set->{schedule};

    # Merge data from main to the archive set
    $setEventCfg->merge(-fromInst  => $self->{erefs}{-event_cfg},
                        -startDate => $setStart,
                        -endDate   => $setEnd,
                        -noLoad    => 1,
                        );
    $setSchedule->merge(-fromInst  => $self->{erefs}{-schedule},
                        -startDate => $setStart,
                        -endDate   => $setEnd,
                        -noLoad    => 1,
                        );
    $setTimes->merge(-fromInst  => $self->{erefs}{-times},
                     -startDate => $setStart,
                     -endDate   => $setEnd,
                     -noLoad    => 1,
                    );


  } # for #

  return 0;
} # Method _mergeFromMain

#----------------------------------------------------------------------------
#
# Method:      _mergeData
#
# Description: Merge archive sets. For each set in target merge event cfg
#              and times between start date and end date of each set
#              Create new sets if there are holes
#              Archive date is set to the latest archive
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


  my @set_dates = $self->getSets();

  # Progress bar handling
  my $ProgressSourceSets;
  my $ProgressTargetSets;
  my $ProgressSteps;
  my $ProgressCnt;
  my $ProgressI = 0;

  # If archive is empty move whole source archive here
  unless (@set_dates) {

    if ($progress_ref) {
      if ($ProgressI > $ProgressCnt) {
        $self->callback(@{$progress_ref->{-callback}});
#          $ProgressCnt += $ProgressSteps;
      } # if #
    } # if #

    $source->move($self);

    # Merge from main
    $self->_mergeFromMain();

    $self->{erefs}{-times}     -> save();
    $self->{erefs}{-event_cfg} -> save();
    $self->{erefs}{-schedule}  -> save();
    $self -> save();
    return 0
  } # unless #


# date_time     : When the archive set was added
# start_date    : Date of first registration in the archive
# end_date      : Date of the last registration in the archive
# event_cfg     : Reference to EventCfg data
# schedule      : Reference to Schedule data
# times         : Reference to Times data

  my $archiveDate = $self->{erefs}{-cfg}->get('archive_date');
  my @source_dates = $source->getSets();
  my $sets = $self->{sets};
  my $firstSetStart = $self->getSets($set_dates[0], 'start_date');

  if ($progress_ref) {
    $ProgressSourceSets = scalar(@source_dates) || 1;
    $ProgressTargetSets = scalar(@set_dates) || 1;
    my $t = $ProgressSourceSets * $ProgressTargetSets;
    $ProgressSteps = ( $t / $progress_ref->{-percent_part} ) || 1;
    $ProgressCnt = 0;
  } # if #


  # All source sets
  for my $srcSetDate (@source_dates) {

    if ($progress_ref) {
      $ProgressI++;

      if ($ProgressI >= $ProgressCnt) {
        $self->callback(@{$progress_ref->{-callback}});
        $ProgressCnt += $ProgressSteps;
      } else {
      } # if #
    } # if #

    next
        if ($srcSetDate eq NO_DATE);

    my $srcSetStart = $source->getSets($srcSetDate, 'start_date');
    my $srcSetEnd   = $source->getSets($srcSetDate, 'end_date'  );
    my $srcTimes    = $source->getSets($srcSetDate, 'times'     );
    my $srcEventCfg = $source->getSets($srcSetDate, 'event_cfg' );
    my $srcSchedule = $source->getSets($srcSetDate, 'schedule'  );
    next
        if ($srcSetEnd lt $startDate);

    my $prevSetStart = NO_DATE;
    my $prevSetEnd   = NO_DATE;

    # Move complete source set before first target set
    if ($srcSetEnd lt $firstSetStart) {

      $source->move($self, $srcSetEnd);

      if ($progress_ref) {
        $ProgressI++;
        if ($ProgressI >= $ProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $ProgressCnt += $ProgressSteps;
        } else {
        } # if #
        $ProgressTargetSets++;
        my $t = $ProgressSourceSets * $ProgressTargetSets;
        $ProgressSteps = ( $t / $progress_ref->{-percent_part} ) || 1;
        $ProgressI = $ProgressI - $ProgressCnt;
        $ProgressCnt = $ProgressSteps * $ProgressSourceSets;
        $ProgressI = $ProgressI + $ProgressCnt;
      } # if #

      next;
    } # if #


    # All archive sets, merge in from source set
    for my $setDate (sort(keys(%{$sets}))) {

      if ($progress_ref) {
        $ProgressI++;
        if ($ProgressI > $ProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $ProgressCnt += $ProgressSteps;
        } else {
        } # if #
        $ProgressTargetSets++;
        my $t = $ProgressSourceSets * $ProgressTargetSets;
        $ProgressSteps = ( $t / $progress_ref->{-percent_part} ) || 1;
        $ProgressI = $ProgressI - $ProgressCnt;
        $ProgressCnt = $ProgressSteps * $ProgressSourceSets;
        $ProgressI = $ProgressI + $ProgressCnt;
      } # if #

      next
          if ($setDate eq NO_DATE);
      my $setStart    = $self->getSets($setDate, 'start_date');
      my $setEnd      = $self->getSets($setDate, 'end_date'  );
      my $setTimes    = $self->getSets($setDate, 'times'     );
      my $setEventCfg = $self->getSets($setDate, 'event_cfg' );
      my $setSchedule = $self->getSets($setDate, 'schedule'  );

      if ($setEnd ge $startDate) {

        # Calculate expected end of previous set, usually same as $prevSetEnd
        my $expectedPrevSetEnd =
                       $setStart ne NO_DATE ?
                         $self->{erefs}{-calculate}->stepDate($setStart, -1) :
                         NO_DATE ;

        # Handle part of set between end of previous set and
        # beginning of this set
        if (($prevSetEnd lt $expectedPrevSetEnd)
            and
            (($srcSetStart lt $expectedPrevSetEnd  ) and
             ($srcSetEnd   gt $prevSetEnd)     )
           ) {

          my $tmpStart = $prevSetEnd ge $startDate ?
                               $prevSetEnd : $startDate;
          my $tmpEnd   = $expectedPrevSetEnd le $endDate ?
                               $expectedPrevSetEnd : $endDate;
          my $set = $self->createSet($tmpStart    ,
                                     $tmpEnd      ,
                                     $srcEventCfg ,
                                     $srcTimes    ,
                                    );

          $self->addSet($set);
        } # if #

        # Merge part of source set within this set dates to this set
        if (($srcSetStart le $setEnd  ) and
            ($srcSetEnd   ge $setStart)    ) {
          $self->_mergeSets($source->getSets($srcSetDate, 'set' ),
                            $self->{sets}{$setEnd}
                           );
        } # if #

      } # if #

      $prevSetStart = $setStart;
      $prevSetEnd   = $setEnd  ;

    } # for #

    # Source set later than target, merge (move) to target
    if ($srcSetEnd gt $prevSetEnd) {
      # Create a set from last set end to end of source set
      my $set = $self->createSet($prevSetEnd  ,
                                 $srcSetEnd   ,
                                 $srcEventCfg ,
                                 $srcTimes    ,
                                );

      $self->addSet($set);
    } # if #


  } # for #

  $self->_mergeFromMain();

  $self->{erefs}{-times}     -> save();
  $self->{erefs}{-event_cfg} -> save();
  $self->{erefs}{-schedule}  -> save();
  $self->save();

  return 0;
} # Method _mergeData

#----------------------------------------------------------------------------
#
# Method:      importSet
#
# Description: Import the selected set into the times and event cfg data
#
# Arguments:
#  0 - Object reference
#  1 - Date for set to import
# Returns:
#  -

sub importSet($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  return undef
      unless (exists($self->{sets}{$date}));

  # Set to import
  my $set = $self->{sets}{$date};

  # Move data to the active data
  $set->{event_cfg} -> move($self->{erefs}{-event_cfg});
  $set->{schedule}  -> move($self->{erefs}{-schedule});
  $set->{times}     -> move($self->{erefs}{-times});

  $self->{erefs}{-event_cfg}->strings();

  $self->{erefs}{-cfg} -> set('archive_date',
                 $self->{erefs}{-calculate}->stepDate($set->{start_date}, -1)
                             );

  # And remove the imported set
  delete($self->{sets}{$date});

  $self->{erefs}{-times}     -> save();
  $self->{erefs}{-event_cfg} -> save();
  $self->{erefs}{-schedule}  -> save();
  $self->{erefs}{-cfg}       -> save();
  $self->save(1);

  return 0;
} # Method importSet

#----------------------------------------------------------------------------
#
# Method:      removeSet
#
# Description: Remove the selected archive set
#
# Arguments:
#  0 - Object reference
#  1 - Date for set to remove
# Returns:
#  -

sub removeSet($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  delete($self->{sets}{$date});

  my @tmp = $self->getSets();
  if (@tmp) {
    # There are still one or more sets...
    $self->{erefs}{-cfg} -> set('archive_date',
                 $self->{erefs}{-calculate}->stepDate($date, -1)
                               )
        if ($date);

  } else {
    # No remaining archive sets
    $self->{erefs}{-cfg} -> set('archive_date', NO_DATE);

  } # if #

  $self->save(1);

  return 0;
} # Method removeSet

#----------------------------------------------------------------------------
#
# Method:      archive
#
# Description: Add a period to the archive
#
# Arguments:
#  0 - Object reference
#  1 - End date of period to archive
# Returns:
#  -

sub archive($$) {
  # parameters
  my $self = shift;
  my ($end_date) = @_;


  # If the archive file not exists, use load to create the file
  $self->load()
    unless $self->fileExists();

  # Create an archive set
  my $start_date = $self->{erefs}{-cfg}->get('archive_date');

  my $set = $self->createSet($start_date,
                             $end_date,
                             $self->{erefs}{-event_cfg},
                             $self->{erefs}{-schedule},
                             $self->{erefs}{-times});

  $self->addSet($set);

  # And finally save the active data
  $self-> save(1);
  $self->{erefs}{-times}     -> save();
  $self->{erefs}{-event_cfg} -> save();
  $self->{erefs}{-schedule}  -> save();
  $self->{erefs}{-cfg}       -> save();

  return 0;
} # Method archive

1;
__END__
