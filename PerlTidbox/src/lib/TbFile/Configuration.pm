#
package TbFile::Configuration;
#
#   Document: Configuration class
#   Version:  2.9   Created: 2019-02-19 17:41
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Configuration.pmx
#

my $VERSION = '2.9';
my $DATEVER = '2019-02-19';

# History information:
#
# 1.0  2007-10-21  Roland Vallgren
#      First issue.
# 1.1  2008-09-13  Roland Vallgren
#      Command options "-config" and "-backup" removed
# 2.0  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Use FileBase functions to save and load
#      Terp week worktime added as default
# 2.1  2009-07-14  Roland Vallgren
#      Default timeout for status messages is 5 minutes
# 2.2  2011-03-16  Roland Vallgren
#      Session data moved to session.dat
# 2.3  2012-05-09  Roland Vallgren
#      not_set_start => start_operation :  none, workday, event, end pause
# 2.4  2012-09-09  Roland Vallgren
#      main_show_daylist default on
# 2.5  2013-03-27  Roland Vallgren
#      Added support for lock of session
# 2.6  2015-09-23  Roland Vallgren
#      Added resume operation and time
#      Configuration.pm should not have any Gui code
# 2.7  2017-09-18  Roland Vallgren
#      Setting terp_normal_worktime renamed to ordinary_week_work_time
# 2.8  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      Do not default H:/.tidbox as backup directory in Windows
#      References to other objects in own hash
#      Improved handling of backup directory
#      New settings to control trace enabled
# 2.9  2019-01-25  Roland Vallgren
#      Corrected comment
#      Added update setting: check_new_version
#      Removed log->trace
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

use File::Path qw();
use File::Spec;

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

use constant BACKUP_ENA => $^O . '_do_backup';
use constant BACKUP_DIR => $^O . '_backup_directory';

#----------------------------------------------------------------------------
#
# Initial configuration data settings
#
#  key                value
#  last_version       Version of Tidbox, to detect new version
#  start_operation    How to register start of tidbox
#                       0:  No action
#                       1:  Register Start workday, if it is the first today
#                       2:  Register Start Event
#                       3:  Register End Pause
#                       4:  Register Start Event selected by user
#  resume_operation   How to register resume of tidbox
#                       0:  No action
#                       1:  Register Start workday, if it is the first today
#                       2:  Register Start Event
#                       3:  Register End Pause
#                       4:  Register Start Event selected by user
#  resume_operation_time  Time to sleep before resume is registered
#  show_data          Set what to show in status area
#                       0:  Show ongoing activity            (Default)
#                       1:  Show worktime for current day
#                       2:  Show worktime for current week
#                       3:  Show time for current activity
#  earlier_menu_size  Size of the earlier menu, zero disables menu
#                       Default is 14 entries
#  show_reg_date      Show date in show_registered
#  archive_date       All dates up to this date is archived,
#                     that is write locked
#  lock_date          Time data up to this date is write locked
#  save_threshold     Save file isn't saved more than this number of minutes
#                       Default is 5 minutes
#  adjust_level       Level to adjust events to
#                       Default 0,1 hours represented as 6 minutes
#  ordinary_week_work_time  Ordinary week worktime, used for Week hints
#                           Default is 40 hours a week
#  show_message_timeout  Timeout for status messages in main window
#                          Default is 5 minutes
#  main_show_daylist  Daylist is default on
#  log_trace_enabled  Enable trace in log, for test, Default is off
#  check_new_version  Control how Update should behave
#                            0: Look for and download updates
#                            6: No search for updates
#

my %DEFAULTS = (
    last_version          => '',
    start_operation       => 0,
    resume_operation      => 0,
    resume_operation_time => 60,
    show_data             => 0,
    earlier_menu_size     => 14,
    show_reg_date         => 1,
    archive_date          => NO_DATE,
    lock_date             => NO_DATE,
    save_threshold        => 5,
    adjust_level          => 6,
    ordinary_week_work_time  => 40,
    show_message_timeout  => 5,
    main_show_daylist     => 1,
    log_trace_enabled     => 0,          # TODO Add trace for debugging
    check_new_version     => 0,
   );


use constant FILENAME  => 'config.dat';
use constant FILEKEY   => 'PROGRAM SETTINGS';

use constant TIDBOX_RCDIR_UNIX    => '.tidbox';
use constant TIDBOX_RCDIR_WINDOWS => 'Tidbox';


#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create configuration object
#
# Arguments:
#  - Object prototype
#  - Reference to arguments hash
# Returns:
#  Object reference

sub new($$%) {
  my $class = shift;
  $class = ref($class) || $class;
  my $args = shift;

  my $self = {
             };

  if (exists($args->{directory})) {
    $self->{dir} = $args->{directory};
  } elsif ($^O eq 'MSWin32') {
    # Find out Windows "Tidbox" application data directory to use
    if ($ENV{APPDATA} and -d $ENV{APPDATA}) {

      $self->{dir} =
        File::Spec->catfile(
                            $ENV{APPDATA},
                            TIDBOX_RCDIR_WINDOWS
                           );
    } else {

      croak "No home directory detected"
          unless ($ENV{HOMEDRIVE} and -d $ENV{HOMEDRIVE});

      $self->{dir} =
        File::Spec->catfile(
                            $ENV{HOMEDRIVE},
                            TIDBOX_RCDIR_UNIX
                           );
    } # if #

  } else {
    # Find out non Windows directories to use, probably Unix likes

    croak "No home directory detected"
        unless ($ENV{HOME} and -d $ENV{HOME});

      $self->{dir} =
        File::Spec->catfile(
                            $ENV{HOME},
                            TIDBOX_RCDIR_UNIX
                           );

  } # if #

# TODO Use File::Spec->splitpath for this?
#    ($volume,$directories,$file) = File::Spec->splitpath( $path );
#    ($volume,$directories,$file) = File::Spec->splitpath( $path, $no_file );
  if (($^O eq 'MSWin32') and
      ($self->{dir} =~ /^(\w+:)/)
     ) {
    $self->{dir_MSwin_drive} = $1;
  } # if #

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  # Set default values
  $self->_clear();

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      dirname
#
# Description: Get full path to directory to store data in
#
# Arguments:
#  0 - Object reference
#  1 - Type: 'dir' or 'bak'
# Returns:
#  Full path if available
#  undef otherwise

sub dirname($$) {
  # parameters
  my $self = shift;
  my ($typ) = @_;


  return undef
      unless ($self->{$typ});

  # Check if the drive exists on Windows, improves performance
  my $d = $typ . '_MSwin_drive';
  if ($self->{$d}) {
    unless (-d $self->{$d}) {
      $self->{erefs}{-log}->
          log('Windows drive', $self->{$d}, 'not accessible');
      return undef;
    } # unless #
  } # if #

  unless (-d $self->{$typ}) {
    eval { File::Path->make_path($self->{$typ}, { mode => 0700 }) };
    if ($@) {
      $self->{erefs}{-log}->log('Create failed', $@);
      return undef
    } # if #
    $self->{erefs}{-log}->
            log('Created type', $typ, 'directory', $self->{$typ});
  } # unless #

  return $self->{$typ};
} # Method dirname

#----------------------------------------------------------------------------
#
# Method:      filename
#
# Description: Get full path to directory to store data in
#              If a file name is provided the path and filname is returned
#
# Arguments:
#  0 - Object reference
#  1 - Type: 'dir' or 'bak'
# Optional Arguments:
#  2 - File name
# Returns:
#  Full path if available
#  undef otherwise

sub filename($$;$) {
  # parameters
  my $self = shift;
  my ($typ, $name) = @_;


  my $dirname = $self->dirname($typ);
  return undef
      unless ($dirname);

  return File::Spec->catfile($dirname, $name)
      if ($name);

  return $dirname;
} # Method filename

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear configuration, set to default values
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  %{$self->{cfg}} = %DEFAULTS;

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load configuration data from file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
# Returns:
#  1 if success

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->loadDatedSets($fh, 'cfg');

  if ($self->get(BACKUP_ENA)) {
    $self->{bak} = $self->get(BACKUP_DIR);
    croak "$^O backup defined, but no directory defined\n"
        unless (defined($self->{bak}));
    if (($^O eq 'MSWin32') and ($self->{bak} =~ /^(\w+:)/)) {
      $self->{bak_MSwin_drive} = $1;
    } # if #
  } else {
    $self->{bak} = undef;
    $self->{bak_MSwin_drive} = undef;
  } # if #

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: _save configuration data to file
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


  $self->saveDatedSets($fh, 'cfg');

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      get
#
# Description: Get a setting or all if no key is given
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  List of settings
# Returns:
#  Value of setting or hash

sub get($@) {
  # parameters
  my $self = shift;


  return $self->{cfg}{shift()}
      unless wantarray();

  return %{$self->{cfg}}
      unless @_;

  my $cfg = $self->{cfg};
  my %copy;
  for my $k (@_) {
    $copy{$k} = $cfg->{$k};
  } # for #
  return %copy;
} # Method get

#----------------------------------------------------------------------------
#
# Method:      Exists
#
# Description: Return true if a setting exists
#
# Arguments:
#  - Object reference
#  - Setting name to check
# Returns:
#  true if setting exists

sub Exists($@) {
  # parameters
  my $self = shift;
  my ($key) = @_;


  return exists($self->{cfg}{$key});
} # Method Exists

#----------------------------------------------------------------------------
#
# Method:      set
#
# Description: Set a configuration settings
#
# Arguments:
#  0 - Object reference
#  Hash with settings to set
# Returns:
#  -

sub set($%) {
  # parameters
  my $self = shift;
  my (%hash) = @_;

  while (my ($key, $val) = each(%hash)) {
    $self->{cfg}{$key} = $val;
  } # while #
  $self->dirty();
  if ($self->{cfg}{BACKUP_ENA()}) {
    $self->{bak} = $self->{cfg}{BACKUP_DIR()};
    if (($^O eq 'MSWin32') and ($self->{bak} =~ /^(\w+:)/)) {
      $self->{bak_MSwin_drive} = $1;
    } # if #
  } else {
    $self->{bak} = undef;
    $self->{bak_MSwin_drive} = undef;
  } # if #

  return 0;
} # Method set

#----------------------------------------------------------------------------
#
# Method:      delete
#
# Description: Delete configuration settings
#
# Arguments:
#  0 - Object reference
#  1 .. n  Keys for settings to delete
# Returns:
#  -

sub delete($@) {
  # parameters
  my $self = shift;

  for my $k (@_) {
    delete($self->{cfg}{$k});
  } # for #
  $self->dirty();
  return 0;
} # Method delete

#----------------------------------------------------------------------------
#
# Method:      replace
#
# Description: Replace configuration data for merge of Tidbox data
#              Do not replace directory paths
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub replace($$) {
  # parameters
  my $self = shift;


  my $other = $self->loadOther('bak');

  return 0
      unless ($other);

  # Copy all data from other session
  my %copy = $other->get();

  # Keep backup settings
  while (my ($key, $val) = each(%copy)) {
    next
        if (substr($key, -10) eq '_do_backup' or
            substr($key, -17) eq '_backup_directory');
    $self->set($key, $val);
  } # while #
  $self->{erefs}{-log}->
            log('All configuration data not related to backup is replaced.');

  $self->save();
  return 0;
} # Method replace

#----------------------------------------------------------------------------
#
# Method:      _mergeData
#
# Description: Merge configuration data
#              No data in this session is updated
#              TODO Is this as we want
#
# Arguments:
#  - Object reference
#  - Source object to merge from
#  - Start Date
#  - End Date
# Returns:
#  -

sub _mergeData($$$$) {
  # parameters
  my $self = shift;
  my ($source, $startDate, $endDate) = @_;


  $self->{erefs}{-log}->
            log('No configuration data merged.');

  return 0;
} # Method _mergeData

#----------------------------------------------------------------------------
#
# Method:      lock
#
# Description: Try to lock session
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub lock($@) {
  # parameters
  my $self = shift;

  return $self->{erefs}{-lock}->lock(@_);
} # Method lock

#----------------------------------------------------------------------------
#
# Method:      isSessionLocked
#
# Description: Check if session is locked by another running session
#
# Arguments:
#  - Object reference
# Returns:
#  0 no lock applies
#  1 if session is locked
#  Also returns lock information if wantarray()

sub isSessionLocked($) {
  # parameters
  my $self = shift;

  my $s = 0;
  my $t = '';
  if ($self->{erefs}{-lock}->isLocked()) {
    $s = 1;
    $t = 'Tidbox är låst';
  } # if #

  return ($s, $t)
      if (wantarray());
  return $s;
} # Method isSessionLocked

#----------------------------------------------------------------------------
#
# Method:      isLocked
#
# Description: Check if this will change a locked date
#              Confirm if locked, else allow change
#
# Arguments:
#  - Object reference
#  - Date to check
# Returns:
#  0 no lock applies
#  1 if the date is locked
#  2 if session is locked
#  Also returns lock information if wantarray()
#

sub isLocked($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  my ($s, $t) = $self->isSessionLocked();
  my $l = $self->{cfg}{lock_date};

  if ($s) {
    $s = 2;
  } elsif ($date le $l) {
    $s = 1;
    $t = 'Veckan är låst!';
  } # if #

  return ($s, $t, $l)
      if (wantarray());

  return $s;
} # Method isLocked

#----------------------------------------------------------------------------
#
# Method:      isBackupEnabled
#
# Description: Return true if backup is enabled
#
# Arguments:
#  - Object reference
# Returns:
#  True Backup is enabeled
#

sub isBackupEnabled($) {
  # parameters
  my $self = shift;

  return $self->get(BACKUP_ENA());
} # Method isBackupEnabled

#----------------------------------------------------------------------------
#
# Method:      impacted
#
# Description: Add reference to object impacted by change of backup policy
#
# Arguments:
#  - Object reference
#  - Reference to impacted object
# Returns:
#  -

sub impacted($$) {
  # parameters
  my $self = shift;

  push @{$self->{impacted}}, @_;
  return 0;
} # Method impacted

#----------------------------------------------------------------------------
#
# Method:      bakInit
#
# Description: Set backupdir after change of backup, set dirty if enabled
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub bakInit($) {
  # parameters
  my $self = shift;

  if ($self->get(BACKUP_ENA())) {
    $self->{bak} = $self->get(BACKUP_DIR());
    if (($^O eq 'MSWin32') and ($self->{bak} =~ /^(\w+:)/)) {
      $self->{bak_MSwin_drive} = $1;
    } # if #
    for my $r (@{$self->{impacted}}) {
      $r->dirty(undef, 'bak');
    } # for #
  } else {
    $self->{bak} = undef;
    $self->{bak_MSwin_drive} = undef;
    for my $r (@{$self->{impacted}}) {
      $r->dirty(1, 'bak');
    } # for #
  } # if #

  return 0;
} # Method bakInit

1;
__END__
