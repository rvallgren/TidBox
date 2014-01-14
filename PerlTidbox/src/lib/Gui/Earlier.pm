#
package Gui::Earlier;
#
#   Document: Gui::Earlier
#   Version:  1.2   Created: 2011-04-01 14:25
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Earlier.pmx
#

my $VERSION = '1.2';
my $DATEVER = '2011-04-01';

# History information:
#
# 1.0  2007-03-05  Roland Vallgren
#      First issue.
# 1.1  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.2  2011-04-01  Roland Vallgren
#      Return reference to button widget on create and prevButt
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent TidBase;

use strict;
use warnings;
use Carp;
use integer;

use Tk;

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

# Registration analysis constants
my $YEAR  = '\d{4}';
my $MONTH = '\d{2}';
my $DAY   = '\d{2}';
my $DATE = $YEAR . '-' . $MONTH . '-' . $DAY;

my $HOUR   = '\d{2}';
my $MINUTE = '\d{2}';
my $TIME   = $HOUR . ':' . $MINUTE;

my $TYPE = '[A-Z]+';

# Event analysis constants
my $TXT_BEGIN       = ' började';
my $TXT_END         = ' slutade';

my $WORKDAYDESC         = 'Arbetsdagen';
my $WORKDAY             = 'WORK';
my $BEGINWORKDAY        = 'BEGINWORK';
my $ENDWORKDAY          = 'WORKEND';

my $PAUSDESC            = 'Paus';
my $BEGINPAUS           = 'PAUS';
my $ENDPAUS             = 'ENDPAUS';

my $EVENTDESC           = 'Händelse';
my $BEGINEVENT          = 'EVENT';
my $ENDEVENT            = 'ENDEVENT';

# Hash to store common texts
my %TEXT = (
             $BEGINWORKDAY => 'Börja arbetsdagen',
             $ENDWORKDAY   => 'Sluta arbetsdagen',

             $BEGINPAUS    => 'Börja paus',
             $ENDPAUS      => 'Sluta paus',

             $BEGINEVENT   => 'Börja händelse',
             $ENDEVENT     => 'Sluta händelse',
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
# Description: Create earlier menu object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              previous  => {},
              prev_text => '',
             };

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      setPrev
#
# Description: Set previous button value
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Event text
# Returns:
#  -

sub setPrev($;$) {
  # parameters
  my $self = shift;
  my ($t) = @_;

  $t = '' unless $t;
  return 0 if ($self->{prev_text} eq $t);
  $self->{prev_text} = $t;
  return
      $self->{prev_butt} -> configure(-text=>$t, -state => "normal")
    if ($t);
  return
      $self->{prev_butt} -> configure(-text=>'Föregående', -state => "disabled")

} # Method setPrev

#----------------------------------------------------------------------------
#
# Method:      prevBut
#
# Description: Create a previous button
#
# Arguments:
#  0 - Object reference
#  1 - Area to add button in
#  2 - Reference to button callback array
# Returns:
#  -

sub prevBut($$$) {
  # parameters
  my $self = shift;
  my ($area, $callback) = @_;

  $self->{prev_butt} = $area
      -> Button(-text => 'Föregående', -bd=>'3',
                -command => $callback,
                -state => 'disabled')
      -> pack(-side => 'left');
  push @$callback, \$self->{prev_text};
  return $self->{prev_butt};
} # Method prevBut

#----------------------------------------------------------------------------
#
# Method:      add
#
# Description: Add an earlier event, pushing the other down the list
#              and removing the earliest.
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Event to add
# Returns:
#  -

sub add($;$) {
  # parameters
  my $self = shift;
  my ($event) = @_;

  return 0 unless $event;
  my $move;

  if (exists($self->{previous}{$event})) {
    return 0 unless $self->{previous}{$event};
    $move = $self->{previous}{$event};
  } else {
    $move = $self->{-cfg}->get('earlier_menu_size');
  } # if #

  while (my ($action, $cnt) = each(%{$self->{previous}})) {
    if ($cnt < $move) {
      $self->{previous}{$action}++;
    } elsif ($cnt == $move) {
      delete($self->{previous}{$action})
          unless (exists($self->{previous}{$event}));
      for my $menu (@{$self->{menus}}) {
        $menu->{menu} -> delete($cnt) if Exists($menu->{menu});
      } # for #
    } # if #
  } # while #

  $self->{previous}{$event} = 0;
  for my $menu (@{$self->{menus}}) {
    $menu->{menu}
      -> insert(0, 'radiobutton',
                -command => $menu->{callback},
                -label => $event,
                -variable => \$menu->{value},
                -value => $event,
                -indicatoron => 0
               )
        if Exists($menu->{menu});
  } # for #

  return 0;
} # Method add

#----------------------------------------------------------------------------
#
# Method:      _build
#
# Description: Add menu contents in an empty menu
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _build($$) {
  # parameters
  my $self = shift;
  my ($item) = @_;


  my $m = $item->{menu};
  my $c = $item->{callback};
  my $r = \$item->{value};
  my $p = $self->{previous};

  for my $k (sort {$p->{$a} <=> $p->{$b}} keys %{$p}) {
    $m -> add('radiobutton',
              -command  => $c,
              -label    => $k,
              -variable => $r,
              -value    => $k,
              -indicatoron => 0
             );
  } # for #
  return 0;
} # Method _build

#----------------------------------------------------------------------------
#
# Method:      build
#
# Description: Build previous data from times data
#
# Arguments:
#  0 - Object reference
#  1 - Reference to times object
# Returns:
#  -

sub build($$) {
  # parameters
  my $self = shift;
  my ($times) = @_;

  my $previous_c = 0;
  %{$self->{previous}} = ();
  for my $ref (reverse(
               $times->getSortedRefs(join(',', $DATE, $TIME, $BEGINEVENT))
              )) {
    if ($$ref =~ /^$DATE,$TIME,$BEGINEVENT,(.+)$/o) {
      next if exists($self->{previous}{$1});
      $self->{previous}{$1} = $previous_c;
      $previous_c++;
      last if $previous_c >= $self->{-cfg}->get('earlier_menu_size');
    } # if #
  } # for #

  # Add menubuttons to created menus
  for my $menu (@{$self->{menus}}) {
    $self->_build($menu) if Exists($menu->{menu});
  } # for #
  return 0;
} # Method build

#----------------------------------------------------------------------------
#
# Method:      create
#
# Description: Create an earlier menu for a window
#
# Arguments:
#  0 - Object reference
#  1 - Reference window hash were to add menu
#  2 - Pack side setting
#  3 - Reference to array for callback to handle the earlier event
# Optional Arguments:
#  4 - Title of the menu
# Returns:
#  -

sub create($$$$;$) {
  # parameters
  my $self = shift;
  my ($area, $side, $callback, $title) = @_;


  my $menu = {
              callback  => $callback,
              value     => undef,
             };
  push @$callback, \$menu->{value};

  ### Previous menu button ###
  $title = "Tidigare"
      unless ($title);
  $menu->{butt} = $area
      -> Menubutton(-text => $title, -bd => '3', -relief => 'raised')
      -> pack(-side => $side);

  ### Previous menu ###
  $menu->{menu} = $menu->{butt}
      -> Menu(-tearoff => 'false');

  ### Previous menu entries ###
  $self->_build($menu);

  # Associate Menubutton with Menu.
  $menu->{butt} -> configure(-menu => $menu->{menu});

  push @{$self->{menus}}, $menu;

  return $menu->{butt};
} # Method create

1;
__END__
