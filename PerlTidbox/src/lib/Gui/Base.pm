#
package Gui::Base;
#
#   Document: Base class for Guis
#   Version:  1.9   Created: 2017-09-29 13:43
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: GuiBase.pmx
#

my $VERSION = '1.9';
my $DATEVER = '2017-09-29';

# History information:
#
# PA1  2006-11-16  Roland Vallgren
#      First issue
# PA2  2006-11-22  Roland Vallgren
#      Corrected "++" bugg that caused fail to start
# PA3  2006-11-25  Roland Vallgren
#      Use common tidbox base class
#      Added method to show window over parent window
# PA4  2007-03-10  Roland Vallgren
#      Add a confirm instance when a named window is created
#      Method withdraw used by popup and window
# 1.5  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
#      Do not withdraw if a fault is returned
#      Use right and bottom edge relative geometry to move window onto screen
# 1.6  2007-06-29  Roland Vallgren
#      Added support for main window create and destroy
#      Method configure moved to common tidbox base class
# 1.7  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.8  2011-04-03  Roland Vallgren
#      Window positions data stored as session data
# 1.9  2017-04-25  Roland Vallgren
#      Do not withdraw a not existing Confirm 
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
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}


############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      _getPos
#
# Description: Get window position
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _getPos($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  return 0
     unless ($win_r->{win} and $win_r->{name});

  if ($win_r->{win} -> geometry() =~ /(\+-?\d+\+-?\d+$)/o) {

    my $key = $win_r->{name} . '_geometry';
    my $val = $self->{-session}->get($key);

    if ($self->{-cfg}->get('remember_positions')) {

      $self->{-session}->set($key => $1)
          if (not defined($val) or ($val ne $1));

    } else {

      $self->{-session}->set($key => undef)
          if (defined($val));

      $self->{-geometry} = $1;

    } # if #
  } # if #

  return 0;
} # Method _getPos

#----------------------------------------------------------------------------
#
# Method:      _displayFrame
#
# Description: Create a window or raise from withdrawn or iconised state
#              If not exists call the method to setup the window
#
# Arguments:
#  0 - Object reference
#  1..n - Additional data required to display contents in a window
# Returns:
#  -

sub _displayFrame($@) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  # Setup Window
  unless (Exists($win_r->{win})) {
    # Create the window

    ### Toplevel ###
    unless (exists($self->{-parent_win})) {

      $win_r->{win} =
          new MainWindow(-title => $self->{-title});

      # This is the parent window
      $self->{-parent_win}{win} = $win_r;

      $win_r->{win}
          -> protocol('WM_DELETE_WINDOW', [$self => 'destroy']);

    } else {

      $win_r->{win} = $self->{-parent_win}{win}
          -> Toplevel(-title => $self->{-title});

      $win_r->{win}
          -> protocol('WM_DELETE_WINDOW', [$self => 'withdraw']);

    } # unless #

    ### Heading ###
    $win_r->{title_area} = $win_r->{win}
        -> Frame()
        -> pack(-side => 'top', -expand => '0', -fill => 'x');

    $win_r->{title} = $win_r->{title_area}
        -> Label()
        -> pack(-side => 'top');

    ### Window contents area ###
    $win_r->{area} = $win_r->{win}
        -> Frame()
        -> pack(-side => 'top', -expand => '1', -fill => 'both');

    ### Button area ###
    $win_r->{button_area} = $win_r->{win}
        -> Frame()
        -> pack(-side => 'top', -expand => '0', -fill => 'x');

    ### Let the class add its contents ###
    $self->_setup(@_);

    # Let window show up before any further actions
    $win_r->{win}->idletasks();

    # Save window reference
    $self->{win} = $win_r;

    # Add a confirm instance for a named window. Confirm windows are not named
    $win_r->{confirm} = new Gui::Confirm(
                              -parent_win => $win_r,
                              -title      => $self->{-title},
                                         )
        if(exists($win_r->{name}));


  } else {
    # Raise window
    $self->_getPos();
    $win_r->{win} -> geometry('') if $win_r->{win}->state() eq 'withdrawn';
    $win_r->{win} -> deiconify();
    $win_r->{win} -> raise();

  } # unless #

  # Add data contents
  $self->_display(@_);

  # Let window show up before any further actions
  $win_r->{win}->idletasks();
  if (exists($win_r->{day_list})) {
    $win_r->{day_list}->setDate();
  } # if #


  return 0;
} # Method _displayFrame

#----------------------------------------------------------------------------
#
# Method:      display
#
# Description: Show a window and handle screen position
#
# Arguments:
#  0 - Object reference
#  1..n - Additional data required to display contents in a window
# Returns:
#  -

sub display($@) {
  # parameters
  my $self = shift;


  $self->_displayFrame(@_);

  my $win_r = $self->{win};

  # Set window geometry
  my $key = $win_r->{name} . '_geometry';
  my ($pos_x, $pos_y);

  if ($self->{-geometry})
  {
    (undef, $pos_x, $pos_y) = split(/\+/, $self->{-geometry});
  }
  elsif ($self->{-cfg} and
         $self->{-cfg}->get('remember_positions') and
         (my $val = $self->{-session}->get($key))
        )
  {
    (undef, $pos_x, $pos_y) = split(/\+/, $val);
  } # if #

  if (defined($pos_x) and defined($pos_y)) {

    my ($scr_x, $scr_y) = $win_r->{win} -> maxsize();
    my ($win_w, $win_h) = split(/\D/, $win_r->{win} -> geometry());

    # Here MS Windows decorations does add 12 pixels in width and height.
    # There is, as far as I know, no explanation why and I expect it to change.
    # But, as a first try, lets compensate for this.
    $win_w += 12;
    $win_h += 12;

    # Set lower right corner on screen ...
    # ... but make sure upper left corner is on screen.
    if (($win_w > $scr_x) or ($pos_x < 0)) {
      $pos_x = '+0';
    } elsif ($scr_x < ($pos_x + $win_w)) {
      $pos_x = '-0';
    } else {
      $pos_x = '+' . $pos_x;
    } # if #
    if (($win_h > $scr_y) or ($pos_y < 0)) {
      $pos_y = '+0';
    } elsif ($scr_y < ($pos_y + $win_h)) {
      $pos_y = '-0';
    } else {
      $pos_y = '+' . $pos_y;
    } # if #

    $win_r->{win} -> geometry($pos_x . $pos_y);

  } # if #


  return 0;
} # Method display

#----------------------------------------------------------------------------
#
# Method:      getWin
#
# Description: Get reference to window hash
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getWin($) {
  # parameters
  my $self = shift;

  return $self->{win};
} # Method getWin

#----------------------------------------------------------------------------
#
# Method:      getName
#
# Description: Get name of window
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub getName($) {
  # parameters
  my $self = shift;

  return $self->{win}{name};
} # Method getWin

#----------------------------------------------------------------------------
#
# Method:      withdraw
#
# Description: Perform action and withdraw a window
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Key to action to perform
# Returns:
#  -

sub withdraw($;$) {
  # parameters
  my $self = shift;
  my ($action) = @_;


  my $win_r = $self->{win};

  return 0
      unless ($win_r and $win_r->{win});

  $action = 'done'
      unless $action;

  my $res = $self->callback($self->{$action});

  return $res
      if $res;

  if ($win_r->{name}) {
    $self -> _getPos();
    $win_r->{confirm} -> withdraw() if $win_r->{confirm};
    $win_r->{win} -> withdraw() if (Exists($win_r->{win}));
  } else {
    $win_r->{win} -> withdraw() if (Exists($win_r->{win}));
    $win_r->{pp_cont} -> destroy() if Exists($win_r->{pp_cont});
    $win_r->{pp_butt} -> destroy() if Exists($win_r->{pp_butt});
  } # if #

  return 0;
} # Method withdraw

#----------------------------------------------------------------------------
#
# Method:      destroy
#
# Description: Destroy the Perl TK main window
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Key to action to perform
# Returns:
#  -

sub destroy($;$) {
  # parameters
  my $self = shift;
  my ($action) = @_;

  $self->withdraw($action);
  $self->{win}{win} -> destroy();
  delete($self->{win}{win});

  return 0;
} # Method destroy

#----------------------------------------------------------------------------
#
# Method:      popup
#
# Description: Show a popup window on top of a parent window,
#              Raise from withdrawn or iconised state
#              If not exists call the method to setup the window
#
# Arguments:
#  0 - Object reference
#  1 - Reference to window that caused the popup
# Returns:
#  -

sub popup($$;@) {
  # parameters
  my $self = shift;


  $self -> withdraw('cancel');

  my $parent = $self->{-parent_win}{win};
  $parent -> idletasks();

  $self->_displayFrame(@_);

  ### Show window on top of calling window ###

  my $win_r = $self->{win};
  if ($parent->geometry() =~ /^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)$/o) {
    my ($w, $h, $x, $y) = ($1, $2, $3, $4);

    my ($pw, $ph) = ($1, $2)
       if ($win_r->{win}->geometry() =~ /^(\d+)x(\d+)/o);

    $x += ($w - $pw)/2;
    $x = 0 if ($x < 0);

    if ($h > $ph) {
      $y += ($h - $ph)/2;
    } else {
      $y += 28;
    } # if #

    $win_r->{win}->geometry("+$x+$y");
  } # if #
  $win_r->{win}->raise();

  return 0;
} # Method popup

#----------------------------------------------------------------------------
#
# Method:      quit
#
# Description: Application is about to quit, retreive needed data
#              but do not destory yet, let TK destroy it all afterwards
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub quit($) {
  # parameters
  my $self = shift;


  $self->_getPos();

  return 0;
} # Method quit

1;
__END__
