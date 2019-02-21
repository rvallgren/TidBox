#
package Gui::SupervisionConfig;
#
#   Document: Supervision Configuration class
#   Version:  1.2   Created: 2019-01-17 11:07
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: SupervisionConfig.pmx
#

my $VERSION = '1.2';
my $DATEVER = '2019-01-17';

# History information:
#
# 1.2  2017-10-16  Roland Vallgren
#      References to other objects in own hash
# 1.1  2017-10-05  Roland Vallgren
#      Don't need FileBase
# 1.0  2016-01-26  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use Carp;
use integer;

use Gui::Event;
use Gui::Time;

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


#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create supervision configuration Gui object
#
# Arguments:
#  - Object prototype
#  -event_cfg   reference to event_cfg
#  -supervision reference to supervision
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;
  my %args = @_;

  # Setup and store notify reference
  my $edit_r = {
                -area      => $args{-area}         ,
                name       => 'SupervisionConfig'  ,
                enabled    => 0                    ,
               };


  my $self = {
                edit         => $edit_r,
                erefs => $args{erefs},
                -notify      => $args{-modified},
                -invalid     => $args{-invalid} ,
                condensed    =>   0,
             };

  bless($self, $class);

  ## Area ##
  $edit_r->{set_area} = $edit_r->{-area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  ### Label ###
  $edit_r->{data_lb} = $edit_r->{set_area}
      -> Label(-text => 'Bevaka:')
      -> pack(-side => 'left');

  ### Enable checkbox ###
  # Here we have to make a weird workaround because TK::Checkbutton does
  # bless the reference sent to -command as a TK::Callback.
  # TidBas::callback does not know how handle such a callback and hence fails
  $edit_r->{enabled} = 0;
  $edit_r->{data_enable} = $edit_r->{set_area}
      -> Checkbutton(-command  => [@{$self->{-notify}}],
                     -variable => \$edit_r->{enabled},
                     -onvalue  => 1,
                     -offvalue => 0)
      -> pack(-side => 'left');

  ### Event cfg ##
  $edit_r->{event_handling} =
      new Gui::Event(erefs => {
                      -event_cfg  => $self->{erefs}{-event_cfg},
                              },
                    -area       => $edit_r->{set_area},
                    -parentName => $edit_r->{name},
                    -validate   => [$self => '_eventKey'],
                    -buttons    => [$self => '_addButtons'],
                   );

  ## Startdate ##
  $edit_r->{date_area} = $edit_r->{set_area}
      -> Frame(-bd => '1', -relief => 'sunken')
      -> pack(-side => 'top', -expand => '1', -fill => 'both');
  $edit_r->{time_area} =
      new Gui::Time(
                    -area      => $edit_r->{date_area},
                    erefs => {
                      -calculate => $self->{erefs}{-calculate},
                             },
                    -date      => 1,
                    -invalid   => $self->{-invalid},
                    -notify    => $self->{-notify},
                    -label     => 'Från och med dag:',
                   );

  ## Supervision enable / clear ##
  $edit_r->{buttons_area} = $edit_r->{set_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $edit_r->{clear} = $edit_r->{buttons_area}
      -> Button(-text => 'Rensa', -command => [$self => '_setupClear'])
      -> pack(-side => 'right');


  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _eventKey
#
# Description: Validate event keys
#
# Arguments:
#  0 - Object reference
# Arguments as received from the validation callback:
#  1 - The proposed value of the entry.
#  2 - The characters to be added (or deleted).
#  3 - The current value of entry i.e. before the proposed change.
#  4 - Index of char string to be added/deleted, if any. -1 otherwise
#  5 - Type of action. 1 == INSERT, 0 == DELETE, -1 if it's a forced
# Returns:
#  0 - True, edit is allways allowed

sub _eventKey($$$$$$) {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;

  $self->callback($self->{-notify});
  return 1;
} # Method _eventKey

#----------------------------------------------------------------------------
#
# Method:      _setupClear
#
# Description: Clear supervision setup
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _setupClear($) {
  # parameters
  my $self = shift;

  my $edit_r = $self->{edit};
  $edit_r->{enabled} = 0;
  $edit_r->{event_handling}->clear();
  $edit_r->{time_area}->clear();

  $self->callback($self->{-notify});

  return 0;
} # Method _setupClear

#----------------------------------------------------------------------------
#
# Method:      _previous
#
# Description: Add previous
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event to add
# Returns:
#  -

sub _previous($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  $self->{edit}{event_handling}->set($$ref);
  return 0;
} # Method _previous

#----------------------------------------------------------------------------
#
# Method:      apply
#
# Description: Apply changes
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub apply($) {
  # parameters
  my $self = shift;


  unless ($self->getData()) {
    return undef;
  }

  # Save supervision settings
  $self->{erefs}{-supervision}->setCfg($self->{cfg});
  $self->{erefs}{-supervision}->setup();

  return 1;
} # Method apply

#----------------------------------------------------------------------------
#
# Method:      getData
#
# Description: Get supervision data
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getData($) {
  # parameters
  my $self = shift;


  my $err_r = [];
  my $date;
  my $edit_r = $self->{edit};
  (undef, $date) = $edit_r->{time_area}->get(1);

  my $action_text =
        $edit_r->{event_handling}->get($self->{-invalid});

  return undef
      unless (defined($date) and $action_text);

  # Store event supervision configuration
  $self->{cfg}{sup_event}  = $action_text;
  $self->{cfg}{start_date} = $date;
  $self->{cfg}{sup_enable} = $edit_r->{enabled};

  return 1;
} # Method getData

#----------------------------------------------------------------------------
#
# Method:      _update
#
# Description: Update displyed supervision data
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _update($) {
  # parameters
  my $self = shift;


  if ($self->{cfg}{sup_event}) {
    $self->{edit}{event_handling}->set($self->{cfg}{sup_event});
  } else {
    $self->{edit}{event_handling}->clear();
  } # if #

  $self->{edit}{time_area} -> set(undef, $self->{cfg}{start_date});
  $self->{edit}{enabled} = $self->{cfg}{sup_enable};

  return 0;
} # Method _update

#----------------------------------------------------------------------------
#
# Method:      showEdit
#
# Description: Insert values in supervision edit
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub showEdit($) {
  # parameters
  my $self = shift;


  # Copy supervision settings
  my $ref = $self->{erefs}{-supervision}->getCfg();
  %{$self->{cfg}} = %{$ref};


  $self->_update();
  return 0;
} # Method showEdit

#----------------------------------------------------------------------------
#
# Method:      _addButtons
#
# Description: Add buttons for the supervision dialog
#
# Arguments:
#  0 - Object reference
#  1 - Area were to add
# Returns:
#  -

sub _addButtons($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;

  $self->{erefs}{-earlier}->create($area, 'right', [$self => '_previous']);
  return 0;
} # Method _addButtons

1;
__END__
