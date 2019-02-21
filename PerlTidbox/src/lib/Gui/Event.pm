#
package Gui::Event;
#
#   Document: Event entry area
#   Version:  1.3   Created: 2019-02-07 15:56
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Event.pmx
#

my $VERSION = '1.3';
my $DATEVER = '2019-02-07';

# History information:
#
# 1.3  2019-02-07  Roland Vallgren
#      Removed log->trace
# 1.2  2017-10-16  Roland Vallgren
#      References to other objects in own hash
# 1.1  2017-05-02  Roland Vallgren
#      Added get empty event => Already exists in EventCfg
# 1.0  2015-12-07  Roland Vallgren
#      Event Gui moved from EventCfg
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

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      _replace_area
#
# Description: Create an Event entry area
#              If a area already exists it is replaced
#              It is actually a replace that is done
#
# Arguments:
#  - Object reference
#  - Reference to cfg
#  - Reference to str
# Returns:
#  -

sub _replace_area($$$) {
  # parameters
  my $self = shift;
  my ($cfg_r, $str_r) = @_;


  $self->{cfg}  = $cfg_r;
  $self->{str}  = $str_r;

  # Create an event configuration display area unless it exists
  my $win_r = $self->{win};
  $win_r->{cfg_area} = $win_r->{area}
        -> Frame()
        -> pack(-side => 'top', -expand => '1', -fill => 'both')
      unless Exists($win_r->{cfg_area});

  # Destroy previous contents of the event configuration area if it exists
  $win_r->{cfgev_area}->destroy()
      if (Exists($win_r->{cfgev_area}));

  # OK, now we create a new one....
  $win_r->{cfgev_area} = $win_r->{cfg_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  # .... and fill it up
  my $first_area = $win_r->{cfgev_area}
      -> Frame(-bd => '1', -relief => 'sunken')
      -> pack(-side => 'top', -expand => '1', -fill => 'both');
  my $last_area = $first_area;

  for my $ev_r (@{$str_r}) {

    if (lc($ev_r->{-type}) ne 'r') {

      $win_r->{$ev_r->{-cfgev_text}} = $first_area
            -> Label(-text => $ev_r->{-text} . ':')
            -> pack(-side => 'left' );

      $win_r->{$ev_r->{-cfgev_data}} = $first_area
            -> Entry(-width           => $ev_r->{-sz_values},
                     -validate        => 'key',
                     -validatecommand => $self->{validate})
             ->pack(-side => 'left');

      $win_r->{$ev_r->{-cfgev_data}} -> bind('<Return>' => $self->{return})
          if ($self->{return});

    } else {

      $win_r->{$ev_r->{-cfgev_data}} = [];

      $win_r->{cfgev_radio_area} = $win_r->{cfgev_area}
          -> Frame(-bd => '1', -relief => 'sunken')
          -> pack(-side => 'top', -expand => '1', -fill => 'both');

      $win_r->{$ev_r->{-cfgev_text}} =
          $win_r->{cfgev_radio_area}
                     -> Label(-text => $ev_r->{-text} . ':')
                     -> pack(-side => 'left' );

      $last_area = $win_r->{cfgev_radio_area}
          -> Frame()
          -> pack(-side => 'top', -expand => '1', -fill => 'both');

      my $reset;
      for my $radio (@{$ev_r->{-sz_values}}) {

        if ($radio) {

          my ($l, $r) = ($radio, $radio);
          ($l, $r) = split(/=>/, $radio)
              if ($ev_r->{-type} eq 'R');

        unless ($reset) {
          $win_r->{$ev_r->{-cfgev_radio}} = $r;
          $reset = 1;
        } # unless #

        push(@{$win_r->{$ev_r->{-cfgev_data}}}, $last_area
              -> Radiobutton(-text => $l,
                             -variable => \$win_r->{$ev_r->{-cfgev_radio}},
                             -value => $r,
                             -command => $self->{validate},
                            )
              -> pack(-side=>'left' )
            );

        } else {
          $last_area = $win_r->{cfgev_radio_area}
              -> Frame()
              -> pack(-side => 'top', -expand => '1', -fill => 'both');
        } # if #
      } # for #

    } # if #
  } # for #

  $self->callback($self->{buttons}, $last_area);
  $self->{last_area} = $last_area;

  return 0;
} # Method _replace_area

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create an Event entry area
#
# Arguments:
#  0 - Object prototype
#  -event_cfg   Reference to event configuration
#  -parentName  Name of parent window
#  -area        Reference to parent frame
#  -validate    Routine to call to validate input ?
#  -buttons     Routine to call to add buttons to the area
#  -return      Routine to call when return is entered
#  -date        Optional date  for event entry other than today
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;
  my %opt = @_;

  my $win_r = {area => $opt{-area},
               name => $opt{-parentName} . 'EC',
              };

  my $self = {
              win        => $win_r,
              validate   => $opt{-validate},
              buttons    => $opt{-buttons},
              return     => $opt{-return},
              erefs      => $opt{erefs},
              date       => $opt{-date},
             };


  bless($self, $class);

  # Get event configuration information
  $self->{types_def}  = $self->{erefs}{-event_cfg}->getDefinition(),

  $self->{erefs}{-event_cfg}->setDisplay($win_r->{name},
                                         [$self, 'replaceArea']);

  $self->_replace_area($self->{erefs}{-event_cfg}->getEventCfg($opt{-date}));

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      modifyArea
#
# Description: Modify layout of existing event entry area to 
#              event configuration for specified date
#
# Arguments:
#  - Object reference
#  - Date
# Returns:
#  -

sub modifyArea($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  my ($cfg_r, $str_r) = $self->{erefs}{-event_cfg}->getEventCfg($date);

  $self->{date} = $date
      if ($self->{date});
  return 0
      unless ($self->{cfg} ne $cfg_r);

  $self->_replace_area($cfg_r, $str_r);

  return 0;
} # Method modifyArea

#----------------------------------------------------------------------------
#
# Method:      replaceArea
#
# Description: Replace area when event cfg is changed
#
# Arguments:
#  - Object reference
#  - Date
# Returns:
#  -

sub replaceArea($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  return 0
       unless (not $self->{date} or ($self->{date} ge $date));

  my ($cfg_r, $str_r) = $self->{erefs}{-event_cfg}->getEventCfg($date);

  $self->_replace_area($cfg_r, $str_r);

  return 0;
} # Method replaceArea

#----------------------------------------------------------------------------
#
# Method:      clear
#
# Description: Clear event entry
#
# Arguments:
#  - Object reference
# Optional argument:
#  - Clear radiobuttons
# Returns:
#  -

sub clear($;$) {
  # parameters
  my $self = shift;
  my ($c_rbt) = @_;

  my $win_r = $self->{win};

  for my $ev_r (@{$self->{str}}) {
    if (lc($ev_r->{-type}) ne 'r') {
      $win_r->{$ev_r->{-cfgev_data}} -> delete(0, 'end');
    } elsif ($c_rbt) {
      $win_r->{$ev_r->{-cfgev_radio}} = '';
    } elsif ($ev_r->{-type} eq 'R') {
      $win_r->{$ev_r->{-cfgev_radio}} =
          substr($ev_r->{-sz_values}[0], index($ev_r->{-sz_values}[0], '=>')+2);
    } else {
      $win_r->{$ev_r->{-cfgev_radio}} = $ev_r->{-sz_values}[0];
    } # if #
  } # for #
  return 0;
} # Method clear

#----------------------------------------------------------------------------
#
# Method:      get
#
# Description: Get event data
#
# Arguments:
#  - Object reference
# Optional argument:
#  - Callback to show error message
# Return:
#  Scalar:
#   - Event data
#  Array:
#   - Lenght of text in event data
#   - Event data string
#  

sub get($;$) {
  # parameters
  my $self = shift;
  my ($show_message_sub_r) = @_;

  my $win_r = $self->{win};

  my @event_datas;
  my $value;
  my $len = 0;

  for my $ev_r (@{$self->{str}}) {
    my $type = $ev_r->{-type};
    if (lc($type) ne 'r') {

      $value = $win_r->{$ev_r->{-cfgev_data}}->get();

      if (($type ne '.') and
           defined($show_message_sub_r) and
           ($value !~ /^$self->{types_def}{$type}[0]*$/)
         )
      {
          $self->callback($show_message_sub_r,
                          'Ej tillåtet: ' . $ev_r->{-text} . ': ' . $value);
          return undef;
      } # if #
      $len += length($value);

    } else {

      $value = $win_r->{$ev_r->{-cfgev_radio}};
      if (defined($show_message_sub_r) and
          ($value eq '')
         ) {
        $self->callback($show_message_sub_r,
                        'Ingen "' . $ev_r->{-text} . ':" vald');
        return undef;
      } # if #

    } # if #

    push @event_datas, $value;
  } # for #

  return ($len, join(',', @event_datas)) if wantarray();
  return join(',', @event_datas);
} # Method get

#----------------------------------------------------------------------------
#
# Method:    _split_data
#
# Description: Split event data for presentation in text window
#
# Arguments:
#  - Object reference
#  - Reference to configuration strings data to split for
# Optional Arguments:
#  - Event to split
#  - Relaxed type check
# Returns:
#  List with split data for presentation

sub _split_data($$;$$) {
  # parameters
  my $self = shift;
  my ($str_r, $event, $nocheck) = @_;


  my @event_datas;

  $event = ''
      unless (defined($event));

  for my $ev_r (@{$str_r}) {

    if ($ev_r->{-type} ne '.') {
      if (($nocheck and $event =~ /^([^,]*),(.*)$/) or
          ($event =~ /^($self->{types_def}{$ev_r->{-type}}[0]*),?(.*)$/)
         )
      {
        push @event_datas, $1;
        $event = $2;

      } else {
        # No match, add nothing and remove up to next ','
        push @event_datas, '';
        $event =~ s/^[^,]*,//;

      } # if #

    } else {
      push @event_datas, $event;
      $event = '';

    } # if #

  } # for #

  return @event_datas;
} # sub _split_data

#----------------------------------------------------------------------------
#
# Method:      set
#
# Description: Set event data
#
# Arguments:
#  - Object reference
#  - Event data string
# Optional Arguments:
#  - If true type check is relaxed
# Returns:
#  -

sub set($$;$) {
  # parameters
  my $self = shift;
  my ($event_data, $nochk) = @_;

  my $win_r = $self->{win};

  my @event_datas = $self->_split_data($self->{str}, $event_data, $nochk);

  for my $ev_r (@{$self->{str}}) {

    my $value = shift(@event_datas);

    if (lc($ev_r->{-type}) ne 'r') {
      $win_r->{$ev_r->{-cfgev_data}} -> delete(0, 'end');
      $win_r->{$ev_r->{-cfgev_data}} -> insert(0, $value);
    } else {
      $win_r->{$ev_r->{-cfgev_radio}} = $value;
    } # if #
  } # for #

} # Method set

#----------------------------------------------------------------------------
#
# Method:      getLastArea
#
# Description: Return last area, were buttons could be added
#
# Arguments:
#  - Object reference
# Return:
#  - Area
#  

sub getLastArea($) {
  # parameters
  my $self = shift;

  return $self->{last_area};
} # Method get

#----------------------------------------------------------------------------
#
# Method:      quit
#
# Description: Quit, disable widgets
#
# Arguments:
#  0 - Object reference
#
# Returns:
#  -

sub quit($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  for my $ev_r (@{$self->{str}}) {

    if (lc($ev_r->{-type}) ne 'r') {
#      $win_r->{$ev_r->{-cfgev_text}} -> configure(-state => 'disabled');
      $win_r->{$ev_r->{-cfgev_data}} -> configure(-state => 'disabled');
    } else {
#      $win_r->{$ev_r->{-cfgev_text}} -> configure(-state => 'disabled');
      for my $r (@{$win_r->{$ev_r->{-cfgev_data}}}) {
        $r-> configure(-state => 'disabled');
      } # for #

    } # if #
  } # for #
  return 0;
} # Method quit

1;
__END__
