#
package TbFile::Backup;
#
#   Document: Tidbox handle backup
#   Version:  1.0   Created: 2019-08-08 11:20
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Backup.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2019-08-08';

# History information:
#
# 1.0  2019-03-05  Roland Vallgren
#      First issue, moved content from TbFile.
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


#############################################################################
#
# Method section
#
#############################################################################
#

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create backup supervision object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              state => undef,
              timer => undef,
              file_names  => [],   # Queue of files to be checked
              file_refs   => {},   # References to files to backup
              file_states => {},   # Status of files, unchecked before exiting
             };

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      addFileToCheck
#
# Description: Add a backup file to check
#
# Arguments:
#  - Object reference
#  - Name of file object
#  - Reference to file object
# Returns:
#  -

sub addFileToCheck($$$) {
  # parameters
  my $self = shift;
  my ($name, $file_ref) = @_;

  $self->{file_refs}{$name} = $file_ref;
  $self->{file_states}{$name} = undef;
  return 0;
} # Method addFileToCheck

#----------------------------------------------------------------------------
#
# Method:      setLoadHandle
#
# Description: Set load handle for calculation of todays digest
#
# Arguments:
#  - Object reference
#  - loadHandle
# Returns:
#  -

sub setLoadHandle($$) {
  # parameters
  my $self = shift;
  my ($handle) = @_;

  $self->{loadHandle} = $handle;
  return 0;
} # Method setLoadHandle

#----------------------------------------------------------------------------
#
# Method:      _calculateDigest
#
# Description: Add a SHA-1 digest for identification of session lock
#
# Arguments:
#  - Object reference
# Returns:
#  digest in hexadecimal encoding

sub _calculateDigest($) {
  # parameters
  my $self = shift;


  my $files = $self->{file_refs};
  my $handle;
  if ($self->{loadHandle}) {
    # Continue calculate digest started by load
    $handle = $self->{loadHandle};
    $self->{loadHandle} = undef;
  } else {
    $handle = TbFile::FileHandleDigest->new();
  } # if #

  # Get values from hash in random order for variation
  while (my ($key, $ref) = each(%{$files})) {
    if ($key eq '-lock') {
      # Lock data is only added directly here and never from file
      my %lock = $ref->getLockData();
      $handle->add(values(%lock));
    } else {
      # Only add a file that has not been added before
      $handle->conditionalAddfile($ref);
    } # if #
  } # while #

  my $thisDigest = $handle->hexdigest();
  $self->{erefs}{-log}->log('Backup: New digest value:', $thisDigest);

  return $thisDigest;
} # Method _calculateDigest

#----------------------------------------------------------------------------
#
# Method:      addSessionDigest
#
# Description: Add a session digest for the session if it is locked and not
#              set today.
#              If session digest is updated, update lock digest also.
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Force calculation if true
# Returns:
#  -

sub addSessionDigest($;$) {
  # parameters
  my $self = shift;
  my ($force) = @_;


  # TODO Session digest should be calculated one file a minute after session
  #      is up unless forced
  #      Archive, times and log could be large files

  my $erefs = $self->{erefs};
  my $lock = $erefs->{-lock};

  $erefs->{-log}->log('Backup: addSessionDigest');

  if ($lock->isLocked()) {
    # Locked by another session, make a new attempt in a while
    $self->{erefs}{-clock}->
         timeout(-minute => scalar($erefs->{-cfg}->get('save_threshold')),
                 -callback => [$self => 'addSessionDigest']);
    return 1;
  } # if #

  unless ($force) {
    # Schedule a new digest in twelve hours, digest to be updated on new date
    # TODO We should not run this more than once every six ours
    #      Do not schedule a timeout if already queued
    $erefs->{-clock}->
         timeout(-minute => 6 * 60,
                 -callback => [$self => 'addSessionDigest']);
  } # unless #

  my $lockDigest = $lock->getDigest();
  my $thisDate = $erefs->{-clock}->getDate();
  my ($lastDigest, $lastDate) = $erefs->{-session}->getDigest(0);

  if ($lockDigest) {
    # Lock digest is set
    if ($lastDate and $thisDate le $lastDate) {
      $erefs->{-log}->log('Backup: Session digest already saved today');
      return 0;
    } # if #

  } # if #

  my $thisDigest = $self->_calculateDigest();

  $lock->setDigest($thisDigest)
      unless($lockDigest);
  $erefs->{-session}->addDigest($thisDigest, $thisDate);
  $erefs->{-log}->log('Backup: Added todays session digest');

  return 0;
} # Method addSessionDigest

#----------------------------------------------------------------------------
#
# Method:      checkLockDigest
#
# Description: Check lock file digest
#
# Arguments:
#  - Object reference
#  - Directory to check
# Returns:
#  'NoLock'              No lock found
#  'NoDigestInOtherLock' One lock did not have a digest
#  'LockedByOther'       Locked by another session
#  'OurLock'             This is our lock

sub checkLockDigest($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;


  my $lockDigestStatus;

  while (1) {
    $lockDigestStatus = $self->{erefs}{-lock}->checkLockDigest($dir);

    last
        unless ($lockDigestStatus eq 'NoDigestInOur');

    # Our lock did not have a digest
    # Force digest to be calculated
    $self->addSessionDigest(1);

  } # while #


  return $lockDigestStatus;

} # Method checkLockDigest

#----------------------------------------------------------------------------
#
# Method:      checkSessionDigest
#
# Description: Check session digest for session
#
# Arguments:
#  - Object reference
#  - Directory to check
# Returns:
#  'NoSession'     Directory contains no session data
#  'OurSession'    It is our session
#  'OlderSession'  It is an older session of our instance
#  'NewerSession'  Our session is history of other session (BEWARE)
#  'BranchSession' It is a branch of our instance
#  'OtherInstance' Other is another instance
#  'NoDigest'      No digest found, no check can be made

sub checkSessionDigest($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;


  # Check session digest
  my $sessionDigestStatus =
           $self->{erefs}{-session}->checkSessionHistory($dir);

  #  undef - Can not load other session
  # Other session does not exist
  # New backup directory
  return 'NoSession'
      unless (defined($sessionDigestStatus));

  # It is our session
  return 'OurSession'
      if ($sessionDigestStatus == 1);

  # It is an older session of our instance
  return 'OlderSession'
      if ($sessionDigestStatus == 2);

  # Our session is history of other session (BEWARE)
  return 'NewerSession'
      if ($sessionDigestStatus == 3);

  # It is a branch of our instance
  return 'BranchSession'
      if ($sessionDigestStatus == 4);

  # Other is another instance
  return 'OtherInstance'
      if ($sessionDigestStatus == 0);


  # No digest found, no check can be made
  # TODO Wait a while for digest to be added and recheck
  #      Is it from an old Tidbox ( before 4.11 )
  #      Then a digest will never appear
  return 'NoDigest'
      if ($sessionDigestStatus == -1);

  # This should not happen
  return 'ERROR';
} # Method checkSessionDigest

#----------------------------------------------------------------------------
#
# Method:      checkDirectoryDigest
#
# Description: Check directory digest information in directory
#
# Arguments:
#  - Object reference
#  - Directory to check, 'dir', 'bak, or directory path
# Returns:
#  'OurLock'           This is our lock from our session
#  'LockedByOther'     Locked by another session
#  'NoSession'         Directory contains no lock or session data
#  'OurSessionLocked'  It is our session without another lock
#  'OurSessionNoLock'  It is our session (without lock ??)
#  'NewerSession'      Our session is history of other session (BEWARE)
#  'BranchSession'     It is a branch of our instance
#  'OtherInstance'     Other is another instance

sub checkDirectoryDigest($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;



  my $lockState = $self->checkLockDigest($dir);

  my $sessionState = $self->checkSessionDigest($dir);

  if ($lockState eq 'OurLock') {
    # This is our lock
    return 'OurLock';
  } elsif ($lockState eq 'NoLock') {
    # No lock found
    ; # Check session state
  } elsif ($lockState eq 'NoDigestInLock') {
    # Other lock did not have a digest
    ; # Check session state
  } elsif ($lockState eq 'LockedByOther') {
    if ($sessionState eq 'OurSession' or
        $sessionState eq 'OlderSession' or
        $sessionState eq 'NewerSession' or
        $sessionState eq 'BranchSession'
       ) {
      # It is our instance but lock was left by another session
      # We should just replace the lock
      return 'OurSessionLocked';
    } else {
      # It is another instance
      # TODO How do we do
      #      - Don't use
      #      - Take over
      # TODO We can become a slave or ask other session to become a slave to our
      return 'LockedByOther';
    } # if #
  } # if #

  # We come here if no lock was found or the lock had no digest
  if ($sessionState eq 'NoSession') {
    # Directory contains no session data
    # Is it a Tidbox directory at all?
    return 'NoSession';
  } elsif ($sessionState eq 'OurSession') {
    # It is our session without lock
    return 'OurSessionNoLock';
  } elsif ($sessionState eq 'OlderSession') {
    # It is an older session of our instance (Without lock ???)
    return 'OurSessionNoLock';
  } elsif ($sessionState eq 'NewerSession') {
    # Our session is history of other session (BEWARE)
    return 'NewerSession';
  } elsif ($sessionState eq 'BranchSession') {
    # It is a branch of our instance
    return 'BranchSession';
  } elsif ($sessionState eq 'OtherInstance') {
    # Other is another instance
    return 'OtherInstance';
  } elsif ($sessionState eq 'NoDigest') {
    # No digest found, no check can be made
    return 'OtherInstance';
  } # if #

  return 0;
} # Method checkDirectoryDigest

#----------------------------------------------------------------------------
#
# Method:      checkBackupDirectory
#
# Description: Check if the directory is usable as backup directory
#
# Arguments:
#  - Object reference
#  - Directory name
# Returns:
#  - 'OK'                       A correct directory specified
#  - 'noArgumentProvided'       No directory name specified
#  - 'sameAsActiveDirectory'    Same dictory as primary directory
#  - 'doesNotExist'             Directory does not exist
#  - 'notADirectory'            Name is not a directory
#  - 'notWriteAccess'           We do not have write access to the directory
#  - 'failedOpenDir'            Directory can not be opened for reading
 
sub checkBackupDirectory($$) {
  # parameters
  my $self = shift;
  my ($d) = @_;


  my $erefs = $self->{erefs};
  my $log = $erefs->{-log};

  my $directoryStatus = TbFile::Util->checkTidBoxDirectory($d, $log);

  return $directoryStatus
      unless ($directoryStatus eq 'dirIsEmpty' or
              $directoryStatus eq 'OK');

  # Do not allow backup to be same as session directory
  if ($d eq $erefs->{-cfg}->dirname('dir')) {
    $log->log('Backup: CheckBackupDirectory: Backup directory ' .
              'can not be same as working directory');
    return 'sameAsActiveDirectory';
  } # if #

  return 'OK';
} # Method checkBackupDirectory

#----------------------------------------------------------------------------
#
# Method:      resetCheckBackup
#
# Description: Reset backup check to state to begin checking
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Time to delay check
# Returns:
#  -

sub resetCheckBackup($;$) {
  # parameters
  my $self = shift;
  my ($time) = @_;


  $self->{state} = 0;
  $self->{timer} = $time || 3;

  return 0;
} # Method resetCheckBackup

#----------------------------------------------------------------------------
#
# Method:      restartCheckBackup
#
# Description: Restart backup check to run next check loop
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Time to delay check
# Returns:
#  -

sub restartCheckBackup($;$) {
  # parameters
  my $self = shift;
  my ($time, $state) = @_;


  $self->{state} = $state || 2;
  $self->{timer} = $time  || 1;

  return 0;
} # Method restartCheckBackup

#----------------------------------------------------------------------------
#
# Method:      autoCheckBackup
#
# Description: Check if backup directory is in place and make
#              sure the backup is up to date
#              Backup state:
#                0 - Started, first backup check pending
#
#                1 - Timeout initialize backup check
#                2 - Backup exists and timer is running, wait for timeout
#                2 - Initate backup verification
#                3 - Verification ongoing, check one file at timeout
#                9 - Timeout after long delay, Restart backup check sequence
#
#               -1 - Backup not found or not active, timer is running
#               -2 - Backup did exist but was lost, timer is running
#
#       In ordinary operation the backup should contain lock an session
#       from this session. If it gets lost then it could come back rather
#       soon.
#        => Anything other than OurLock should not happen
#           Handle as ignore until it corrects it self
#       If the backup is on a network device then it could be disconnected
#       for a long time. But the same session should come back when connected
#       again.
#        => Possible states: OurLock, OurSessionNoLock
#           Go on with the backup
#       If the network device is disconnected for a very long time,
#       weeks or months
#        => Possible states: OtherInstance
#       Conclusion: Backup should only handle its own instance, no merge
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - if success

sub autoCheckBackup($) {
  # parameters
  my $self = shift;


  my $files = $self->{file_refs};
  my $log = $self->{erefs}{-log};

  # Locked by another session, skip
  return 1
      if ($self->{erefs}{-lock}->isLocked());

  return 1
      if (--$self->{timer} > 0);

  # TODO Should we check the directory every minute?
  my $backupDir = $self->{erefs}{-cfg}->dirname('bak');
  my $save_threshold = $self->{erefs}{-cfg}->get('save_threshold');

  if (defined($backupDir)) {

    # Backup directory exists, handle it
    if ($self->{state} == 0) {
      # 0 - Started, first backup check pending
      $self->restartCheckBackup();


    } elsif ($self->{state} == 2) {
      # 2 - Initate backup verification
      $self->{state} = 3;
      $self->{timer} = 1;

      # Check that all backups are up to date
      push @{$self->{file_names}}, keys(%{$self->{file_refs}});

      # Check logging on backup
      $log->checkBackup();
      $log->log('Backup: Initialize backup OK check');

    } elsif ($self->{state} == 3) {
      # 3 - Verification ongoing, check one file at timeout
      if (@{$self->{file_names}}) {
        # One more file to check, Perform check that backup is OK
        my $file_key = pop(@{$self->{file_names}});
        # TODO Consider using a digest (sha checksum) to verify backup
        #      => Read both files => Slower
        $self->{file_states}{$file_key} =
             $files->{$file_key}->copyBackup();
        $log->log('Backup: Verified backup for', $file_key);
        $self->{timer} = 1;

      } else {
        # All backups checked: Schedule next check
        $log->log('Backup: Check done, schedule next check');
        $self->{state} = 9;
        $self->{timer} = 10 * $save_threshold;

      } # if #

    } elsif ($self->{state} == 9) {
      # 9 - Timeout after long delay, Restart backup check sequence
      $self->restartCheckBackup();

    } elsif ($self->{state} < 0) {
      # -1 - Backup was unavailable from start
      # -2 - Backup was lost and came back
      # => Check backup directory

      # TODO Chain digest supervision with backup
      #      That is if digest check, skip backup check this minute
      my $state = $self->checkDirectoryDigest('bak');

      if ($state eq 'OurLock' or
          $state eq 'OurSessionNoLock') {
        # Our lock, initiate new backup cycle
        # Our session, without lock, initiate new backup cycle
        $self->restartCheckBackup();
      } else {
        # Not handled state, Wait a while and try again
        $self->{state} = -2;
        $self->{timer} = $save_threshold * 4;
      } # if #

# TODO Here could future improvement add merge, after a confirm

    } else {
      # Unknown backup state, this should not happen
      carp 'WARNING: ', __PACKAGE__,
                     ': Unknown backup state check: ', $self->{state};
      $log->log('WARNING: ', __PACKAGE__,
                     ': Unknown backup state check: ', $self->{state});
      $log->log('Backup: Restarting backup check');
      $self->restartCheckBackup();

    } # if #

  } else {

    # Backup directory not found

    if ($self->{state} == 0) {
      # 0 - Started or first backup check pending: Reset timer
      $self->{timer} = $save_threshold;
      $self->{state} = -1;

    } elsif ($self->{state} == -1 or
             $self->{state} == -2) {
      # -1 or -2 - Reset timer and keep waiting
      $self->{timer} = $save_threshold;

    } elsif ($self->{state} > 0) {
      # >0 - Backup did exist, but was lost, reset backup check
      for my $file_state (values(%{$self->{file_states}})) {
        $file_state = undef;
      } # for #
      $self->{state} = -2;
      $self->{timer} = $save_threshold;
      $log->log('Backup: Backup directory was lost');

    } else {
      # Unknown backup state, this should not happen
      carp 'WARNING: ', __PACKAGE__,
           ': Unknown backup unavailable state check: ', $self->{state};
      $log->log('Backup: WARNING: ', __PACKAGE__,
           ': Unknown backup unavailable state check: ', $self->{state});
      $log->log('Backup: Restarting backup check');
      $self->{state} = 0;
      $self->{timer} = 1;

    } # if #

  } # if #

  return 0;
} # Method autoCheckBackup

#----------------------------------------------------------------------------
#
# Method:      startAuto
#
# Description: Start backup check timer
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub startAuto($) {
  # parameters
  my $self = shift;


  # Set backup state to started
  $self->resetCheckBackup();
  $self->{erefs}{-clock}->repeat(-minute => [$self => 'autoCheckBackup']);

  # Add session digest for this session after thirtyseven seconds
  $self->{erefs}{-clock}->
     timeout(-second => 37, -callback => [$self => 'addSessionDigest']);


  return 1;
} # Method startAuto

#----------------------------------------------------------------------------
#
# Method:      replaceBackupData
#
# Description: Replace backup data with data from this instance
#              All files, except log, are copied to backup directory
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Step progress indicator callback
# Returns:
#  -

sub replaceBackupData($;$) {
  # parameters
  my $self = shift;
  my (@progress) = @_;

  my $files = $self->{file_refs};

  # Copy all files except log
  $self->{erefs}->{-log}->log('Backup: Replace backup from this instance');
  for my $k (keys(%{$self->{file_refs}})) {
    $files->{$k}->forcedCopy('dir', 'bak');
    $self->callback(@progress, 12);
  } # for #

  return 0;
} # Method replaceBackupData

#----------------------------------------------------------------------------
#
# Method:      mergeBackupData
#
# Description: Merge instance with data from backup
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Step progress indicator callback
# Returns:
#  -

sub mergeBackupData($;$) {
  # parameters
  my $self = shift;
  my (@progress) = @_;

  my $files = $self->{file_refs};
  $self->{erefs}{-log}->log('Backup: Merge backup data');

  # Lock backup
  $files->{-lock}->forcedCopy('dir', 'bak');

  # Progress bar steps 1% each step
  # Session, cfg and supervision have 1% each
  # Event cfg have 2%
  # Times have 20%
  # Archive have 75%

  # Get file sizes of possible large files for progress bar handling
  # Start on 6: Session, Configuration and Supervision get 1% each
  #             Overhead and book keeping afterwards get 3%
  my $progress_sum = 6;
  my $progress_ref = {};
  for my $k (qw(-event_cfg -times -archive)) {
    my $d = $files->{$k}->getFileSize('dir');
    my $b = $files->{$k}->getFileSize('bak');
    my $s = $d + $b;
    $progress_sum += $s;
    $progress_ref->{$k}->{dir} = $d;
    $progress_ref->{$k}->{bak} = $b;
    $progress_ref->{$k}->{sum} = $s;
    $progress_ref->{$k}->{-callback} = \@progress;
  } # for #
  for my $k (qw(-event_cfg -times -archive)) {
    $progress_ref->{$k}->{-percent_part} =
          int(94 * $progress_ref->{$k}->{sum} / $progress_sum) || 1;
  } # for #

  # Merge session data from backup into current session
  for my $k (qw(-session -cfg -supervision -event_cfg -times)) {
    $files->{$k}->merge(-fromDir => 'bak', -progress_h => $progress_ref->{$k});
    $self->callback(@{$progress_ref->{-callback}});
#   Plugin.pmx , merge       TODO
  } # for #

  $files->{-archive}->merge(-fromDir   => 'bak'     ,
                            -progress_h => $progress_ref->{-archive} ,
                           );
  $self->callback(@{$progress_ref->{-callback}});

  # Save all and Unload -archive
  for my $k (qw(-session -cfg -supervision -event_cfg -times -archive)) {
    $files->{$k}->save(1);
  } # for #
  $files->{-archive}->clear();    # Unload archive
  $self->callback(@{$progress_ref->{-callback}});

  # Add session digest after merge
  my $thisDate   = $self->{erefs}{-clock}->getDate();
  my $thisDigest = $self->_calculateDigest();
  $files->{-lock}->setDigest($thisDigest);
  $files->{-session}->addDigest($thisDigest, $thisDate);
  $self->{erefs}{-log}->
       log('Backup: Added todays session digest after merge data', $thisDigest);

  return 0;
} # Method mergeBackupData

#----------------------------------------------------------------------------
#
# Method:      replaceSessionData
#
# Description: Drop data in this session and use data from backup instead
#              Forced copy from backup
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Step progress indicator callback
# Returns:
#  -

sub replaceSessionData($;$) {
  # parameters
  my $self = shift;
  my (@progress) = @_;

  my $files = $self->{file_refs};

  # Lock backup
  $files->{-lock}->forcedCopy('dir', 'bak');

  # Copy and load live session data
  # TODO Plugin? That need a reload, that is restart of Tidbox
  #      We need to check if plugins are added or removed
  for my $k (qw(-event_cfg -supervision -plugin -times)) {
    $files->{$k}->forcedCopy('bak', 'dir');
    $files->{$k}->load();
    $self->callback(@progress, 12);
  } # for #

  # Copy archive
  $files->{-archive}->forcedCopy('bak', 'dir');
  $files->{-archive}->clear();
  $self->callback(@progress, 12);

  $files->{-cfg}->replace();
  $self->callback(@progress, 12);

  $files->{-session}->replace();
  $self->callback(@progress, 12);

  # Add session digest after merge
  my $thisDate   = $self->{erefs}{-clock}->getDate();
  my $thisDigest = $self->_calculateDigest();
  $files->{-lock}->setDigest($thisDigest);
  $files->{-session}->addDigest($thisDigest, $thisDate);
  $self->{erefs}{-log}->log(
         'Added todays session digest after replace data in this session',
          $thisDigest);
  $self->callback(@progress, 2);

  # TODO This does not handle Edit EventCfg correct if it shows another date
  my @dates = ($self->{erefs}{-clock}->getDate());
  # Update all subscribed changes
  for my $k (qw(-cfg -event_cfg -supervision -plugin -times)) {
    $files->{$k}->_doDisplay(@dates);
  } # for #

  return 0;
} # Method replaceSessionData

#----------------------------------------------------------------------------
#
# Method:      end
#
# Description: Check that all backup files are updated
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Callback to display information about save
# Returns:
#  -

sub end($;$) {
  # parameters
  my $self = shift;
  my ($message) = @_;


  my $files = $self->{file_refs};

  # Check if any backup need an update
  while (my ($file_key, $val) = each(%{$self->{file_states}})) {
    unless (defined($val)) {
      $self->callback($message);
      $val = $files->{$file_key}->copyBackup();
    } # unless #
  } # while #


  return 0;
} # Method end

1;
__END__
