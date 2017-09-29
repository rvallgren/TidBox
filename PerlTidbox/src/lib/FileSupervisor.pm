#
package FileSupervisor;
#
#   Document: Handle all files
#   Version:  2.3   Created: 2017-09-25 12:07
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: FileSupervisor.pmx
#

my $VERSION = '2.3';
my $DATEVER = '2017-09-25';

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
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use integer;

use Version qw(register_starttime);

use Log;
use Lock;
use Configuration;
use Session;
use Times;
use EventCfg;
use Supervision;
use Plugin;
use Archive;

# Register version information
{
  use Version qw(register_version);
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

  my $order = [ qw(-lock -cfg -session -event_cfg -supervision -plugin -times) ];
  my $extra = [ qw(-archive) ];

  my $files = {
              -lock        => new Lock(),

              -log         => new Log(),

              -cfg         => new Configuration($args),

              -session     => new Session($args),

              -event_cfg   => new EventCfg(),

              -supervision => new Supervision(),

              -times       => new Times(),

              -plugin      => new Plugin(),

              -archive     => new Archive(),

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
                -log         => $files->{-log},
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
# Description: Load files
#
# Arguments:
#  - Object reference
#  - Date
#  - Time
#  - Version
# Returns:
#  -

sub load($$$$) {
  # parameters
  my $self = shift;
  my ($date, $time, $version) = @_;

  my $files = $self->{files};

  # Read old data for configuration and times, do not read archive
  for my $k (@{$self->{order}}) {
    $files->{$k}->load();
  } # for #

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
  $files->{-lock}->lock($date, $time);

  # Start auto saving for files and register impacted
  for my $k (@{$self->{order}}, @{$self->{extra}}) {
    $files->{$k}->startAuto();
    $files->{-cfg}->impacted($files->{$k});
    $self->{backup}{file_states}{$k} = undef;
  } # for #

  return 0;
} # Method load

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
  Version->register_starttime($date, $time);

  $files->{-session}->start($date, $time);

  $files->{-times}->startSession($date, $time);

  Version->register_locked_session($files->{-lock}->get());


  # Setup supervision
  $files->{-supervision}->setup();

  # Start supervision of backup directory
  $self->startAuto();


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
  my $backup = $self->{backup};
  $backup->{state} = 0;
  $backup->{timer} = 3;
  $self->{-clock}->repeat(-minute => [$self => 'autoCheckBackup']);

  return 1;
} # Method startAuto

#----------------------------------------------------------------------------
#
# Method:      autoCheckBackup
#
# Description: Check if backup directory is in place and make
#              sure the backup is up to date
#              Backup state:
#                0 - Started, backup check pending
#                1 - Timer running, wait for timeout
#               -1 - Backup not found or not active
#                2 - Backup detected, start verification sequence
#                3 - Verify backup
#                9 - Backup OK
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - if success

sub autoCheckBackup($) {
  # parameters
  my $self = shift;


  my $files = $self->{files};
  my $backup = $self->{backup};

  return 1
      if ($files->{-lock}->isLocked());

  return 1
      if (--$backup->{timer} > 0);

  my $backupDir = $files->{-cfg}->filename('bak');

  if (defined($backupDir)) {

    # Backup directory exists, handle it
    if ($backup->{state} <= 1) {
      # Started or not existing before
      # Initialize backup check
      $backup->{timer} = 1;
      $backup->{state} = 2;

      # Check that all backups are up to date
      @{$backup->{files}} = keys(%{$backup->{file_states}});

      # Check logging on backup
      $files->{-log}->checkBackup();
      $files->{-log}->log('Initialize backup OK check');

    } elsif ($backup->{state} == 2) {
      if (@{$backup->{files}}) {
        # Perform check that backup is OK
        my $file_key = pop(@{$backup->{files}});
        $backup->{file_states}{$file_key} = 
             $files->{$file_key}->copyBackup();
        $files->{-log}->log('Verified backup for', $file_key);
        $backup->{timer} = 1;

      } else {
        # All backups checked: Schedule next check
        $files->{-log}->log('Backup check done, schedule next check');
        $backup->{state} = 9;
        $backup->{timer} = 10 * $files->{-cfg}->get('save_threshold');
      } # if #

    } elsif ($backup->{state} == 9) {
      # Restart backup check sequence
      $backup->{state} = 0;
      $backup->{timer} = 1;

    } # if #

  } else {

    # Backup directory not found

    if ($backup->{state} <= 0) {
      # Started or backup check pending: Reset timer
      $backup->{timer} = $files->{-cfg}->get('save_threshold');

    } else {
      # Backup did exist, but was lost, reset backup check
      for my $file_state (values(%{$backup->{file_states}})) {
        $file_state = undef;
      } # for #
      $backup->{state} = -1;
      $files->{-log}->log('Backup directory was lost');
    } # if #
  } # if #

  return 0;
} # Method autoCheckBackup

1;
__END__
