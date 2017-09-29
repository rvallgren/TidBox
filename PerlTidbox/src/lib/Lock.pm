#
package Lock;
#
#   Document: Lockfile handler
#   Version:  1.1   Created: 2017-08-25 16:58
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Lock.pmx
#

my $VERSION = '1.1';
my $DATEVER = '2017-08-25';

# History information:
#
# 1.0  2012-04-24  Roland Vallgren
#      First issue.
# 1.1  2015-10-08  Roland Vallgren
#      Minor correction.
#      Log grab lock
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base FileBase;

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
              locked  => undef,        # Reference to lock by other session
              session => undef,        # Reference to lock by this session
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
      if ($self->{session});

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
#    Överrid låset, enbart läsning
    return 1;
  } # if #

  # Set lock
  my $user = getlogin || getpwuid($<) || "Okänd tidbox användare";
  $self->{session} = {
                      locked => 'Tidbox är låst',
                      user   => $user,
                      date   => $date,
                      time   => $time,
                     };

  $self->dirty();
  $self->save();

  # Start logging after unlock

  if ($lock_grabbed and $self->{-log}) {
    $self->{-log}->start();
    $self->{-log}->
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
  $self->{-log}->log('Unlock session');
  $self->remove();
  return 0;
} # Method unlock

#----------------------------------------------------------------------------
#
# Method:      isLocked
#
# Description: Check if lock is set
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
           "\n  Användare:" . $self->{locked}{user}.
           "\n  Datum:" . $self->{locked}{date} .
           "\n  Tid:" . $self->{locked}{time}
         :
           undef
         ;
} # Method get

1;
__END__
