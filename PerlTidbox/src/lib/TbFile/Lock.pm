#
package TbFile::Lock;
#
#   Document: Lockfile handler
#   Version:  1.2   Created: 2018-09-13 17:56
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Lock.pmx
#

my $VERSION = '1.2';
my $DATEVER = '2018-09-13';

# History information:
#
# 1.2  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      References to other objects in own hash
#      Added handling of lock digest to allow check of lock integrity
# 1.1  2015-10-08  Roland Vallgren
#      Minor correction.
#      Log grab lock
# 1.0  2012-04-24  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base TbFile::Base;

use strict;
use warnings;
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

use constant FILENAME  => 'lock.dat';
use constant FILEKEY   => 'LOCK SESSION';


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
# Description: Create object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = {
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  # Set default values
  $self->_clear();

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear log
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  $self->{locked}  = undef;
  $self->{session} = undef;

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load lock by other session into locked
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

  $self->loadDatedSets($fh, 'locked');

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save lock for this session in lockfile
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


  $self->saveDatedSets($fh, 'session');

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      lock
#
# Description: Set session lock and save to lockfile
#
# Arguments:
#  - Object reference
#  - date
#  - time
# Optional Arguments:
#  - grab the lock
# Returns:
#  -

sub lock($$$;$) {
  # parameters
  my $self = shift;
  my ($date, $time, $grab) = @_;

  # We have the lock already
  return 1
      if (ref($self->{session}));

  # Grab the lock if requested
  my $lock_grabbed;
  if (exists($self->{locked}) and $grab) {
    $lock_grabbed = $self->{locked};
    $self->{locked} = undef;
  } # if #


  # Check if lock is set
  if ($self->isLocked()) {    
#    info printout
#    'En annan session av tidbox startades',
#    $self->{locked}{user},
#    $self->{locked}{date},
#    $self->{locked}{time},
#    Override the lock, read only mode
    return 1;
  } # if #

  # Set lock
  my $user = getlogin || getpwuid($<) || "Okänd tidbox användare";
  $self->{session} = {
                      locked    => 'Tidbox är låst',
                      user      => $user,
                      date      => $date,
                      time      => $time,
                      systime   => time(),
                      processId => $$,
                     };

  $self->{erefs}{-log}->log('Lock session');

  $self->save(1);

  # Start logging after unlock grabbed lock

  if ($lock_grabbed and $self->{erefs}{-log}) {
    $self->{erefs}{-log}->start();
    $self->{erefs}{-log}->
      log('------ Grabbed lock from user:', $lock_grabbed->{user},
          'Locked at:', $lock_grabbed->{date}, $lock_grabbed->{time},
          '------'
         );
  } # if #

  return 0;
} # Method lock

#----------------------------------------------------------------------------
#
# Method:      unlock
#
# Description: Remove session lock if we have it
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub unlock($) {
  # parameters
  my $self = shift;

  return 1
      unless (ref($self->{session}));
  $self->{session} = undef;
  $self->{erefs}{-log}->log('Unlock session');
  $self->remove();
  return 0;
} # Method unlock

#----------------------------------------------------------------------------
#
# Method:      isLocked
#
# Description: Check if lock is set by another session
#
# Arguments:
#  0 - Object reference
# Returns:
#  True if lock is set

sub isLocked($) {
  # parameters
  my $self = shift;

  return ref($self->{locked});
} # Method isLocked

#----------------------------------------------------------------------------
#
# Method:      get
#
# Description: Return lock information about other session lock
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub get($) {
  # parameters
  my $self = shift;

  return $self->isLocked() ?
           $self->{locked}{locked} .
           "\n  Användare:" . $self->{locked}{user}     .
           "\n  Datum:"     . $self->{locked}{date}     .
           "\n  Tid:"       . $self->{locked}{time}     .
           "\n  SystemTid:" . $self->{locked}{systime}  .
           "\n  ProcessId:" . $self->{locked}{processId}
         :
           undef
         ;
} # Method get

#----------------------------------------------------------------------------
#
# Method:      getLockData
#
# Description: Return lock information about this session lock
#
# Arguments:
#  - Object reference
# Returns:
#  Lock hash data
#  

sub getLockData($) {
  # parameters
  my $self = shift;

  return %{$self->{session}}
      if (ref($self->{session}));

  return %{$self->{locked}}
      if (ref($self->{locked}));

  return undef
} # Method getLockData

#----------------------------------------------------------------------------
#
# Method:      getDigest
#
# Description: Get digest for lock, if set
#              Digest is get from lock for this session or
#              from loaded lock file
#
# Arguments:
#  - Object reference
# Returns:
#  Digest
#  undef - No lock or no digest

sub getDigest($) {
  # parameters
  my $self = shift;

  return $self->{session}{digest}
      if (ref($self->{session}));

  return $self->{locked}{digest}
      if (ref($self->{locked}));

  return undef
} # Method getDigest

#----------------------------------------------------------------------------
#
# Method:      setDigest
#
# Description: Set digest for lock
#
# Arguments:
#  - Object reference
#  - Digest
# Returns:
#  - 0
#  undef - Session is not locked

sub setDigest($$$) {
  # parameters
  my $self = shift;
  my ($digest) = @_;


  return undef
      unless (ref($self->{session}));

  $self->{session}{digest} = $digest;
  $self->{erefs}{-log}->log('Added lock digest:', $digest);
  $self->dirty();
  $self->save();

  return 0;
} # Method setDigest

#----------------------------------------------------------------------------
#
# Method:      checkLockDigest
#
# Description: Check if lock in specified directory is ours
#
# Arguments:
#  - Object reference
#  - Directory: 'dir', 'bak', path to directory
# Returns:
#  'OurLock'              The lock is from our session
#  'LockedByOther'        Lock is not our session
#  'NoLock'               No lock detected in directory
#  'NoDigestInOtherLock'  No digest found in lock file
#  'NoDigestInOur'        Our session have no digest

sub checkLockDigest($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;


  # We have no digest in our lock
  my $ourDigest = $self->getDigest();
  unless ($ourDigest) {
    $self->{erefs}{-log}->trace('No digest in our lock, yet?');
    return 'NoDigestInOur';
  } # unless #

  # Try to load other lock
  my $found_lock = $self->loadOther($dir);

  # No lock file in other
  unless ($found_lock) {
    $self->{erefs}{-log}->trace('No lock file in directory');
    return 'NoLock';
  } # unless #

  # Get digest from other lock
  my $foundDigest = $found_lock->getDigest();
  unless ($foundDigest) {
    $self->{erefs}{-log}->trace('No digest in other lock, yet?',
                                join('::', $found_lock->getLockData()));
    return 'NoDigestInOtherLock';
  } # unless #

  # The lock is from our session
  if ($ourDigest eq $foundDigest) {
    $self->{erefs}{-log}->log('Our lock, digests equal');
    return 'OurLock';
  } # if #

  $self->{erefs}{-log}->log('Not our lock Our:', $ourDigest,
                            'Digest found in', $dir, ':', $foundDigest);
  return 'LockedByOther';
} # Method checkLockDigest

1;
__END__
