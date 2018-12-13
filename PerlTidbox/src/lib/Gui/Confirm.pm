#
package Gui::Confirm;
#
#   Document: Confirm
#   Version:  1.11   Created: 2018-12-06 21:01
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Confirm.pmx
#

my $VERSION = '1.11';
my $DATEVER = '2018-12-06';

# History information:
#
# 1.6  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
# 1.7  2008-01-04  Roland Vallgren
#      Added "NoteBook" style layout and advanced buttons layout
# 1.8  2008-09-06  Roland Vallgren
#      Allow copy from data areas, that is ROtext
# 1.9  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.10  2013-05-27  Roland Vallgren
#       Remove trailing and heading white space in labels
# 1.11  2018-02-19  Roland Vallgren
#       Done action can not be used to destroy window
#       Added progress bar
#

#----------------------------------------------------------------------------
#
# Setup
#
use base Gui::Base;

use strict;
use warnings;
use Carp;
use integer;

use Tk ();
use Tk::NoteBook;

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

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create a new confirm popup
#
# Arguments:
#  0 - Object prototype
#  -parent_win  Parent window
#  -title       Window title
# Returns:
#  Object reference

sub new($%) {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = {
               @_,
               exit => undef,
             };

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _setup
#
# Description: Needed by Gui::Base, no action
#
# Arguments:
#  -
# Returns:
#  -

sub _setup() {
  return 0;
} # Method _setup

#----------------------------------------------------------------------------
#
# Method:      _display
#
# Description: Display the confirm popup
#              Yes and No buttons are created if action is specified
#              Close button otherwise
#              Window close will call No or Done callback
#
# Arguments:
#  0 - Object reference
#  Labels, buttons content
#    -text     Reference to array of Confirm texts
#    -data     Reference to array of Optional data to confirm
#    -layout   'simple' (default) or 'NoteBook'
#  Progress bar content
#    -progress  Text to display with the progress bar
#  Radio button content
#    -radio    Reference to array of Radio buttons definitions
#  -buttons  Reference to array with pairs, button text, Callback
#            Buttons are added from right, that is "No" button last
#  -action   Use Yes and No buttons, Callback to perform for Yes button
#  -reject   Callback to perform on No button
#  -done     Callback to perform on Close button
# Returns:
#  Object reference

sub _display($%) {
  my $self = shift;
  my %args = @_;

  # Setup confirm popup contents
  my $win_r = $self->{win};

  # Window frame
  if ($args{-fulltitle}) {
    $win_r->{win} -> configure(-title => $args{-fulltitle});

  } elsif ($args{-title}) {
    $win_r->{win} ->
        configure(-title => $self->{-title} . ' ' . $args{-title});

  } else {
    $win_r->{win} -> configure(-title => $self->{-title});

  } # if #

  # Create the contents
  my $area = 'pp_cont';
  my $no = 0;

  if ($args{-text}) {
    # Notebook or frame
    my $layout = 'simple';

    $layout = $args{-layout}
        if ($args{-layout});

    if ($layout eq 'NoteBook') {
      $win_r->{pp_cont} = $win_r->{area} -> NoteBook(-dynamicgeometry => 1);
    } else {
      $win_r->{pp_cont} = $win_r->{area} -> Frame();
    } # if #
    $win_r->{pp_cont} -> pack(-side => 'top', -expand => '1', -fill => 'both',
                              -padx => 5, -pady => 5);

    # Texts and data
    my @data;
    @data = @{$args{-data}}
        if $args{-data};

    for my $text (@{$args{-text}}) {

      if ($layout eq 'NoteBook') {
        $area = 'tab_' . ++$no;
        $win_r->{$area} = $win_r->{pp_cont}
            -> add($area, -label => $text);
      } else {
        $win_r->{$area}
            -> Frame()
            -> pack(-side => 'top', -expand => '1', -fill => 'both')
            -> Label(-text => $text, -justify => 'left')
            -> pack(-side => 'left');
      } # if #

      if (@data) {
        my $t = shift(@data);
        next unless (defined($t));
        if (not ref($t)) {
          my $s = $t;
          $s =~ s/^\s+//;
          $s =~ s/\s+$//;
          $win_r->{$area}
                -> Frame(-bd => '2', -relief => 'sunken')
                -> pack(-side => 'top', -expand => '1', -fill => 'both')
                -> Label(-text => $s, -justify => 'left')
                -> pack(-side => 'left');

        } elsif (ref($t) eq 'SCALAR') {
          $win_r->{$area}
              -> Frame()
              -> pack(-side => 'top', -expand => '1', -fill => 'both')
              -> ROText(
                        -wrap => 'no',
                        -height => 1,
                        -width => length($$t),
                       )
              -> pack(-side => 'left')
              -> Insert($$t);

        } elsif (ref($t) eq 'ARRAY') {
          my $w = 10;
          for my $s (@$t) {
            $w = length($s)
                if ($w < length($s));
            $s =~ s/\s+$//;
          } # for #

          $win_r->{$area}
              -> Frame()
              -> pack(-side => 'top', -expand => '1', -fill => 'both')
              -> ROText(
                        -wrap => 'no',
                        -height => @$t + 1,
                        -width => $w,
                       )
              -> pack(-side => 'left')
              -> Insert(join("\n", @$t));

        } elsif (ref($t) eq 'HASH') {
          my @tmp;
          for my $k (sort(keys(%$t))) {
            push @tmp, $k . $t->{$k};
          } # for #

          $win_r->{$area}
              -> Frame(-bd => '2', -relief => 'sunken')
              -> pack(-side => 'top', -expand => '1', -fill => 'both')
              -> Label(-text => join("\n", @tmp), -justify => 'right')
              -> pack(-side => 'left');

        } else {
          $win_r->{$area}
              -> Frame(-bd => '2', -relief => 'sunken')
              -> pack(-side => 'top', -expand => '1', -fill => 'both')
              -> Label(-text => 'ERROR: felaktig typ', -justify => 'left')
              -> pack(-side => 'left');
        } # if #
      } # if #
    } # for #

  } elsif ($args{-progress}) {
    # Progress bar

    # Add progress heading
    $win_r->{area}
        -> Frame()
        -> pack(-side => 'top', -expand => '1', -fill => 'both')
        -> Label(-text => $args{-progress}, -justify => 'left')
        -> pack(-side => 'top', -expand => '1', -fill => 'x');

    # Add progress bar
    $win_r->{'progress_bar'} = $win_r->{area}
        -> Frame()
        -> pack(-side => 'top', -expand => '1', -fill => 'both')
        -> ProgressBar(
                       -width => 15,
                       -from => 0,
                       -to => 100,
                       -blocks => 0,
                       -gap => 0,
                       -colors => [0, 'blue'],
                       -value => 0,
                      )->pack(-side => 'top', -fill => 'x');

    # Add numeric procent
    $win_r->{progress_procent} = $win_r->{area}
        -> Frame()
        -> pack(-side => 'top', -expand => '1', -fill => 'both')
        -> Label(-text => '', -justify => 'left')
        -> pack(-side => 'top', -expand => '1', -fill => 'x');

    # Do not add any buttons for progress bar
    return $self;

  } elsif ($args{-radio}) {
    # Radio buttons

    for my $v (@{$args{-radio}}) {

      if (not ref($v)) {
        $win_r->{$area}
            -> Frame()
            -> pack(-side => 'top', -expand => '1', -fill => 'both')
            -> Label(-text => $v, -justify => 'left')
            -> pack(-side => 'left');

      } elsif (ref($v) eq 'ARRAY') {
        my $a = $area . $no++;
        $win_r->{$a} = $win_r->{$area}
            -> Frame(-bd => '2', -relief => 'sunken')
            -> pack(-side => 'top', -expand => '1', -fill => 'both');
        $win_r->{$a}
            -> Label(-text => shift(@$v), -justify => 'left')
            -> pack(-side => 'left');
        my $r = shift(@$v);
        for my $b (@$v) {
          my $w = $win_r->{$a}
              -> Radiobutton(-text     => $b->[1],
                             -variable => $r,
                             -value    => $b->[0],
                            );
          if (ref($b->[2])) {
            $w -> pack(%{$b->[2]});
          } else {
            $w -> pack(-side => 'left');
          } # if #

        } # for #
        
      } # if #

    } # for #

  } else {
    $win_r->{error}
        -> Frame(-bd => '2', -relief => 'sunken')
        -> pack(-side => 'top', -expand => '1', -fill => 'both')
        -> Label(-text => 'ERROR: Okänd layout', -justify => 'left')
        -> pack(-side => 'left');
  } # if #

  ### Button ###
  $win_r->{pp_butt} = $win_r->{button_area}
      -> Frame()
      -> pack(-side => 'top', -padx => 5, -pady => 5);

  if ($args{-buttons}) {
    # Advanced buttons
    my $no = 0;
    # Remaining buttons
    while (@{$args{-buttons}}) {
      my $b = shift(@{$args{-buttons}});
      my $key = 'button_action_' . $no;
      $self->{'win_confirm_button_' . $no} = $win_r->{pp_butt}
           -> Button( -text => $b, -command => [$self => 'withdraw', $key])
           -> pack(-side => 'right');
      $self->{$key} = shift(@{$args{-buttons}});
      $no++;
    } # while #

  } elsif ($args{-action}) {

    # No button
    $self->{win_confirm_no} = $win_r->{pp_butt}
         -> Button( -text => 'Nej', -command => [$self => 'withdraw'])
         -> pack(-side => 'right');
    $self->{done} = $args{-reject};

    # Yes button
    $self->{win_confirm_button_yes} = $win_r->{pp_butt}
         -> Button( -text => 'Ja', -command => [$self => 'withdraw', 'action'])
         -> pack(-side => 'right');
    $self->{action} = $args{-action};

  } else {
    # One button, Close button
    $self->{win_confirm_no} = $win_r->{pp_butt}
         -> Button( -text => 'Stäng', -command => [$self => 'withdraw'])
         -> pack(-side => 'right');
    $self->{done} = $args{-done};
    $self->{action} = undef;

  } # if #


  return $self;
} # Method _display

#----------------------------------------------------------------------------
#
# Method:      step_progress_bar
#
# Description: Step percentage and update progress bar
#              Default step 1%
#              Positive: Step bar value percentage
#              Negative: sets to - value
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Step 1-99, negative => set to percentage
# Returns:
#  - Value of progress, 0-100

sub step_progress_bar($;$) {
  # parameters
  my $self = shift;
  my ($step) = @_;

  $step = 1
      unless (defined($step));

  my $win_r = $self->{win};
  my $wg = $win_r->{progress_bar};
  my $value;
  if ($step > 0) {
    $value = $wg->value() + $step;
  } else {
    $value=-$step;
  } # if #
  $wg->value($value);
  $win_r->{progress_procent}->configure(-text => $value . '% klart');
  # Make the change in GUI visible
  $self->{erefs}{-parent_win}{win} -> update();
  return $value;

  return 0;
} # Method step_progress_bar

1;
__END__
