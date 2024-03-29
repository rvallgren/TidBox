#
package Gui::Earlier;
#
#   Document: Gui::Earlier
#   Version:  1.5   Created: 2019-09-12 14:34
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Earlier.pmx
#

my $VERSION = '1.5';
my $DATEVER = '2019-09-12';

# History information:
#
# 1.0  2007-03-05  Roland Vallgren
#      First issue.
# 1.1  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.2  2011-04-01  Roland Vallgren
#      Return reference to button widget on create and prevButt
# 1.3  2015-11-04  Roland Vallgren
#      getSortedRefs joins expression
# 1.4  2017-10-16  Roland Vallgren
#      References to other objects in own hash
# 1.5  2019-08-29  Roland Vallgren
#      Code improvements
#      Get last unique events from Times for previous data
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

use Tk;

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

# Registration analysis constants
my $YEAR  = '\d{4}';
my $MONTH = '\d{2}';
my $DAY   = '\d{2}';
my $DATE = $YEAR . '-' . $MONTH . '-' . $DAY;

my $HOUR   = '\d{2}';
my $MINUTE = '\d{2}';
my $TIME   = $HOUR . ':' . $MINUTE;

my $TYPE = qr/[BEPW][AENOV][DEGRU][EIKNPS][ADEKNORSTUVW]*/;

# Event analysis constants
# Actions are choosen to be sorted alphabetically, sort 1, 2, 3, 4, 5, 6
# This only applies to actions registered on the same time and
# normally it is only when it is meaningful as time it is OK to do so
# Like this:
#   BEGINWORK should be befor any other action
#   ENDPAUS or ENDEVENT should be before EVENT or PAUS
#   WORKEND should be after any other
my $WORKDAYDESC         = 'Arbetsdagen';
my $WORKDAY             = 'WORK';
my $BEGINWORKDAY        = 'BEGINWORK';      # Sort 1
my $ENDWORKDAY          = 'WORKEND';        # Sort 6

my $PAUSDESC            = 'Paus';
my $BEGINPAUS           = 'PAUS';           # Sort 5
my $ENDPAUS             = 'ENDPAUS';        # Sort 3

my $EVENTDESC           = 'H�ndelse';
my $BEGINEVENT          = 'EVENT';          # Sort 4
my $ENDEVENT            = 'ENDEVENT';       # Sort 2

# Hash to store common texts
my %TEXT = (
             $BEGINWORKDAY => 'B�rja arbetsdagen',
             $ENDWORKDAY   => 'Sluta arbetsdagen',

             $BEGINPAUS    => 'B�rja paus',
             $ENDPAUS      => 'Sluta paus',

             $BEGINEVENT   => 'B�rja h�ndelse',
             $ENDEVENT     => 'Sluta h�ndelse',
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
      $self->{prev_butt} -> configure(-text=>'F�reg�ende', -state => "disabled")

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
      -> Button(-text => 'F�reg�ende', -bd=>'3',
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
    $move = $self->{erefs}{-cfg}->get('earlier_menu_size');
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
# Method:      buildData
#
# Description: Build previous data from times data
#
# Arguments:
#  0 - Object reference
#  1 - Reference to times object
# Returns:
#  -

sub buildData($$) {
  # parameters
  my $self = shift;
  my ($times) = @_;

  my $size = $self->{erefs}{-cfg}->get('earlier_menu_size');
  $self->{previous} = $times->getPreviousEvents($size);

  return 0;
} # Method buildData

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
