#
package TidBase;
#
#   Document: Base class for Tidbox classes
#   Version:  1.5   Created: 2016-01-27 11:02
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: TidBase.pmx
#

my $VERSION = '1.5';
my $DATEVER = '2016-01-27';

# History information:
#
# PA1  2006-11-25  Roland Vallgren
#      First issue
# PA2  2007-02-12  Roland Vallgren
#      Callback returns results from called method or subroutine
# 1.3  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
#      Method configure added
# 1.4  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.5  2016-01-15  Roland Vallgren
#      Added common methods to handle subscriptions (displays)
#      callback croaks if it can not handle a callback
#

#----------------------------------------------------------------------------
#
# Setup
#
use strict;
use warnings;
use Carp;
use integer;

use Scalar::Util qw(blessed weaken);

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
# Method:      callback
#
# Description: Call method or subroutine in callback reference
#                Sub: ARRAY: CODE, [arguments...]
#                Methods: ARRAY: Object, MethodName[arguments...]
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Callback reference
# Returns:
#  Value from called routine
#  1 if callback is not understod
#  0 no callback defined
#  Returns return code fromn callbacks

sub callback($;$@) {
  # parameters
  my $self = shift;
  my ($callback, @arg) = @_;

  return 0 unless $callback;


  return &$callback(@arg) if (ref($callback) eq 'CODE');

  unless (ref($callback) eq 'ARRAY') {
    croak "callback issued: \"" . ref($callback) . "\" Not ARRAY, afraid no good way to handle this\n";
    return 1;
  }

  if (ref($callback->[0]) eq 'CODE') {
    my ($sub, @opt) = @$callback;
    return &$sub(@opt, @arg);

  } elsif (ref($callback->[0])) {
    my ($obj, $met, @opt) = @$callback;
    return $obj->$met(@opt, @arg);

  } # if #

  croak "callback issued: No known way to handle\n";
  return 1;
} # Method callback

#----------------------------------------------------------------------------
#
# Method:      configure
#
# Description: Add setting to an object
#
# Arguments:
#  0 - Object reference
# Additional arguments as hash
#  
# Returns:
#  -

sub configure($%) {
  # parameters
  my $self = shift;
  my %args = @_;

  while (my ($key, $val) = each(%args)) {
    $self->{$key} = $val;
    # To improve performance when Tidbox is shut down,
    # weaken references to other objects
    weaken($self->{$key})
        if (blessed($val));
  } # while #

  return 0;
} # Method configure

#----------------------------------------------------------------------------
#
# Method:      setDisplay
#
# Description: Set display for changes used by clients
#              TODO: Is the name OK? (Suggestion add 'ec' for EventCfg)
#              TODO: TitleClock does not handle an ordinary callback
#
# Arguments:
#  - Object reference
#  - Name of the change
#  - Callback argument, undef to disable
# Returns:
#  -

sub setDisplay($$$) {
  # parameters
  my $self = shift;
  my ($name, $disp) = @_;

  $self->{-display}{$name} = $disp;
  return 0;
} # Method setDisplay

#----------------------------------------------------------------------------
#
# Method:      _doDisplay
#
# Description: Display subscribed changes
#              Calls the registered handler provided arguments
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 .. n - Dates array fetched earlier from by
# Returns:
#  -

sub _doDisplay($;@) {
  # parameters
  my $self = shift;


  for my $ref (values(%{$self->{-display}})) {
    $self->callback($ref, @_)
        if ($ref);
  } # for #

  return 0;
} # Method _doDisplay

1;
__END__
