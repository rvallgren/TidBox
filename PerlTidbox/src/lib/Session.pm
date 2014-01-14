#
package Session;
#
#   Document: Session class
#   Version:  1.0   Created: 2011-03-27 12:44
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Session.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2011-03-27';

# History information:
#
# 1.0  2011-03-16  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent TidBase;
use parent FileBase;

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


use constant FILENAME  => 'session.dat';
use constant FILEKEY   => 'SAVED SESSION DATA';

#----------------------------------------------------------------------------
#
# Initial configuration data settings
#
#  key                value
#  start_time         Date and time when started
#  last_starttime     Date and time when started last time
#  last_endtime       Date and time when ended last time
#  uptime             Total time the tool has been running in this session
#  last_uptime        Time the tool was running last time
#  accumulated_time   Accumulated total time the tool has been running
#  <win>_pos          Last position of window
#  Filägare?          ?
#                           

my %DEFAULTS = (
   );


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
# Returns:
#  Object reference

sub new($$%) {
  my $class = shift;
  $class = ref($class) || $class;
  my $args = shift;

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
  my $val = $self->{-cfg}->get($key);
  if (defined($val)) {
    $self->{-cfg}->delete($key);
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
    $self->{-cfg}->delete($key)
        if ($self->{-cfg}->get($key));
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
# Method:      start
#
# Description: Add start of workday, if not started yet
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

  $self->dirty();

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
  $self->{-clock}->repeat(-minute => [$self => 'minute']);

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
    $self->{save_threshold} = $self->{-cfg}->get('save_threshold') + 1;
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


  my $time = $self->{-clock}->getTime();
  my $date = $self->{-clock}->getDate();

  $self->set('end_time', $date . ',' . $time);

  $self->dirty();

  return 0;
} # Method end

1;
__END__
