#
package TbFile;
#
#   Document: Handle all files
#   Version:  2.7   Created: 2026-02-01 19:20
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: TbFile.pmx
#

my $VERSION = '2.7';
my $DATEVER = '2026-02-01';

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
# 2.6  2019-03-14  Roland Vallgren
#      Moved backup handling and supervision to TbFile::Backup
# 2.7  2024-08-29  Roland Vallgren
#      Added schedule file
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
use TbFile::Schedule;
use TbFile::Plugin;
use TbFile::Archive;
use TbFile::Backup;

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
               qw(-cfg -lock -session -event_cfg -supervision
                  -schedule -plugin -times)
              ];
  my $load = [
               qw(-event_cfg -supervision -schedule -plugin -times)
              ];
  my $extra = [ qw(-archive) ];

  my $files = {
                -lock        => TbFile::Lock->new(),

                -log         => TbFile::Log->new(),

                -cfg         => TbFile::Configuration->new($args),

                -session     => TbFile::Session->new($args),

                -event_cfg   => TbFile::EventCfg->new(),

                -supervision => TbFile::Supervision->new(),

                -times       => TbFile::Times->new(),

                -plugin      => TbFile::Plugin->new(),

                -archive     => TbFile::Archive->new(),

                -schedule    => TbFile::Schedule->new(),

              };

  my $self = {
              order  => $order,
              load   => $load ,
              extra  => $extra,
              files  => $files,
              backup => TbFile::Backup->new(),
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

  $files->{-cfg}->
      configure(
                -cfg         => $files->{-cfg},
                -lock        => $files->{-lock},
                -event_cfg   => $files->{-event_cfg},
                -log         => $files->{-log},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-event_cfg}->
      configure(
                -cfg         => $files->{-cfg},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-log}->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-lock}->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-session}->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-times}->
      configure(
                -cfg         => $files->{-cfg},
                -event_cfg   => $files->{-event_cfg},
                -session     => $files->{-session},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-supervision}->
      configure(
                -cfg         => $files->{-cfg},
                -times       => $files->{-times},
                -log         => $files->{-log},
                -event_cfg   => $files->{-event_cfg},
                -clock       => $args{-clock},
                -calculate   => $args{-calculate},
                -error_popup => $args{-error_popup},
               );

  $files->{-plugin}->
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

  $files->{-archive}->
      configure(
                -cfg         => $files->{-cfg},
                -log         => $files->{-log},
                -times       => $files->{-times},
                -event_cfg   => $files->{-event_cfg},
                -schedule    => $files->{-schedule},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $files->{-schedule}->
      configure(
                -cfg         => $files->{-cfg},
                -log         => $files->{-log},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  $self->{backup}->
      configure(
                -cfg         => $files->{-cfg},
                -log         => $files->{-log},
                -lock        => $files->{-lock},
                -session     => $files->{-session},
                -clock       => $args{-clock},
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
    my $sessionState = $self->{backup}->checkSessionDigest('bak');

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
  # TODO No check is made if load failed: for example wrong file format
  for my $k (@{$self->{load}}) {
    $files->{$k}->load('dir', $handle);
  } # for #

  # Hand over load handle to backup for digest calculation
  $self->{backup}->setLoadHandle($handle);

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
    $self->{backup}->addFileToCheck($k, $files->{$k});
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
  return $self->{$name}
      if (exists($self->{$name}));
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
  $self->{backup}->startAuto();

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
  $self->{backup}->end($message);

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

  my $lockState = $self->{backup}->checkLockDigest('dir');

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

1;
__END__
