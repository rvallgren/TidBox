#
package TbFile;
#
#   Document: Handle all files
#   Version:  2.5   Created: 2019-02-07 15:54
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: TbFile.pmx
#

my $VERSION = '2.5';
my $DATEVER = '2019-02-07';

# History information:
#
# 1.0  2011-02-25  Roland Vallgren
#      First issue.
# 1.1  2012-06-04  Roland Vallgren
#      not_set_start => start_operation :  none, workday, event, end pause
# 2.0  2012-09-10  Roland Vallgren
#      Added session lock
# 2.1  2015-08-10  Roland Vallgren
#      Added configurations needed by Settings
#      Moved check lock for start session in Times to Times.pm
#      Show version information in log
#      Added supervision of backup
# 2.2  2017-03-08  Roland Vallgren
#      Don't log when session.dat is written
# 2.3  2017-09-13  Roland Vallgren
#      Added support for plug-in
#      Removed support for import of earlier Tidbox data
#      Added handling for migration of data between versions
# 2.4  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      Renamed FileSupervisor to TbFile (TidboxFile)
#      References to other objects in own hash
#      Added handling of new backup directory that contains tidbox data
#      Backup directory is monitored for existence and part of this session
# 2.5  2019-01-25  Roland Vallgren
#      Use TbFile::Util to read directory
#      Removed log->trace
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use integer;

use TidVersion qw(register_starttime);

use TbFile::FileHandleDigest;
use TbFile::Log;
use TbFile::Lock;
use TbFile::Configuration;
use TbFile::Session;
use TbFile::Times;
use TbFile::EventCfg;
use TbFile::Supervision;
use TbFile::Plugin;
use TbFile::Archive;

use Digest;
use Carp;

# Register version information
{
  use TidVersion qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}


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
# Description: Create object and create all file objects
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($args) = @_;

  # Load -cfg first to make sure backup is checked
  my $order = [
               qw(-cfg -lock -session -event_cfg -supervision -plugin -times)
              ];
  my $extra = [ qw(-archive) ];

  my $files = {
              -lock        => new TbFile::Lock(),

              -log         => new TbFile::Log(),

              -cfg         => new TbFile::Configuration($args),

              -session     => new TbFile::Session($args),

              -event_cfg   => new TbFile::EventCfg(),

              -supervision => new TbFile::Supervision(),

              -times       => new TbFile::Times(),

              -plugin      => new TbFile::Plugin(),

              -archive     => new TbFile::Archive(),

             };

  # Backup check data
  my $backup = {
                files => [],
                file_states => {},
               };

  my $self = {
              order  => $order,
              extra  => $extra,
              files  => $files,
              backup => $backup,
             };
  bless($self, $class);
  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      configure
#
# Description: Setup needed references
#
# Arguments:
#  - Object reference
#  - Hash with needed references
# Returns:
#  -

sub configure($%) {
  # parameters
  my $self = shift;
  my (%args) = @_;


  $self->SUPER::configure(%args);

  my $files = $self->{files};

  $files->{-cfg} ->
      configure(
                -cfg         => $files->{-cfg},
                -lock        => $files->{-lock},
                -event_cfg   => $files->{-event_cfg},
                -log         => $files->{-log},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-event_cfg} ->
      configure(
                -cfg         => $files->{-cfg},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-log} ->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-lock} ->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-session} ->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-times} ->
      configure(
                -cfg         => $files->{-cfg},
                -event_cfg   => $files->{-event_cfg},
                -session     => $files->{-session},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-supervision} ->
      configure(
                -cfg         => $files->{-cfg},
                -times       => $files->{-times},
                -log         => $files->{-log},
                -event_cfg   => $files->{-event_cfg},
                -clock       => $args{-clock},
                -calculate   => $args{-calculate},
                -error_popup => $args{-error_popup},
               );

  $files->{-plugin} ->
      configure(
                -cfg         => $files->{-cfg},
                -session     => $files->{-session},
                -times       => $files->{-times},
                -log         => $files->{-log},
                -event_cfg   => $files->{-event_cfg},
                -plugin      => $files->{-plugin},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-archive} ->
      configure(
                -cfg         => $files->{-cfg},
                -times       => $files->{-times},
                -log         => $files->{-log},
                -event_cfg   => $files->{-event_cfg},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  return 0;
} # Method configure

#----------------------------------------------------------------------------
#
# Method:      load
#
# Description: Load files needed for operation
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub load($) {
  # parameters
  my $self = shift;

  my $files = $self->{files};

  my $handle = TbFile::FileHandleDigest->new();
  my $loaded;

  # Load configuration first, only from local storage
  $files->{-cfg}->load('dir', $handle);

  # Load local lock and if backup is enabled, backup lock
  $loaded = $files->{-lock}->load('dir', $handle);
  if ($files->{-cfg}->isBackupEnabled()) {
    if ($loaded) {
      my $backupLock = $files->{-lock}->loadOther('bak');
      if ($backupLock) {
        my $lockDigest = $files->{-lock}->getDigest() || 'noDigest';
        my $backupDigest = $backupLock->getDigest() || 'noDigest';
        # Both local and backup have lock
        if ($lockDigest ne $backupDigest) {
          # Disable unlock
          $self->{lock_digestDiffers} = 1;
        } # if #
      } # if #
    } else {
      $files->{-lock}->load('bak', $handle);
    } # if #
  } # if #

  # Load local session and if backup is enabled, backup session
  $loaded = $files->{-session}->load('dir', $handle);
  if ($files->{-cfg}->isBackupEnabled()) {
    my $sessionState = $self->_checkSessionDigest('bak');

#    if ($sessionState eq 'NoSession') {
      # Backup contains no session data
      # Is it a Tidbox directory at all?
#
#    } elsif ($sessionState eq 'OurSession') {
      # It is our session
#
#    } elsif ($sessionState eq 'OlderSession') {
#      # It is an older session of our instance
#
#    } elsif ($sessionState eq 'NewerSession') {
    if ($sessionState eq 'NewerSession') {
      # Our session is history of other session (BEWARE)
      $self->{session_backup_operation} = 'merge';

    } elsif ($sessionState eq 'BranchSession') {
      # It is a branch of our instance
      $self->{session_backup_operation} = 'merge';

    } elsif ($sessionState eq 'OtherInstance') {
      # Other is another instance
      # TODO How do we do this?
      $self->{session_backup_operation} = 'notOurInstance';

#    } else {
      # Not handled session state
#
    } # if #

  } # if #

  # Load remaining files from local storage as usual

  while (my ($k, $r) = each(%{$files})) {
    next
        if ($k eq '-cfg'     or
            $k eq '-lock'    or
            $k eq '-session' or
            $k eq '-log'     or
            $k eq '-archive'   );
# TODO No check is made if load failed: for example wrong file format
    $r->load('dir', $handle);
  } # while #

  $self->{loadHandle} = $handle;
  return 0;
} # Method load

#----------------------------------------------------------------------------
#
# Method:      init
#
# Description: Initiate session
#              - Migrate data if new version
#              - Lock
#              - Enable auto save, backup check
#              - Register impacted handling
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub init($) {
  # parameters
  my $self = shift;
  my ($date, $time, $version) = @_;

  my $files = $self->{files};
  # Migrate data between Tidbox versions
  if ($files->{-session}->get('last_version') ne $version) {
    require MigrateVersion;
    MigrateVersion->MigrateData(
                  -cfg         => $files->{-cfg},
                  -session     => $files->{-session},
                  -times       => $files->{-times},
                  -log         => $files->{-log},
                  -event_cfg   => $files->{-event_cfg},
                  -plugin      => $files->{-plugin},
                  );
  } # if #

  # Lock session
  my $lock = $self->{files}{-lock};
  $lock->lock($date, $time);
  # TODO Should we have two digests in lock?
  #     1: Lock digest is set immediately
  #     2: Session digest is set when session digest is added to session

  # Start auto saving for files and register impacted
  for my $k (@{$self->{order}}, @{$self->{extra}}) {
    $files->{$k}->startAuto();
    $files->{-cfg}->impacted($files->{$k});
    $self->{backup}{file_states}{$k} = undef;
  } # for #

  return 0;
} # Method init

#----------------------------------------------------------------------------
#
# Method:      getRef
#
# Description: Get reference to a file object
#
# Arguments:
#  - Object reference
#  - Name of file object
# Returns:
#  Reference to the object

sub getRef($$) {
  # parameters
  my $self = shift;
  my ($name) = @_;

  return $self->{files}{$name}
      if (exists($self->{files}{$name}));
  return undef;
} # Method getRef

#----------------------------------------------------------------------------
#
# Method:      start
#
# Description: Set start time and date of this session
#
# Arguments:
#  - Object reference
#  - Date
#  - Time
#  - Call string of the program
#  - Version information for logging
# Returns:
#  -

sub start($$$$) {
  # parameters
  my $self = shift;
  my ($date, $time, $args, $title) = @_;


  my $files = $self->{files};

  # Start logging
  $files->{-log}->start();
  $files->{-log}->log('------', 'Started', $title, '------');
  $files->{-log}->log('Command', $args->{-call_string}, @{$args->{-argv}});

  # Set start time
  TidVersion->register_starttime($date, $time);

  $files->{-session}->start($date, $time);

  $files->{-times}->startSession($date, $time);

  TidVersion->register_locked_session($files->{-lock}->get());


  # Setup supervision
  $files->{-supervision}->setup();

  # Start supervision of backup directory
  $self->startAuto();

  # Add session digest for this session after one minute
  $self->{erefs}{-clock}->
     timeout(-minute => 1, -callback => [$self => 'addSessionDigest']);

  # Start verify session integrity
  $self->{erefs}{-clock}->
         timeout(-minute => 4,
                 -callback => [$self => 'verifySessionLockIntegrity']);


  return 0;
} # Method start

#----------------------------------------------------------------------------
#
# Method:      error_warning
#
# Description: Start loggin errors and warnings
#
# Arguments:
#  0 - Object reference
#  1 - Reference to error hash
#  2 - Reference to warning hash
# Returns:
#  -

sub error_warning($$$) {
  # parameters
  my $self = shift;

  my $log = $self->{files}{-log};
  for my $ref (@_) {
    $ref->{handler} = $log;
    push @{$self->{error_warning}}, $ref;
    for my $l (@{$ref->{list}}) {
      $log->log($ref->{prefix}, $l);
    } # for #

  } # for #

  return 0;
} # Method error_warning

#----------------------------------------------------------------------------
#
# Method:      end
#
# Description: Set end time and date of this session
#              Save all files
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


  my $files = $self->{files};

  # Set end time
  $files->{-session}->end();

  # Save not saved data for configuration and times
  for my $r (values(%{$files})) {
    $self->callback($message);
    $r->save();
  } # for #

  # Check if any backup need an update
  while (my ($file_key, $val) = each(%{$self->{backup}{file_states}})) {
    unless (defined($val)) {
      $self->callback($message);
      $val = $files->{$file_key}->copyBackup();
    } # unless #
  } # while #

  # Turn of logging of errors and warnings
  for my $ref (@{$self->{error_warning}}) {
    $ref->{handler} = undef;
  } # for #


  $self->{files}{-log}->log('------ Ended tidbox ------');

  # Unlock session
  $files->{-lock}->unlock();



  return 0;
} # Method end

#----------------------------------------------------------------------------
#
# Method:      checkSessionLock
#
# Description: Show callback that session is locked by another session
#
# Arguments:
#  - Object reference
#  - Callback to show the lock message
# Returns:
#  -

sub checkSessionLock($) {
  # parameters
  my $self = shift;
  my ($callback) = @_;


  $self->{locked_callback} = $callback;

  if ($self->{files}{-lock}->isLocked()) {
    unless ($self->{lock_digestDiffers}) {
      $self->callback($callback, 'locked');
    } else {
      $self->callback($callback, 'different_locked');
    } # unless #

  } # if #

  return 0;
} # Method checkSessionLock

#----------------------------------------------------------------------------
#
# Method:      checkBackupDirectory
#
# Description: Check if the directory is usable as backup directory
#              - Is it empty
#              - Does it contain Tidbox files
#
# Arguments:
#  - Object reference
#  - Directory name
# Returns:
#  - 'OK'                       A correct directory specified
#  - undef                      No directory name specified
#  - 'sameAsActiveDirectory'    Same dictory as primary directory
#  - 'doesNotExist'             Directory does not exist
#  - 'notADirectory'            Name is not a directory
#  - 'notWriteAccess'           We do not have write access to the directory
#  - 'failedOpenDir'            Directory can not be opened for reading
 
sub checkBackupDirectory($$) {
  # parameters
  my $self = shift;
  my ($d) = @_;


  my $files = $self->{files};
  my $log = $files->{-log};

  unless ($d) {
    $log->log('CheckBackupDirectory: No argument provided');
    return undef;
  } # unless #

  # Do not allow backup to be same as session directory
  if ($d eq $files->{-cfg}->dirname('dir')) {
    $log->log('CheckBackupDirectory: Backup directory ',
              'can not be same as working directory');
    return 'sameAsActiveDirectory';
  } # if #

  unless (-e $d) {
    # Does not exist
    $log->log('CheckBackupDirectory:', $d, 'does not exist');
    return 'doesNotExist';
  } # if #

  unless (-d $d) {
    # Arument is not a directory or name does not exist
    $log->log('CheckBackupDirectory:', $d, 'is not a directory');
    return 'notADirectory';
  } # unless #

  unless (-w $d) {
    # No write access to the directory
    # TODO Write protected does not work on Windows.
    #      We do not check result of write
    $log->log('CheckBackupDirectory:', $d, 'is read only');
    return 'notWriteAccess';
  } # unless #

  # Check if there are any files in the directory
  my $dirFiles = TbFile::Utils->readDir($d);
  unless (defined($dirFiles)) {
    # Failed to open directory for reading
    $log->log('CheckBackupDirectory: Failed to open', $d, 'for reading');
    return 'failedOpenDir';
  } # unless #

  my $fileCnt = 0;
  for my $f (@{$dirFiles}) {
    $fileCnt++;
  } # for #

  return 'OK';
} # Method checkBackupDirectory

#----------------------------------------------------------------------------
#
# Method:      _checkLockDigest
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

sub _checkLockDigest($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;

  my $files = $self->{files};

  my $lockDigestStatus;

  while (1) {
    $lockDigestStatus = $self->{files}{-lock}->checkLockDigest($dir);

    last
        unless ($lockDigestStatus eq 'NoDigestInOur');

    # Our lock did not have a digest
    # Force digest to be calculated
    $self->addSessionDigest(1);

  } # while #


  return $lockDigestStatus;

} # Method _checkLockDigest

#----------------------------------------------------------------------------
#
# Method:      _checkSessionDigest
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

sub _checkSessionDigest($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;


  # Check session digest
  my $sessionDigestStatus =
           $self->{files}{-session}->checkSessionHistory($dir);

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
  carp ('ERROR: Unknown session digest status: ', $sessionDigestStatus);
  return 'ERROR';
} # Method _checkSessionDigest

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


  my $files = $self->{files};

  my $lockState = $self->_checkLockDigest($dir);

  my $sessionState = $self->_checkSessionDigest($dir);

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
# Method:      verifySessionLockIntegrity
#
# Description: Verify that the session lock is still the same as the one
#              on file.
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub verifySessionLockIntegrity($) {
  # parameters
  my $self = shift;


  # TODO Check backup lock if primary lock is OK
  #      Handle in verifyBackup?

  my $log = $self->{files}{-log};

  # Schedule next check
  $self->{erefs}{-clock}->
         timeout(-minute => 7,
                 -callback => [$self => 'verifySessionLockIntegrity']);

  my $lockState = $self->_checkLockDigest('dir');

  if ($lockState eq 'OurLock') {
    # This is our lock, all OK, wait for next check
    return 0;
  } # if #

  if ($lockState eq 'NoLock') {
    # No lock found
    # TODO Something fishy is going on, someone else has removed the lock
    #      Lock session, data might not be consistent
    # TODO We have no data to set locked with
    #      Can we ask user?
    $self->callback($self->{locked_callback}, 'lost');
    return 0;
  } # if #

  if ($lockState eq 'NoDigestInOurLock') {
    # Our lock did not have a digest
    return 0;
  } # if #

  if ($lockState eq 'NoDigestInOtherLock') {
    # One lock did not have a digest
    # This could be startup, just skip and se what happens next time we check
    # TODO We should know that we have waited long enough
    return 0;
  } # if #

  if ($lockState eq 'LockedByOther') {
    # Another session has grabbed the lock, Lock our session
    $self->{files}{-lock}->load();
    $self->{erefs}{-clock}->setLocked('Tidbox är låst');
    # TODO Tell Tidbox it is locked by another session
    $self->callback($self->{locked_callback}, 'claimed');
    return 0;
  } # if #


  return 0;
} # Method verifySessionLockIntegrity

#----------------------------------------------------------------------------
#
# Method:      startAuto
#
# Description: Start autosave timer
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

  return 1;
} # Method startAuto

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


  my $backup = $self->{backup};
  $backup->{state} = 0;
  $backup->{timer} = $time || 3;

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


  my $backup = $self->{backup};
  $backup->{state} = $state || 2;
  $backup->{timer} = $time  || 1;

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


  my $files = $self->{files};
  my $log = $files->{-log};
  my $backup = $self->{backup};

  # Locked by another session, skip
  return 1
      if ($files->{-lock}->isLocked());

  return 1
      if (--$backup->{timer} > 0);

  my $backupDir = $files->{-cfg}->dirname('bak');

  if (defined($backupDir)) {

    # Backup directory exists, handle it
    if ($backup->{state} == 0) {
      # 0 - Started, first backup check pending
      $self->restartCheckBackup();


    } elsif ($backup->{state} == 2) {
      # 2 - Initate backup verification
      $backup->{state} = 3;
      $backup->{timer} = 1;

      # Check that all backups are up to date
      push @{$backup->{files}}, keys(%{$backup->{file_states}});

      # Check logging on backup
      $log->checkBackup();
      $log->log('Initialize backup OK check');

    } elsif ($backup->{state} == 3) {
      # 3 - Verification ongoing, check one file at timeout
      if (@{$backup->{files}}) {
        # One more file to check, Perform check that backup is OK
        my $file_key = pop(@{$backup->{files}});
        $backup->{file_states}{$file_key} =
             $files->{$file_key}->copyBackup();
        $log->log('Verified backup for', $file_key);
        $backup->{timer} = 1;

      } else {
        # All backups checked: Schedule next check
        $log->log('Backup check done, schedule next check');
        $backup->{state} = 9;
        $backup->{timer} = 10 * $files->{-cfg}->get('save_threshold');

      } # if #

    } elsif ($backup->{state} == 9) {
      # 9 - Timeout after long delay, Restart backup check sequence
      $self->restartCheckBackup();

    } elsif ($backup->{state} < 0) {
      # -1 - Backup was unavailable from start
      # -2 - Backup was lost and came back
      # => Check backup directory

      my $state = $self->checkDirectoryDigest('bak');


      if ($state eq 'OurLock' or
          $state eq 'OurSessionNoLock') {
        # Our lock, initiate new backup cycle
        # Our session, without lock, initiate new backup cycle
        $self->restartCheckBackup();
      } else {
        # Not handled state, Wait a while and try again
        $backup->{state} = -2;
        $backup->{timer} = $files->{-cfg}->get('save_threshold') * 4;
      } # if #

# TODO Here could future improvement add merge, after a confirm

    } else {
      # Unknown backup state, this should not happen
      carp 'WARNING: ', __PACKAGE__,
                     ': Unknown backup state check: ', $backup->{state};
      $log->log('WARNING: ', __PACKAGE__,
                     ': Unknown backup state check: ', $backup->{state});
      $log->log('Restarting backup check');
      $self->restartCheckBackup();

    } # if #

  } else {

    # Backup directory not found

    if ($backup->{state} == 0) {
      # 0 - Started or first backup check pending: Reset timer
      $backup->{timer} = $files->{-cfg}->get('save_threshold');
      $backup->{state} = -1;

    } elsif ($backup->{state} == -1 or
             $backup->{state} == -2) {
      # -1 or -2 - Reset timer and keep waiting
      $backup->{timer} = $files->{-cfg}->get('save_threshold');

    } elsif ($backup->{state} > 0) {
      # >0 - Backup did exist, but was lost, reset backup check
      for my $file_state (values(%{$backup->{file_states}})) {
        $file_state = undef;
      } # for #
      $backup->{state} = -2;
      $backup->{timer} = $files->{-cfg}->get('save_threshold');
      $log->log('Backup directory was lost');

    } else {
      # Unknown backup state, this should not happen
      carp 'WARNING: ', __PACKAGE__,
           ': Unknown backup unavailable state check: ', $backup->{state};
      $log->log('WARNING: ', __PACKAGE__,
           ': Unknown backup unavailable state check: ', $backup->{state});
      $log->log('Restarting backup check');
      $backup->{state} = 0;
      $backup->{timer} = 1;

    } # if #

  } # if #

  return 0;
} # Method autoCheckBackup

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


  my $files = $self->{files};
  my $handle;
  if ($self->{loadHandle}) {
    # Continue calculate digest started by load
    $handle = $self->{loadHandle};
    $self->{loadHandle} = undef;
  } else {
    $handle = TbFile::FileHandleDigest->new();
  } # if #

  # Get values from hash in random order for variation
  while (my ($key, $ref) = each(%{$self->{files}})) {
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
  $self->{files}{-log}->log('New digest value: ', $thisDigest);

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
  #      Archive and log could be large files

  my $files = $self->{files};
  my $lock = $files->{-lock};

  if ($lock->isLocked()) {
    # Locked by another session, make a new attempt in a while
    $self->{erefs}{-clock}->
         timeout(-minute => scalar($self->{files}{-cfg}->get('save_threshold')),
                 -callback => [$self => 'addSessionDigest']);
    return 1;
  } # if #

  unless ($force) {
    # Schedule a new digest in twelve hours, digest to be updated on new date
    # TODO We should not run this more than once every six ours
    #      Do not schedule a timeout if already queued
    $self->{erefs}{-clock}->
         timeout(-minute => 6 * 60,
                 -callback => [$self => 'addSessionDigest']);
  } # unless #

  my $lockDigest = $lock->getDigest();
  my $thisDate = $self->{erefs}{-clock}->getDate();
  my ($lastDigest, $lastDate) = $files->{-session}->getDigest(0);

  if ($lockDigest) {
    # Lock digest is set
    if ($lastDate and $thisDate le $lastDate) {
      $files->{-log}->log('Session digest already saved today');
      return 0;
    } # if #

  } # if #

  my $thisDigest = $self->_calculateDigest();

  $lock->setDigest($thisDigest)
      unless($lockDigest);
  $files->{-session}->addDigest($thisDigest, $thisDate);
  $files->{-log}->log('Added todays session digest');

  return 0;
} # Method addSessionDigest

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

  my $files = $self->{files};

  # Copy all files except log
  $files->{-log}->log('Replace backup from this instance');
  for my $k (@{$self->{order}}, @{$self->{extra}}) {
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

  my $files = $self->{files};
  $files->{-log}->log('Merge backup data');

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
#   Plugin.pmx , size      TODO
  } # for #
  for my $k (qw(-event_cfg -times -archive)) {
    $progress_ref->{$k}->{-percent_part} =
          int(94 * $progress_ref->{$k}->{sum} / $progress_sum) || 1;
#   Plugin.pmx , size      TODO
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
  $files->{-log}->log('Added todays session digest after merge data',
                      $thisDigest);

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

  my $files = $self->{files};

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
  $files->{-log}->log(
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

1;
__END__
