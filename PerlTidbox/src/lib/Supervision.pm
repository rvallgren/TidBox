#
package Supervision;
#
#   Document: Supervision class
#   Version:  1.4   Created: 2015-09-29 15:23
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Supervision.pmx
#

my $VERSION = '1.4';
my $DATEVER = '2015-09-29';

# History information:
#
# 1.0  2007-06-30  Roland Vallgren
#      First issue.
# 1.1  2008-06-16  Roland Vallgren
#      Use status field to report calculate problems
# 1.2  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.3  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
# 1.4  2015-09-16  Roland Vallgren
#      Fault handling aligned with Settings in edit
#      Times::getSortedRefs does join
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base FileBase;

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


use constant FILENAME  => 'supervision.dat';
use constant FILEKEY   => 'SUPERVISION SETTINGS';
use constant SAVEKEYS  => qw(sup_enable start_date sup_event);

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create supervision object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
                 condensed =>   0,
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);


  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all times data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  $self->{sup_enable} =  0;
  $self->{start_date} = '';
  $self->{sup_event}  = '';
  $self->{start}      =  0;
  $self->{date}       = '0';
  $self->{event}      = '';

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load supervision data
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  while (defined(my $line = $fh->getline())) {
    $self->{$1} = $2
        if ($line =~ /^(\w+)=(.+?)\s*$/);

  } # while #

  return 1;
} # Method load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save supervision data
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _save($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  for my $key (SAVEKEYS) {
    $fh->print($key, '=', $self->{$key}, "\n");
  } # for #

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      importData
#
# Description: Put imported supervision data
#
# Arguments:
#  - Object reference
#  - Enable
#  - Date
#  - Event data
# Returns:
#  -

sub importData($$$$) {
  # parameters
  my $self = shift;
  my ($enable, $date, $event) = @_;

  $self->{sup_enable} = $enable;
  $self->{start_date} = $date;
  $self->{sup_event}  = $event;
  $self->dirty();
  return 0;
} # Method importData

#----------------------------------------------------------------------------
#
# Method:      startAuto
#
# Description: Start autosave timer
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub startAuto($) {
  # parameters
  my $self = shift;


  # . Subscribe to updated event data
  $self->{-times}->setDisplay('Supervision', [$self, 'updated']);

  $self->SUPER::startAuto();

  return 1;
} # Method startAuto

#----------------------------------------------------------------------------
#
# Method:      _day
#
# Description: Calculate for one day
#
# Arguments:
#  0 - Object reference
#  1 - Date
# Returns:
#  Time in minutes

sub _day($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


    my $day_r = $self->{-calculate}->
        dayWorkTimes($date, $self->{condensed}, $self->{-error_popup});

    return 0
        unless exists $day_r->{activities};
    return 0
        unless exists $day_r->{activities}{$self->{event}};

    return $day_r->{activities}{$self->{event}};
} # Method _day

#----------------------------------------------------------------------------
#
# Method:      clear
#
# Description: Clear the ongoing supervision
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub clear($) {
  # parameters
  my $self = shift;

  $self->{date} = '';
  return 0;
} # Method clear

#----------------------------------------------------------------------------
#
# Method:      is
#
# Description: Is event supervised
#
# Arguments:
#  0 - Object reference
#  1 - Event
# Returns:
#  -

sub is($$) {
  # parameters
  my $self = shift;
  my ($event) = @_;

  return ($self->{sup_enable} and $self->{event} eq $event);
} # Method is

#----------------------------------------------------------------------------
#
# Method:      calc
#
# Description: Calculate event time from today until startdate
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - Resulting time in minutes
#  1 - Event text

sub calc($) {
  # parameters
  my $self = shift;


  my $today = $self->{-clock}->getDate();

  return ($self->{yesterday} + $self->_day($today), $self->{event})
      if ($self->{date} eq $today);

  # Add time from yesterday back until startdate
  my $start   = $self->{start};
  my $checked = 0;
  my $time    = 0;

  for my $ref (reverse(
       $self->{-times}->getSortedRefs($DATE, $TIME, $BEGINEVENT, $self->{event})
    ))
  {
    my $date = substr($$ref, 0, 10);

    next if $date eq $checked;
    next if $date ge $today;
    last if $date lt $start;

    $checked = $date;

    $time += $self->_day($date);

  } # for #

  $self->{yesterday} = $time;
  $self->{date} = $today;

  return ($self->{yesterday} + $self->_day($today), $self->{event});

} # Method calc

#----------------------------------------------------------------------------
#
# Method:      setup
#
# Description: Setup supervision
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub setup($) {
  # parameters
  my $self = shift;


  if ($self->{sup_enable})
  {
    $self->{start} = $self->{start_date};
    $self->{event} = $self->{sup_event};
  } else {
    $self->{start} = 0;
    $self->{event} = '';
  } # if #

  $self->{date} = '0';

  return 0;
} # Method setup

#----------------------------------------------------------------------------
#
# Method:      updated
#
# Description: Check if changed dates are in supervision range
#              and initiate an update if so
#
# Arguments:
#  0 - Object reference
#    1 .. n - Dates impacted by the update
#    1, 2, 3 - '-', d1, d2 Range of dates impacted by the update
# Returns:
#  -

sub updated($@) {
  # parameters
  my $self = shift;
  my (@dates) = @_;


  return 0
      unless ($self->{start});
  return 0
      unless ($self->{date});
  return 0
      unless ($self->{-calculate}->
                 impactedDate(
                              [$self->{start},
                               $self->{-clock}->getDate()
                              ],
                              @dates
                             )
             );

  $self->{date} = 0;

  return 0;
} # Method updated

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

  $self->callback($self->{edit}{-notify});
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
  $self->{-event_cfg}->clearData($edit_r);
  $edit_r->{time_area}->clear();

  # No supervision ongoing
  delete($self->{cfg}{supervision});

  $self->callback($edit_r->{-notify});

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

  $self->{-event_cfg}->putData($self->{edit}, $$ref);
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

  # Copy supervision settings
  for my $key (SAVEKEYS) {
    $self->{$key} = $self->{edit}{$key};
  } # for #
  $self->setup();

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
      $self->{-event_cfg} -> getData($edit_r, $edit_r->{-invalid});

  return undef
      unless (defined($date) and $action_text);

  # Store event supervision configuration
  $self->{edit}{sup_event}  = $action_text;
  $self->{edit}{start_date} = $date;
  $self->{edit}{sup_enable} = $edit_r->{enabled};

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


  if ($self->{edit}{sup_event}) {
    $self->{-event_cfg} -> putData($self->{edit}, $self->{edit}{sup_event});
  } else {
    $self->{-event_cfg} -> clearData($self->{edit});
  } # if #

  $self->{edit}{time_area} -> set(undef, $self->{edit}{start_date});
  $self->{edit}{enabled} = $self->{edit}{sup_enable};

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
  my ($copy) = @_;


  # Copy supervision settings
  for my $key (SAVEKEYS) {
    $self->{edit}{$key} = $self->{$key};
  } # for #


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

  $self->{-earlier}->create($area, 'right', [$self => '_previous']);
  return 0;
} # Method _addButtons

#----------------------------------------------------------------------------
#
# Method:      setupEdit
#
# Description: Setup for supervision edit
#
# Arguments:
#  0 - Object reference
#  -area       Window where to add the configuration area
#  -modified   Callback for modified settings
#  -invalid    Callback for invalid date
# Returns:
#  -

sub setupEdit($%) {
  # parameters
  my $self = shift;
  my %opt = @_;


  # Setup and store notify reference
  my $edit_r = {-notify  => $opt{-modified},
                -invalid => $opt{-invalid} ,
                -area    => $opt{-area}    ,
                name     => 'Supervision'  ,
               };
  $self->{edit} = $edit_r;

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
      -> Checkbutton(-command  => [@{$opt{-modified}}],
                     -variable => \$edit_r->{enabled},
                     -onvalue  => 1,
                     -offvalue => 0)
      -> pack(-side => 'left');

  ### Event cfg ##
  $edit_r->{evbutt_area} = $self->{-event_cfg}
      -> createArea(-win      => $edit_r,
                    -area     => $edit_r->{set_area},
                    -validate => [$self => '_eventKey'],
                    -buttons  => [$self => '_addButtons'],
                    -iscfg    => 1,
                   );

  ## Startdate ##
  $edit_r->{date_area} = $edit_r->{set_area}
      -> Frame(-bd => '1', -relief => 'sunken')
      -> pack(-side => 'top', -expand => '1', -fill => 'both');
  $edit_r->{time_area} =
      new Gui::Time(
                    -area      => $edit_r->{date_area},
                    -calculate => $self->{-calculate},
                    -date      => 1,
                    -invalid   => $opt{-invalid},
                    -notify    => $opt{-modified},
                    -label     => 'Från och med dag:',
                   );

  ## Supervision enable / clear ##
  $edit_r->{buttons_area} = $edit_r->{set_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $edit_r->{clear} = $edit_r->{buttons_area}
      -> Button(-text => 'Rensa', -command => [$self => '_setupClear'])
      -> pack(-side => 'right');

  return 0;
} # Method setupEdit

1;
__END__
