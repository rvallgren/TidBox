#
package TbFile::Session;
#
#   Document: Session class
#   Version:  1.2   Created: 2019-02-07 15:09
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Session.pmx
#

my $VERSION = '1.2';
my $DATEVER = '2019-02-07';

# History information:
#
# 1.2  2019-02-07  Roland Vallgren
#      Removed log->trace
# 1.1  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      References to other objects in own hash
#      Added merge with new backup data
#      Added session digest to supervise file integrity
# 1.0  2011-03-16  Roland Vallgren
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


use constant FILENAME  => 'session.dat';
use constant FILEKEY   => 'SAVED SESSION DATA';

#----------------------------------------------------------------------------
#
# Initial configuration data settings
#
#  key                   value
#  last_version          Version of Tidbox, to detect new version
#  start_time            Date and time when started
#  last_start_time       Date and time when started last time
#  last_end_time         Date and time when ended last time
#  this_session          Number of minutes this session has been up
#  last_session          Number of minutes of last session
#  accumulated_sessions  Accumulated number of minutes for previous session
#                        and all before, since the feature was introduced
#  <win>_pos             Last position of window
#  Fileowner?            ?  TODO ?
#  session_digest_no_<x>_value  Hex hash value for session digest no <x>
#  session_digest_no_<x>_date   Date when session digest no <x> was created
#                           

my %DEFAULTS = (
     accumulated_sessions => 0,
   );

# Maximum number of digests saved for the session
# TODO Fyra som ett test att resten tas bort
use constant MAX_DIGESTS   => 10;


#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create session object
#
# Arguments:
#  - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

# Should be
# $self = $class->SUPER::new();

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
# Description: Clear session data, set default values
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  %{$self->{data}} = %DEFAULTS;

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load session data from file
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


  $self->loadDatedSets($fh, 'data');

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: _save supervision data to file
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


  $self->saveDatedSets($fh, 'data');

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      _upd
#
# Description: Get a setting, move from configuration if not found
#
# Arguments:
#  - Object reference
#  - Setting
# Returns:
#  Value of setting

sub _upd($$) {
  # parameters
  my $self = shift;
  my $key = shift();


  return $self->{data}{$key}
      if (exists($self->{data}{$key}));
  my $val = $self->{erefs}{-cfg}->get($key);
  if (defined($val)) {
    $self->{erefs}{-cfg}->delete($key);
    $self->{data}{$key} = $val;
  } # if #
  return $val;
} # Method _upd

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


  return $self->_upd(shift())
      unless wantarray();

  return %{$self->{data}}
      unless @_;

  my %copy;
  for my $k (@_) {
    $copy{$k} = $self->_upd($k);
  } # for #
  return %copy;
} # Method get

#----------------------------------------------------------------------------
#
# Method:      set
#
# Description: Set session settings
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
    $self->{erefs}{-cfg}->delete($key)
        if ($self->{erefs}{-cfg}->get($key));
    $self->{data}{$key} = $val;
  } # while #
  $self->dirty();

  return 0;
} # Method set

#----------------------------------------------------------------------------
#
# Method:      delete
#
# Description: Delete session settings
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
    delete($self->{data}{$k});
  } # for #
  $self->dirty();
  return 0;
} # Method delete

#----------------------------------------------------------------------------
#
# Method:      replace
#
# Description: Replace session data with data from directory.
#              Session is never completely replaced.
#              If session is our own instance then
#              Add accumulated session time, if not our instance
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub replace($) {
  # parameters
  my $self = shift;


  my $other = $self->loadOther('bak');

  return 0
      unless ($other);

  # Copy all data from other session
  my %copy = $other->get();

  for my $key (qw(this_session last_session start_time)) {
    $copy{$key} = $self->get($key);
  } # for #

  if ($self->checkSessionHistory($other) == 0) {

    # Other session is another instance
    # Accumulate both instances

    $copy{accumulated_sessions} = $self->get('accumulated_sessions') +
                                  $other->get('accumulated_sessions') +
                                  $other->get('this_session');

  } # if #


  $self->set(%copy);
  return 0;
} # Method replace

#----------------------------------------------------------------------------
#
# Method:      _mergeData
#
# Description: Merge session data
#              Accumulated both instances session times
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


  if ($self->checkSessionHistory($source) == 0) {

    # Other session is another instance
    # Accumulate both instances
    $self->set('accumulated_sessions', $self->get('accumulated_sessions') +
                                       $source->get('accumulated_sessions') +
                                       $source->get('this_session')
              );

  } # if #

  return 0;
} # Method _mergeData

#----------------------------------------------------------------------------
#
# Method:      start
#
# Description: Add start of workday, if not started yet
#              Add uptime from previous session to accumulated uptime
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub start($$$) {
  # parameters
  my $self = shift;
  my ($date, $time) = @_;


  if (my $tmp = $self->get('this_session')) {
    my $total = $self->get('accumulated_sessions');
    $self->set('accumulated_sessions', $total ? $total + $tmp : $tmp);

    $self->set('last_session', $tmp);

    $tmp = $self->get('start_time');
    $self->set('last_start_time', $tmp);
    $tmp = $self->get('end_time');
    $self->set('last_end_time', $tmp);
  } # if #

  $self->set('start_time', $date . ',' . $time);
  $self->set('this_session', 1);

  $self->save();

  return 0;
} # Method start

#----------------------------------------------------------------------------
#
# Method:      startAuto
#
# Description: Start autosave timer and session counter
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub startAuto($) {
  # parameters
  my $self = shift;


  $self->SUPER::startAuto();
  $self->{erefs}{-clock}->repeat(-minute => [$self => 'minute']);

  return 1;
} # Method startAuto

#----------------------------------------------------------------------------
#
# Method:      minute
#
# Description: Count time in this session
#              Called once a minute
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub minute($) {
  # parameters
  my $self = shift;

  $self->{data}{this_session}++;
  if (not $self->{save_threshold}) {
    $self->dirty();
    $self->{save_threshold} = $self->{erefs}{-cfg}->get('save_threshold') + 1;
  } else {
    $self->{save_threshold}--;
  } # if #

} # Method minute

#----------------------------------------------------------------------------
#
# Method:      end
#
# Description: End session
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub end($) {
  # parameters
  my $self = shift;


  my $time = $self->{erefs}{-clock}->getTime();
  my $date = $self->{erefs}{-clock}->getDate();

  $self->set('end_time', $date . ',' . $time);

  $self->dirty();

  return 0;
} # Method end

#----------------------------------------------------------------------------
#
# Method:      getDigest
#
# Description: Get digest and date for digest number
#
# Arguments:
#  - Object reference
#  - Number 0..9
# Returns:
#  Digest
#  Date

sub getDigest($$) {
  # parameters
  my $self = shift;
  my ($no) = @_;

  $no = '0'
       unless ($no);
  return (scalar($self->get('session_digest_no_' . $no . '_value')),
          scalar($self->get('session_digest_no_' . $no . '_date')));
} # Method getDigest

#----------------------------------------------------------------------------
#
# Method:      setDigest
#
# Description: Set digest and date for digest number
#
# Arguments:
#  - Object reference
#  - Number
#  - Digest
#  - Date
# Returns:
#  -

sub setDigest($$$$) {
  # parameters
  my $self = shift;
  my ($no, $digest, $date) = @_;

  
  $self->set('session_digest_no_' . $no . '_value', $digest),
  $self->set('session_digest_no_' . $no . '_date' , $date);

  return 0;
} # Method setDigest

#----------------------------------------------------------------------------
#
# Method:      addDigest
#
# Description: Add new digest, the older are stepped
#
# Arguments:
#  - Object reference
#  - Digest (hexadecimal)
# Returns:
#  -

sub addDigest($$) {
  # parameters
  my $self = shift;
  my ($digest, $date) = @_;


  my ($prevDigest, $prevDate);
  my $no = 0;
  do {
    ($prevDigest, $prevDate) = $self->getDigest($no);
    if ($no <= MAX_DIGESTS) {
      $self->setDigest($no, $digest, $date);
      $digest = $prevDigest;
      $date   = $prevDate;
    } else {
      $self->setDigest($no, undef, undef);
    } # if #
    $no++;
  } while ($prevDigest);

  $self->save();
  return 0;
} # Method addDigest

#----------------------------------------------------------------------------
#
# Method:      checkSessionHistory
#
# Description: Check our session digests with session provided if it
#              is a historic session of ours
#
# Arguments:
#  - Object reference
#  - Directory or reference to other session
# Returns:
#  undef - Can not load other session
#  1 - This is our session
#  2 - This is an earlier of our session
#  3 - Our session is history of parallell session
#  4 - Other session is a branch
#  0 - No digests matched, it is another instance
#  -1 - We do not have any digest, we can not check

sub checkSessionHistory($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;


  my $found_session;
  if (ref($dir)) {
    $found_session = $dir;
  } else {

    # Get other session
    $found_session = $self->loadOther($dir);

    return undef
        unless (defined($found_session));

  } # if #

  # Get our session digests
  my %ourDigests;
  my $no = 0;
  while (defined($no)) {
    my ($digest, $date) = $self->getDigest($no);
    last
        unless (defined($digest));
    $self->{erefs}{-log}->log('Got our digest', $digest)
        if ($self->{erefs}{-log});
    $ourDigests{$digest} = [$no, $date];
    $no++;
  } # while #

  # Did we have any digests?
  return -1
      unless ($no > 0);

  # Check other session digests
  $no = 0;
  while (defined($no)) {
    my ($digest, $date) = $found_session->getDigest($no);
    last
        unless (defined($digest));
    $self->{erefs}{-log}->log('Check other digest', $digest)
        if ($self->{erefs}{-log});
    if (exists($ourDigests{$digest})) {
      if ($no == 0) {
        if ($ourDigests{$digest}[0] == 0) {
          # This is our session
          $self->{erefs}{-log}->log('Digest equal, our session')
              if ($self->{erefs}{-log});
          return 1;
        } else {
          # This is an earlier session of our instance
          $self->{erefs}{-log}->
                 log('This is an earlier session of our instance')
              if ($self->{erefs}{-log});
          return 2;
        } # if #
      } else {
        if ($ourDigests{$digest}[0] == 0) {
          # Our session is history of parallell session
          $self->{erefs}{-log}->
                 log('Our session is history of parallell session')
              if ($self->{erefs}{-log});
          return 3;
        } else {
          # Other session is a branch
          $self->{erefs}{-log}->
                 log('Other session is a branch')
              if ($self->{erefs}{-log});
          return 4;
        } # if #
      } # if #
    } # if #
    $no++;
  } # while #

  # No digests matched, it is another instance
  return 0;
} # Method checkSessionHistory

1;
__END__
