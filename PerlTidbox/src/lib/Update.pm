#
package Update;
#
#   Document: Manage Tidbox self updating
#   Version:  1.0   Created: 2019-02-13 21:26
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Update.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2019-02-13';

# History information:
#
# 1.0  2019-01-10  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use integer;

use Update::Controller;

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
# Description: Create update object
#
# Arguments:
#  - Object prototype
#  - Reference to call hash
# Returns:
#  Object reference

sub new($$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($args) = @_ ;
  my $self =
   {
    args       => $args,
    erefs      => {}   ,
    controller => undef,     # Update::Controller  Scheduled controller
   };
  bless($self, $class);
  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      init
#
# Description: Initialize update handling
#              - Start controller
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub init($) {
  # parameters
  my $self = shift;

# TODO This way can makes Update.pm more or less empty
  $self->{controller} = 
      Update::Controller->new($self->{args}, $self->{erefs});

  # Start autonomous updates
  $self->{controller}->setup();

  return 0;
} # Method init

#----------------------------------------------------------------------------
#
# Method:      setNewVersionCallback
#
# Description: Show when a new version is ready to be installed
#
# Arguments:
#  - Object reference
#  - Callback
# Returns:
#  -

sub setNewVersionCallback($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  return $self->{controller}->setNewVersionCallback($ref);
} # Method setNewVersionCallback

#----------------------------------------------------------------------------
#
# Method:      setRestart
#
# Description: Signal to restart script that Tidbox should be restarted
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - State: 0 = Only install, 1 = Install and restart
# Returns:
#  -

sub setRestart($;$) {
  # parameters
  my $self = shift;
  my ($state) = @_;

  return undef
      unless ($self->{controller});
  return $self->{controller}->setRestart($state);
} # Method setRestart

#----------------------------------------------------------------------------
#
# Method:      getReplaceScript
#
# Description: Return full path and name to replace Tidbox script
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub getReplaceScript($) {
  # parameters
  my $self = shift;

  return undef
      unless ($self->{controller});
  return $self->{controller}->getReplaceScript();
} # Method getReplaceScript

1;
__END__
