#
package EventCfg;
#
#   Document: Event Configuration Data
#   Version:  2.6   Created: 2012-09-10 18:33
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: EventCfg.pmx
#

my $VERSION = '2.6';
my $DATEVER = '2012-09-10';

# History information:

# PA1  2006-07-22  Roland Vallgren
#      First issue.
# PA2  2006-10-27  Roland Vallgren
#      Corrected error in add and remove event cfg
# PA3  2006-11-18  Roland Vallgren
#      Radiobutton change is treated as text entry
#      Allow settings window to be withdrawn
# PA4  2006-11-27  Roland Vallgren
#      Update event cfg area in settings window
# PA5  2007-02-11  Roland Vallgren
#      Matching date uses constant
# PA6  2007-03-09  Roland Vallgren
#      Event cfg now show edit settings below the list
# 1.7  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
# 1.8  2007-06-17  Roland Vallgren
#      Date for event cfg is kept for event area
#      Allow radiobutton to be undef when cleared
# 1.9  2008-04-05  Roland Vallgren
#      Added archive handling
# 1.10  2008-07-01  Roland Vallgren
#       Added advanced radio button
# 2.0  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Use FileBase functions to save and load
# 2.1  2009-07-08  Roland Vallgren
#      Precompile regexp match string
# 2.2  2010-01-04  Roland Vallgren
#      New entry gets label "Ny" to avoid empty label.
# 2.3  2011-02-12  Roland Vallgren
#      "\r" and "\n" not allowed in text entry
#      Added quit to disable area
# 2.4  2011-06-02  Roland Vallgren
#      Corrected modifyArea to update date even though are not is replaced.
# 2.5  2012-08-19  Roland Vallgren
#      New method getEmpty returns an emty event, like clearData
# 2.6  2012-09-10  Roland Vallgren
#      Not allowed to change event cfg for locked weeks
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

use Tk;
use Tk::LabFrame;

use Gui::Time;

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


# Edit settings field width
use constant EDIT_WIDTH => '20';

# Event configuration: Default
use constant EVENT_START => '0000-00-00';

my %EVENT_CFG = (
    COPERNICUS => [ 'Proj:w:8',
                    'Typ:d:4',
                    'Art:r:-;+;Ö;KÖ;Res',
                    'Not:.:24',
                  ],
    ENKEL => [ 'Aktivitet:.:24',
             ],
    TERP => [ 'Project:d:6',
              'Task:D:6',
              'Type:R:' .
                'N'  . '=>'. 'Normal -SE'                          . ';' .
                'F+' . '=>'. 'Normal /flex -SE'                    . ';' .
                'Ö+' . '=>'. 'Overtime Single /saved -SE-Overtime' . ';' .
                'Res'. '=>'. 'Travelling I /paid -SE-Overtime'     . ';' .
                'F-' . '=>'. 'Normal /used flex timi -SE'          . ';' .
                'Ö-' . '=>'. 'Compensation for Overtime -SE'       . ';' .
                'Sem'. '=>'. 'Vacation -SE'                                ,
              'Details:.:24',
            ],
                );

# Event types definitions
#   Key:   Typ selection, stored in times.dat
#   Value: Reference to array with "Regexp", "Description", "Sort order"
my %types_def = (
                  A  => [ '[A-ZÅÄÖ]'        , 'Versaler (A-Ö)'           , 1 ],
                  a  => [ '[a-zåäöA-ZÅÄÖ]'  , 'Alfabetiska (a-öA-Ö)'     , 2 ],
                  w  => [ '\\w'             , 'Alfanumerisk (a-ö0-9_)'   , 3 ],
                  W  => [ '[^,\n\r]'        , 'Text (ej ,)'              , 4 ],
                  d  => [ '\\d'             , 'Siffror (0-9)'            , 5 ],
                  D  => [ '[\\d\\.\\+\\-]'  , 'Numeriska (0-9.+-)'       , 6 ],
                  r  => [ '[^,\n\r]'        , 'Radioknapp'               , 7 ],
                  R  => [ '[^,\n\r]'        , 'Radioknapp översätt'      , 8 ],
                 '.' => [ '[^\n\r]'         , 'Fritext'                  , 9 ],
                );

use constant FILENAME  => 'eventcfg.dat';
use constant FILEKEY   => 'EVENT CONFIGURATION';

#############################################################################
#
# Function section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Function:    _text_strings
#
# Description: Create the event text strings
#
# Arguments:
#  0 - Reference to event configuration array
# Returns:
# A reference to an array with one hash of settings per event configuration
#  0 - Label
#  1 - Type definition
#  2 - Size or radio button values
#  3 - Event cfg text key
#  4 - Event cfg data key
#  5 - Event cfg radio key

sub _text_strings($) {
  my ($cfg_r) = @_;

  my $list = [];
  my $num = 0;
  for my $ev_st (@$cfg_r) {
    my ($text, $type, $sz_values) = split(':', $ev_st);
    $sz_values = [split(';', $sz_values)] if ($type eq 'r');
    $sz_values = [split(';', $sz_values)] if ($type eq 'R');
    push  @$list, { -text        => $text,
                    -type        => $type,
                    -sz_values   => $sz_values,
                    -cfgev_text  => 'cfgevtx_' . $num,
                    -cfgev_data  => 'cfgevdt_' . $num,
                    -cfgev_radio => 'cfgevrd_' . $num,
                  };
    $num++;
  } # for #

  return $list
} # sub _text_strings

#----------------------------------------------------------------------------
#
# Function:    _split_data
#
# Description: Split event data for presentation in text window
#
# Arguments:
#  0 - Reference to configuration strings data to split for
#  1 - Event to split
# Optional Arguments:
#  2 - Relaxed type check
# Returns:
#  List with split data for presentation

sub _split_data($$;$) {
  # parameters
  my ($str_r, $event, $nocheck) = @_;


  my @event_datas;

  $event = ''
      unless (defined($event));

  for my $ev_r (@{$str_r}) {

    if ($ev_r->{-type} ne '.') {
      if (($nocheck and $event =~ /^([^,]*),(.*)$/) or
          ($event =~ /^($types_def{$ev_r->{-type}}[0]*),?(.*)$/)
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
# Function:    _get_cfg_date
#
# Description: Get configuration for date
#
# Arguments:
#  0 - Reference to object hash
# Optional arguments:
#  1 - Date
# Returns:
#  Reference to cfg array for date

sub _get_cfg_date($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;



  unless ($date and
          ($date lt $self->{date}) and
           exists($self->{earlier})
         ) {
    return ($self->{cfg}, $self->{str}) if wantarray();
    return $self->{cfg};
  } # unless #

  my $found = EVENT_START;
  for my $d (sort(keys(%{$self->{earlier}}))) {
    last if $d gt $date;
    $found = $d;
  } # for #

  return ($self->{earlier}{$found}, $self->{strings}{$found})
     if wantarray();
  return $self->{earlier}{$found};

} # sub _get_cfg_date

#----------------------------------------------------------------------------
#
# Function:    _chg_state
#
# Description: Check if settings is allowed or differs and
#              set state of buttons
#
# Arguments:
#  0 - Reference to edit hash
# Returns:
#  -

sub _chg_state($) {
  # parameters
  my ($ref) = @_;

  if ($ref->{size_OK}  and
      $ref->{label_OK} and
       (
         $ref->{label_proposed} ne $ref->{ev_ref}{text}
         or
         $ref->{type_edit_type_var} ne $ref->{ev_ref}{type}
         or
         (
           ( lc($ref->{type_edit_type_var}) eq 'r' and
             $ref->{size_proposed} ne $ref->{ev_ref}{sz_values} )
           or
           ( lc($ref->{type_edit_type_var}) ne 'r' and
             $ref->{size_proposed} != $ref->{ev_ref}{sz_values} )
         )
         or
         $ref->{type_edit_type_var} ne $ref->{ev_ref}{type}
       )
     ) {
    $ref->{button_set} -> configure(-state => 'normal');
    $ref->{change} = 1;
  } else {
    $ref->{button_set} -> configure(-state => 'disabled');
    $ref->{change} = 0;
  } # if #

  return 0;
} # sub _chg_state

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      _replace_area
#
# Description: Replace event configuration area
#              The area is created if it does not exist
#
# Arguments:
#  0 - Object reference
#  1 - Reference to hash for event configuration area
# Returns:
#  The last created area

sub _replace_area($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;


  # Create an event configuration display area unless it exists
  $ref->{cfg_area} = $ref->{area}
        -> Frame()
        -> pack(-side => 'top', -expand => '1', -fill => 'both')
      unless Exists($ref->{cfg_area});

  # Destroy previous contents of the event configuration area if it exists
  $ref->{cfgev_area}->destroy() if (Exists($ref->{cfgev_area}));

  # OK, now we create a new one....
  $ref->{cfgev_area} = $ref->{cfg_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  # .... and fill it up
  my $first_area = $ref->{cfgev_area}
      -> Frame(-bd => '1', -relief => 'sunken')
      -> pack(-side => 'top', -expand => '1', -fill => 'both');
  my $last_area = $first_area;

  for my $ev_r (@{$ref->{str}}) {

    if (lc($ev_r->{-type}) ne 'r') {

      $ref->{$ev_r->{-cfgev_text}} = $first_area
            -> Label(-text => $ev_r->{-text} . ':')
            -> pack(-side => 'left' );

      $ref->{$ev_r->{-cfgev_data}} = $first_area
            -> Entry(-width           => $ev_r->{-sz_values},
                     -validate        => 'key',
                     -validatecommand => $ref->{validate})
             ->pack(-side => 'left');

      $ref->{$ev_r->{-cfgev_data}} -> bind('<Return>' => $ref->{return})
          if ($ref->{return});

    } else {

      $ref->{$ev_r->{-cfgev_data}} = [];

      $ref->{cfgev_radio_area} = $ref->{cfgev_area}
          -> Frame(-bd => '1', -relief => 'sunken')
          -> pack(-side => 'top', -expand => '1', -fill => 'both');

      $ref->{$ev_r->{-cfgev_text}} =
          $ref->{cfgev_radio_area}
                     -> Label(-text => $ev_r->{-text} . ':')
                     -> pack(-side => 'left' );

      $last_area = $ref->{cfgev_radio_area}
          -> Frame()
          -> pack(-side => 'top', -expand => '1', -fill => 'both');

      my $reset;
      for my $radio (@{$ev_r->{-sz_values}}) {

        if ($radio) {

          my ($l, $r) = ($radio, $radio);
          ($l, $r) = split(/=>/, $radio)
              if ($ev_r->{-type} eq 'R');

          unless ($reset) {
            $ref->{$ev_r->{-cfgev_radio}} = $r;
            $reset = 1;
          } # unless #

          push(@{$ref->{$ev_r->{-cfgev_data}}},
                $last_area
                    -> Radiobutton(-text => $l,
                                   -variable => \$ref->{$ev_r->{-cfgev_radio}},
                                   -value => $r,
                                   -command => $ref->{validate},
                                  )
                    -> pack(-side=>'left' )
              );

        } else {
          $last_area = $ref->{cfgev_radio_area}
              -> Frame()
              -> pack(-side => 'top', -expand => '1', -fill => 'both');
        } # if #
      } # for #

    } # if #
  } # for #

  $self->callback($ref->{buttons}, $last_area);

  return $last_area;
} # Method _replace_area

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create new event configuration data
#              If used in an archive set slightly limitied
#
# Arguments:
#  0 - Object prototype
# Optional arguments hash:
#  -archive - Start date for archive set
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;
  my %args = @_;
  my $self;

  unless ($args{-archive}) {

    $self = {
             areas => {},
            };

    bless($self, $class);

    $self->init(FILENAME, FILEKEY);

  } else {
    $self = {archive    => $args{-archive}  ,
             -cfg       => $args{-cfg}      ,
             -calculate => $args{-calculate},
             -clock     => $args{-clock}    ,
            };

    bless($self, $class);

    $self->init(undef, FILEKEY);

  } # unless #

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      strings
#
# Description: Add event configuration data strings
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub strings($) {
  # parameters
  my $self = shift;

  $self->{str} = _text_strings($self->{cfg});
  for my $key (%{$self->{earlier}}) {
    $self->{strings}{$key} = _text_strings($self->{earlier}{$key});
  } # for #

  return 0;
} # Method strings

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all event configuration data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  $self->{date} = EVENT_START;
  @{$self->{cfg}} = @{$EVENT_CFG{TERP}};
  %{$self->{earlier}} = ()
      if (exists($self->{earlier}));
  $self->strings();

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load event configuration
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle to load from
# Returns:
#  0 = Success

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->loadDatedSets($fh, 'cfg');

  $self->strings();

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save event cfg data to file
#
# Arguments:
#  0 - Object reference
#  1 - Filehandle
# Returns:
#  -

sub _save($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->saveDatedSets($fh, 'cfg');

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      importData
#
# Description: Put imported event configuration data
#
# Arguments:
#  - Object reference
#  - Date
#  - Reference to event cfg data
# Returns:
#  -

sub importData($$$) {
  # parameters
  my $self = shift;
  my ($date, $cfg_r) = @_;


  $self->addSet('cfg', $cfg_r, $date);
  $self->dirty();

  return 0;
} # Method importData

#----------------------------------------------------------------------------
#
# Method:      move
#
# Description: Move event configuration to an event cfg object
#              If no last date is specified all data is moved
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event configuration object to move to
# Optional Arguments:
#  2 - Last date of to move
# Returns:
#  -

sub move($$;$) {
  # parameters
  my $self = shift;
  my ($target, $last_date) = @_;


  if (not defined($last_date) or ($last_date ge $self->{date})) {

    # Move all data or up to date to move is later than actual
    # event configuration date

    #   Archive all earlier data and clear earlier
    for my $date (keys(%{$self->{earlier}})) {
      $target->addSet('cfg', $self->{earlier}{$date}, $date);
    } # for #

    #   Copy actual data to target set and update date
    $target->addSet('cfg', [ @{$self->{cfg}} ], $self->{date});

    # Clear earlier data
    %{$self->{earlier}} = ();

    # Do we really need to clear this?
    %{$self->{strings}} = ();

    if (defined($last_date)) {
      $self->{date} = $last_date;
      $self->{strings}{$last_date} = _text_strings($self->{cfg});

    } else {
      @{$self->{cfg}} = ();

    } # if #

  } else {

    # Archive and clear all data before last date
    my $cfg_r;
    for my $date (sort(keys(%{$self->{earlier}}))) {
      if ($last_date ge $date) {
        $cfg_r = $self->{earlier}{$date};
        $target->addSet('cfg', $cfg_r, $date);
        delete($self->{earlier}{$date});

        # Do we really need to clear this?
        delete($self->{strings}{$date});
      } # if #
    } # for #

    # Copy last data and set date to last date
    $self->{earlier}{$last_date} = [ @$cfg_r ];
    $self->{strings}{$last_date} = _text_strings($cfg_r);

  } # if #

  $self   -> dirty();
  $target -> dirty();

  return 0;
} # Method move

#----------------------------------------------------------------------------
#
# Method:      getNum
#
# Description: Get number of configuration data
#              If a date is specified the configuration data for that day
#              is returned
#
# Arguments:
#  0 - Object reference
# Optional arguments:
#  1 - Date to get for
# Returns:
#  Length of array in scalar mode

sub getNum($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  my $cfg_r = _get_cfg_date($self, $date);

  return scalar(@{$cfg_r});
} # Method getNum

#----------------------------------------------------------------------------
#
# Method:      labelKey
#
# Description: Only alphanumerical (\w) characters allowed
#
# Arguments:
#  0 - Object reference
# Arguments as received from the validation callback:
#  0 - The proposed value of the entry.
#  1 - The characters to be added (or deleted).
#  2 - The current value of entry i.e. before the proposed change.
#  3 - Index of char string to be added/deleted, if any. -1 otherwise
#  4 - Type of action. 1 == INSERT, 0 == DELETE, -1 if it's a forced
# Returns:
#  0 - True or false, An acceptable character received

sub labelKey($;@) {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;


  my $ref = $self->{edit};

  return 1 unless (ref($ref->{ev_ref}));

  return 0 if ($insert and ($proposed !~ /^\w*$/));
  if (length($proposed) and $proposed) {
    $ref->{label_OK} = 1;
    $ref->{label_proposed} = $proposed;
  } else {
    $ref->{label_OK} = 0;
  } # if #
  _chg_state($ref);
  return 1;
} # Method labelKey

#----------------------------------------------------------------------------
#
# Method:      sizeKey
#
# Description: Evaluate a key setting size or radiobutton entry
#              Size: only one or two digit numbers are accepted
#              Radiobutton: Only a valid radiobutton string is accepted
#
# Arguments:
#  0 - Object reference
# Arguments as received from the validation callback:
#  0 - The proposed value of the entry.
#  1 - The characters to be added (or deleted).
#  2 - The current value of entry i.e. before the proposed change.
#  3 - Index of char string to be added/deleted, if any. -1 otherwise
#  4 - Type of action. 1 == INSERT, 0 == DELETE, -1 if it's a forced
# Returns:
#  0 - True or false, An acceptable character received

sub sizeKey($;@) {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;


  my $ref = $self->{edit};

  return 1 unless (ref($ref->{ev_ref}));

  if (lc($ref->{type_edit_type_var}) ne 'r') {
    # Size entry
    return 0 if ($insert and ($proposed !~ /^\d*$/) or (length($proposed) > 2));
    if (length($proposed) and $proposed) {
      $ref->{size_OK} = 1;
      $ref->{size_proposed} = $proposed;
    } else {
      $ref->{size_OK} = 0;
    } # if #
    _chg_state($ref);
    return 1;

  } else {
    # Radio button entry
    return 0
        if ($insert and ($proposed !~ /^[^,:]*$/));

    if (($proposed =~ m/^[^\r\n]+$/)     and
        (index($proposed, ';;;') lt 0)   and
        (substr($proposed, 0, 1) ne ';') and
        (substr($proposed, -1)   ne ';')
       ) {

      my $ok = 1;
      if ($ref->{type_edit_type_var} eq 'R') {
        for my $t (split(';', $proposed)) {
          next
              unless $t;
          my $i = index($t, '=>');
          $ok = 0
              unless ($i > 0 and $i < length($t) - 2);

        } # for #
      } # if #

      $ref->{size_OK} = $ok;
      $ref->{size_proposed} = $proposed
          if $ok;
    } else {
      $ref->{size_OK} = 0;
    } # if #
    _chg_state($ref);
    return 1;

  } # if #

  return 0;
} # Method sizeKey

#----------------------------------------------------------------------------
#
# Method:      showType
#
# Description: Show selected type
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub showType($) {
  # parameters
  my $self = shift;

  my $ref = $self->{edit};

  $ref -> {type_edit_menu_but}
       -> configure(-text => $types_def{$ref->{type_edit_type_var}}[1]);

  if ($ref->{type_edit_type_var} ne $ref->{ev_ref}{type} and
      (lc($ref->{type_edit_type_var}) eq 'r' or
       lc($ref->{ev_ref}{type})       eq 'r'
      )
     )
  {
    $ref->{size_edit_entry} -> delete(0, 'end');
    if (lc($ref->{type_edit_type_var}) ne 'r') {
      $ref->{size_edit_entry} -> configure(-justify => 'right');
      $ref->{size_edit_entry} -> configure(-width => EDIT_WIDTH);
      $ref->{size_edit_frame} -> configure(-label => 'Bredd:');
    } else {
      $ref->{size_edit_entry} -> configure(-justify => 'left');
      $ref->{size_edit_entry} -> configure(-width => 30);
      $ref->{size_edit_frame} -> configure(-label => 'Värden:');
    } # if #
    $ref->{size_OK} = 0;
  } # if #

  _chg_state($ref);

  return 0;
} # Method showType

#----------------------------------------------------------------------------
#
# Method:      display
#
# Description: Display data for an entry
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Activate entry
# Returns:
#  -

sub display($;$) {
  # parameters
  my $self = shift;
  my ($display) = @_;


  my $ref = $self->{edit};

  $ref->{edit_list_box}->selectionSet($display) if (defined($display));

  my $cur_selection = $ref->{edit_list_box}->curselection();
  $cur_selection = $cur_selection->[0] if ref($cur_selection);

  if (defined($cur_selection)) {
    $ref->{edit_line_ref} = $ref->{edit_list_box}->get($cur_selection);
    my $ev_ref = $ref->{edit_list_refs}{$ref->{edit_line_ref}};

    # Signal validation routine "sizeKey" to accept any input
    $ref->{ev_ref} = undef;

    # Label setting
    $ref->{label_edit_entry} -> configure(-state => 'normal');
    $ref->{label_edit_entry} -> delete(0, 'end');
    $ref->{label_edit_entry} -> insert(0, $ev_ref->{text});
    $ref->{label_proposed} = $ev_ref->{text};
    $ref->{label_OK}       = 1;

    # Type setting
    $ref->{type_edit_menu_but}
        -> configure(-text => $ev_ref->{type_desc}, -state => 'normal');
    $ref->{type_edit_type_var} = $ev_ref->{type};
    $ref->{type_edit_menu} ->
        entryconfigure('end',
            -state => ($cur_selection < $#{$ref->{cfg}}) ? 'disabled' : 'normal'
                       );

    # Size or radiobutton values setting
    $ref->{size_edit_entry} -> configure(-state => 'normal');
    $ref->{size_edit_entry} -> delete(0, 'end');
    $ref->{size_edit_entry} -> insert(0, $ev_ref->{sz_values});
    if (lc($ev_ref->{type}) ne 'r') {
      $ref->{size_edit_entry} -> configure(-justify => 'right');
      $ref->{size_edit_frame} -> configure(-label => 'Bredd:');
    } else {
      $ref->{size_edit_entry} -> configure(-justify => 'left');
      $ref->{size_edit_frame} -> configure(-label => 'Värden:');
    } # if #
    $ref->{size_edit_entry} -> configure(
       -width => (length($ev_ref->{sz_values}) > EDIT_WIDTH) ?
                 (length($ev_ref->{sz_values}))  :
                  EDIT_WIDTH);
    $ref->{size_proposed} = $ev_ref->{sz_values};
    $ref->{size_OK}       = 1;

    # Change button setting
    $ref->{button_set} -> configure(-state => 'disabled');
    $ref->{button_add} -> configure(-state => 'normal');
    if ($cur_selection < $#{$ref->{cfg}}) {
      $ref->{button_remove} -> configure(-state => 'normal');
    } else {
      $ref->{button_remove} -> configure(-state => 'disabled');
    } # if #

    $ref->{ev_ref} = $ev_ref;
  } # if #

  return 0;
} # Method display

#----------------------------------------------------------------------------
#
# Method:      update
#
# Description: Update the settings list
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Activate entry
# Returns:
#  -

sub update($;$) {
  # parameters
  my $self = shift;
  my ($display) = @_;


  my $ref = $self->{edit};

  # Display event cfg entries in listbox

  if (exists($ref->{edit_list_refs})) {
    %{$ref->{edit_list_refs}} = ();
  } else {
    $ref->{edit_list_refs} = {};
  } # if #

  $ref->{edit_list_box}      -> delete(0, 'end');
  my $edit_list_refs = $ref->{edit_list_refs};
  for my $ev_st (@{$ref->{cfg}}) {
    my ($text, $type, $sz_values) = split(':', $ev_st);

    my $type_desc = '-';
    $type_desc = $types_def{$type}[1]
        if (exists($types_def{$type}));

    my $entry;
    if (lc($type) ne 'r') {
      $entry = sprintf('Etikett: %-10s  Typ: %-32s  Bredd: %2d',
                       $text, $type_desc, $sz_values);
    } else {
      $entry = sprintf('Etikett: %-10s  Typ: %-32s  Värden: %s',
                       $text, $type_desc, $sz_values);
    } # if #

    $ref->{ev_ref} = 0;
    $edit_list_refs->{$entry} = { ref => \$ev_st,
                                  text => $text,
                                  sz_values => $sz_values,
                                  type => $type,
                                  type_desc => $type_desc,
                                };
    $ref->{edit_list_box} -> insert("end", $entry);
  } # for #


  if (defined($display)) {
    $self->display($display);
  } else {
    $ref->{label_edit_entry}   -> delete(0, 'end');
    $ref->{label_edit_entry}   -> configure(-state => 'disabled');
    $ref->{size_edit_frame}    -> configure(-label => '');
    $ref->{size_edit_entry}    -> delete(0, 'end');
    $ref->{size_edit_entry}    -> configure(-width => EDIT_WIDTH, -state => 'disabled');
    $ref->{type_edit_menu_but} -> configure(-text => '-', -state => 'disabled');
    $ref->{button_set}         -> configure(-state => 'disabled');
    $ref->{button_add}         -> configure(-state => 'disabled');
    $ref->{button_remove}      -> configure(-state => 'disabled');
  } # if #


  return 0;
} # Method update

#----------------------------------------------------------------------------
#
# Method:      change
#
# Description: Change settings for an entry
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub change($) {
  # parameters
  my $self = shift;


  my $ref = $self->{edit};
  return 0 unless ($ref->{change});

  if (ref($ref->{ev_ref})) {
    my $ev_ref= $ref->{ev_ref};
    ${$ev_ref->{ref}} =
           $ref->{label_edit_entry} -> get() . ':' .
           $ref->{type_edit_type_var}        . ':' .
           $ref->{size_edit_entry}  -> get() ;
    $self->update();
    $ref->{button_add}     -> configure(-state => 'disabled');
    $ref->{button_remove}  -> configure(-state => 'disabled');
    $ref->{modified} = 2;
    $self->callback($ref->{notify});
  } # if #

  return 1;
} # Method change

#----------------------------------------------------------------------------
#
# Method:      add
#
# Description: add an entry
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub add($) {
  # parameters
  my $self = shift;


  my $ref = $self->{edit};

  my $index = $ref->{edit_list_box}->curselection();
  $index = $index->[0] if ref($index);

  @{$ref->{cfg}} = (@{$ref->{cfg}}[0 .. $index-1],
                    'Ny:A:6',
                    @{$ref->{cfg}}[$index .. $#{$ref->{cfg}}]);
  $self->update($index);

  return 0;
} # Method add

#----------------------------------------------------------------------------
#
# Method:      remove
#
# Description: Remove an entry
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub remove($) {
  # parameters
  my $self = shift;


  my $ref = $self->{edit};

  my $index = $ref->{edit_list_box}->curselection();
  $index = $index->[0] if ref($index);

  @{$ref->{cfg}} = (@{$ref->{cfg}}[0 .. $index-1],
                    @{$ref->{cfg}}[$index+1 .. $#{$ref->{cfg}}]);
  $ref->{modified} = 2;
  $self->callback($ref->{notify}, 'modified_event_cfg');
  $self->update();
  return 0;
} # Method remove

#----------------------------------------------------------------------------
#
# Method:      select
#
# Description: Select a default setting
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub select($) {
  # parameters
  my $self = shift;


  my $ref = $self->{edit};

  @{$ref->{cfg}} = @{$EVENT_CFG{$self->{defaults_selector}}};

  $ref->{modified} = 2;
  $self->callback($ref->{notify}, 'modified_event_cfg');
  $self->update();

  $self->{defaults_selector} = '';

  return 0;
} # Method select

#----------------------------------------------------------------------------
#
# Method:      apply
#
# Description: Apply new event configuration settings
#
# Arguments:
#  0 - Object reference
# Returns:
#  False if no changes were applied

sub apply($) {
  # parameters
  my $self = shift;


  my $ref = $self->{edit};

  return 0 unless ($ref->{modified});

  my $date = $ref->{week_no} -> get(1);

  return 0 unless $date;

  return 0
      if ($self->{-cfg}->isLocked($date, $self->{win_r}));

  $ref->{week_no} -> update(-min_date  => $date);

  if (($ref->{modified} > 1) and ($date gt $self->{date})) {
    $self->{earlier}{$self->{date}} = $self->{cfg};
    $self->{strings}{$self->{date}} = $self->{str};
    $self->{cfg} = [];
    $self->{date} = $date;
  } # if #
  @{$self->{cfg}} = @{$ref->{cfg}};
  $self->{str} = _text_strings($self->{cfg});

  for my $k (keys(%{$self->{areas}})) {
    my $r = $self->{areas}{$k};
    next unless (not $r->{date} or ($r->{date} ge $self->{date}));
    $r->{cfg} = $self->{cfg};
    $r->{str} = $self->{str};
    $self -> _replace_area($r);
  } # for #

  return $ref->{modified} - 1;
} # Method apply

#----------------------------------------------------------------------------
#
# Method:      showEdit
#
# Description: Show event configuration edit
#
# Arguments:
#  0 - Object reference
#  1 - Window where to add the configuration area
#  2 - Callback for modified settings
# Returns:
#  -

sub showEdit($$$) {
  # parameters
  my $self = shift;
  my ($win, $notify_r) = @_;


  # Copy event configuration
  @{$self->{edit}{cfg}} = @{$self->{cfg}};

  $self->update();
  $self->{edit}{week_no} -> set(undef, $self->{-clock}->getDate());

  return 0;
} # Method showEdit

#----------------------------------------------------------------------------
#
# Method:      setupEdit
#
# Description: Setup for event configuration edit
#
# Arguments:
#  0 - Object reference
#  -area       Window where to add the configuration area
#  -win_r      Window for message popup
#  -modified   Callback for modified settings
#  -invalid    Callback for invalid date
# Returns:
#  -

sub setupEdit($%) {
  # parameters
  my $self = shift;
  my %opt = @_;


  my $edit_r = {notify => $opt{-modified}};
  $self->{edit} = $edit_r;
  $self->{win_r} = $opt{-win_r};

  ## Event cfg edit area ##
  $edit_r->{set_area} =
      $opt{-area} -> Frame()
          -> pack(-side=>'top', -expand => '0', -fill=>'x');

  ### Listbox ###
  $edit_r->{list_edit_area} = $edit_r->{set_area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $edit_r->{edit_list_box} = $edit_r->{list_edit_area}
      -> Listbox(-width => 30,
                 -height => 5,
                 -exportselection => 0);
  $edit_r->{edit_list_box}
      -> pack(-side => 'left', -expand => '1', -fill => 'both');
  $edit_r->{edit_list_box} -> bind('<ButtonRelease-1>', [$self => 'display']);

  $edit_r->{edit_scrollbar} = $edit_r->{list_edit_area}
      -> Scrollbar(-command => ['yview', $edit_r->{edit_list_box}])
      -> pack(-side => 'left', -fill => 'y');

  $edit_r->{edit_list_box}
      -> configure(-yscrollcommand => ['set', $edit_r->{edit_scrollbar}]);

  ### Entry edit ###
  $edit_r->{entry_sec_area} = $edit_r->{set_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $edit_r->{entry_edit_area} = $edit_r->{entry_sec_area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'left');

  # Label text
  $edit_r->{label_edit_frame} = $edit_r->{entry_edit_area}
      -> LabFrame(-labelside => 'left',
                  -label => 'Etikett:',
                  -relief => 'flat')
      -> pack(-side => 'top', -fill => 'x');
  $edit_r->{label_edit_entry} = $edit_r->{label_edit_frame}
      -> Entry(-validate => 'key',
               -validatecommand => [labelKey => $self],
               -state    => 'disabled',)
      -> pack(-side => 'right');
  $edit_r->{label_edit_entry}
      -> bind('<Return>' => [$self => 'change']);

  # Type definition menu
  $edit_r->{type_edit_type_var} = '-';

  $edit_r->{type_edit_frame} = $edit_r->{entry_edit_area}
      -> LabFrame(-labelside => 'left',
                  -label  => 'Typ:',
                  -relief => 'flat')
      -> pack(-side => 'top', -fill => 'x');
  $edit_r->{type_edit_menu_but} = $edit_r->{type_edit_frame}
    -> Menubutton(-text   => '-',
                  -bd     => '1',
                  -relief => 'raised',
                  -state  => 'disabled',
                 )
    -> pack(-side => 'right');

  $edit_r->{type_edit_menu} = $edit_r->{type_edit_menu_but}
    -> Menu(-tearoff => "false");
  for my $key (sort
                {$types_def{$a}[2] <=> $types_def{$b}[2]}
                (keys(%types_def))
              ) {
    $edit_r->{type_edit_menu}
      -> add( 'radiobutton',
              -command     => [showType => $self],
              -label       => $types_def{$key}[1],
              -variable    => \$edit_r->{type_edit_type_var},
              -value       => $key,
              -indicatoron => 0,
            );
  } # for #

  # Disable free text entry
  $edit_r->{type_edit_menu} -> entryconfigure('end', -state => 'disabled');

  # Associate Menubutton with Menu.
  $edit_r->{type_edit_menu_but} -> configure(-menu => $edit_r->{type_edit_menu});

  # Size or radio button values
  $edit_r->{size_edit_frame} = $edit_r->{entry_edit_area}
      -> LabFrame(-labelside => 'left',
                  -relief => 'flat')
      -> pack(-side => 'top', -fill => 'x');
  $edit_r->{size_edit_entry} = $edit_r->{size_edit_frame}
      -> Entry(-validate => 'key',
               -validatecommand => [sizeKey => $self],
               -state    => 'disabled',
              )
      -> pack(-side => 'right');
  $edit_r->{size_edit_entry}
      -> bind('<Return>' => [$self => 'change']);


  # Defaults, Set, Add and Delete buttons
  $edit_r->{entry_button_area} = $edit_r->{entry_edit_area}
      -> Frame()
      -> pack(-side => 'bottom');

  $self->{defaults_selector} = '';
  ### Defaults menu button ###
  $edit_r->{defaults_but} = $edit_r->{entry_button_area}
      -> Menubutton(-text => 'Förslag', -bd => '2', -relief => 'raised')
      -> pack(-side => 'left');

  ### Defaults menu ###
  $edit_r->{defaults_menu} = $edit_r->{defaults_but}
      -> Menu(-tearoff => 'false');
  # Associate Menubutton with Menu.
  $edit_r->{defaults_but} -> configure(-menu => $edit_r->{defaults_menu});

  # Add menu contents
  for my $key (sort(keys(%EVENT_CFG))) {
    $edit_r->{defaults_menu}
        -> add('radiobutton',
               -command => [select => $self],
               -label => ucfirst(lc($key)),
               -variable => \$self->{defaults_selector},
               -value => $key,
               -indicatoron => 0
              );
  } # for #

  # Change, New and Remove buttons
  $edit_r->{button_set} = $edit_r->{entry_button_area}
      -> Button(-text => 'Ändra', -command => [change => $self])
      -> pack(-side => 'left');
  $edit_r->{button_add} = $edit_r->{entry_button_area}
      -> Button(-text => 'Lägg till', -command => [add => $self])
      -> pack(-side => 'left');
  $edit_r->{button_remove} = $edit_r->{entry_button_area}
      -> Button(-text => 'Ta bort', -command => [remove => $self])
      -> pack(-side => 'left');

  ### Start week ###
  $edit_r->{week_sec_area} = $edit_r->{set_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $edit_r->{week_area} = $edit_r->{week_sec_area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'left');

  $edit_r->{week_no} =
      new Gui::Time(
                    -area      => $edit_r->{week_area},
                    -calculate => $self -> {-calculate},
                    -week      => 1,
                    -invalid   => $opt{-invalid},
                    -notify    => $opt{-modified},
                    -label     => 'Från och med vecka:',
                    -max_date  => $self->{-calculate} ->
                                  dayInWeek($self->{-clock}->getYear(),
                                            $self->{-clock}->getWeek(), 7),
                    -min_date  => $self->{date},
                   );

  return 0;
} # Method setupEdit

#----------------------------------------------------------------------------
#
# Method:      modifyArea
#
# Description: Modify layout of existing event entry areas
#
# Arguments:
#  0 - Object reference
#  1 - Window reference
#  2 - Date
# Returns:
#  -

sub modifyArea($$$) {
  # parameters
  my $self = shift;
  my ($win_r, $date) = @_;


  my ($cfg_r, $str_r) = _get_cfg_date($self, $date);

  my $ref = $self->{areas}{$win_r->{name}};

  $ref->{date} = $date
      if ($ref->{date});
  return 0
      unless ($ref->{cfg} ne $cfg_r);

  $ref->{cfg}  = $cfg_r;
  $ref->{str}  = $str_r;
  $self -> _replace_area($ref);

  return 0;
} # Method modifyArea

#----------------------------------------------------------------------------
#
# Method:      createArea
#
# Description: Setup event entry area
#
# Arguments:
#  0 - Object reference
# Named Arguments:
#  -win      - Reference to window hash
#  -area     - Area were to add the event entry area
#  -validate - Reference to routine to validate entered text
# Optional Named Arguments:
#  -buttons  - Reference to routine to add event area buttons
#  -return   - Reference to routine when <Return> is pressed
#  -date     - Date for entry
#  -iscfg    - This is the configuration window
# Returns:
#  0 - Last created area

sub createArea($%) {
  # parameters
  my $self = shift;
  my %opt = @_;


  my ($cfg_r, $str_r) = _get_cfg_date($self, $opt{-date});

  my $name = $opt{-win}->{name};
  $self->{areas}{$name} =
     {cfg      => $cfg_r,
      str      => $str_r,
      window   => $opt{-win},
      area     => $opt{-area},
      validate => $opt{-validate},
      buttons  => $opt{-buttons},
      return   => $opt{-return},
      date     => $opt{-date},
      iscfg    => $opt{-iscfg},
     };

  $self->{cfg_name} = $name
      if ($opt{-iscfg});

  my $last_area = $self -> _replace_area($self->{areas}{$name});

  return $last_area;
} # Method createArea

#----------------------------------------------------------------------------
#
# Method:      quit
#
# Description: Quit, disable widgets
#
# Arguments:
#  0 - Object reference
#  1 - Name of window
#
# Returns:
#  -

sub quit($$) {
  # parameters
  my $self = shift;
  my ($name) =@_;

  my $ref = $self->{areas}{$name};

  for my $ev_r (@{$ref->{str}}) {

    if (lc($ev_r->{-type}) ne 'r') {
#      $ref->{$ev_r->{-cfgev_text}} -> configure(-state => 'disabled');
      $ref->{$ev_r->{-cfgev_data}} -> configure(-state => 'disabled');
    } else {
#      $ref->{$ev_r->{-cfgev_text}} -> configure(-state => 'disabled');
      for my $r (@{$ref->{$ev_r->{-cfgev_data}}}) {
        $r-> configure(-state => 'disabled');
      } # for #

    } # if #
  } # for #
  return 0;
} # Method quit

#----------------------------------------------------------------------------
#
# Method:      matchString
#
# Description: Create a regexp string for matching event configuration
#
# Arguments:
#  0 - Object reference
#  1 - Condense setting
# Optional Arguments:
#  1 - Date to get string for
# Returns:
#  0 - Event match regexp
#  1 - Adjusted condense setting, if too big

sub matchString($$;$) {
  # parameters
  my $self = shift;
  my ($condense, $date) = @_;


  my ($cfg_r, $str_r) = _get_cfg_date($self, $date);

  my $event_no;
  if ($#{$cfg_r} > $condense) {
    $event_no = @{$cfg_r} - $condense;
  } else {
    $event_no = 1;
    $condense = $#{$cfg_r};
  } # if #

  my $match_string = '(';
  for my $ev_r (@{$str_r}) {
    my $type = $ev_r->{-type};
    $match_string .= $types_def{$type}[0] . '*';
    last if ($type eq '.');

    $event_no--;
    $match_string .= ($event_no ? ',' : '),(' );
  } # for #
  $match_string .= ')';
  # And finally compile regexp
  $match_string = qr/^$match_string$/;

  return ($match_string, $condense) if wantarray();
  return $match_string;
} # Method matchString

#----------------------------------------------------------------------------
#
# Method:      clearData
#
# Description: Clear configured event data GUI
#
# Arguments:
#  0 - Object reference
#  1 - Reference to window hash
# Optional Arguments:
#  2 - Undef radiobuttons
# Returns:
#  -

sub clearData($$;$) {
  # parameters
  my $self = shift;
  my ($win_r, $c_rbt) = @_;


  my $ref   = $self->{areas}{$win_r->{name}};

  for my $ev_r (@{$ref->{str}}) {
    if (lc($ev_r->{-type}) ne 'r') {
      $ref->{$ev_r->{-cfgev_data}} -> delete(0, 'end');
    } elsif ($c_rbt) {
      $ref->{$ev_r->{-cfgev_radio}} = '';
    } elsif ($ev_r->{-type} eq 'R') {
      $ref->{$ev_r->{-cfgev_radio}} =
          substr($ev_r->{-sz_values}[0], index($ev_r->{-sz_values}[0], '=>')+2);
    } else {
      $ref->{$ev_r->{-cfgev_radio}} = $ev_r->{-sz_values}[0];
    } # if #
  } # for #
  return 0;
} # Method clearData

#----------------------------------------------------------------------------
#
# Method:      putData
#
# Description: Put event data in configured event GUI
#
# Arguments:
#  0 - Object reference
#  1 - Reference to window hash
#  2 - Event data string
# Optional Arguments:
#  3 - If true type check is relaxed
# Returns:
#  -

sub putData($$$;$) {
  # parameters
  my $self = shift;
  my ($win_r, $event_data, $nochk) = @_;


  my $ref   = $self->{areas}{$win_r->{name}};
  my $str_r = $ref->{str};

  my @event_datas = _split_data($str_r, $event_data, $nochk);

  for my $ev_r (@{$str_r}) {

    my $value = shift(@event_datas);

    if (lc($ev_r->{-type}) ne 'r') {
      $ref->{$ev_r->{-cfgev_data}} -> delete(0, 'end');
      $ref->{$ev_r->{-cfgev_data}} -> insert(0, $value);
    } else {
      $ref->{$ev_r->{-cfgev_radio}} = $value;
    } # if #
  } # for #
  return 0;
} # Method putData

#----------------------------------------------------------------------------
#
# Method:      getData
#
# Description: Get event data from configured event GUI
#
# Arguments:
#  0 - Object reference
#  1 - Reference to window hash
# Optional argument:
#  2 - Callback to show error message
#  3 - Date
# Returns scalar:
#  0 - Event data.
# Returns array:
#  0 - Lenght of text in event data
#  1 - Event data string

sub getData($$;$$) {
  # parameters
  my $self = shift;
  my ($win_r, $show_message_sub_r, $date) = @_;


  my $ref   = $self->{areas}{$win_r->{name}};

  my @event_datas;
  my $value;
  my $len = 0;

  for my $ev_r (@{$ref->{str}}) {
    my $type = $ev_r->{-type};
    if (lc($type) ne 'r') {

      $value = $ref->{$ev_r->{-cfgev_data}}->get();
      if (defined($show_message_sub_r) and
          ($value !~ /^$types_def{$type}[0]*$/)
         )
      {
        if ($self->{cfg_name} and
            ($win_r->{name} eq $self->{cfg_name})) {
          # Ignore faulty format due to changed event configuration
          return '';
        } else {
          $self->callback($show_message_sub_r,
                          'Ej tillåtet: ' . $ev_r->{-text} . ': ' . $value);
          return undef;
        } # if #
      } # if #
      $len += length($value);

    } else {

      $value = $ref->{$ev_r->{-cfgev_radio}};
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
} # Method getData

#----------------------------------------------------------------------------
#
# Method:      getEmpty
#
# Description: Get an empty data for today.
#              A comment may be provided.
#
# Arguments:
#  0 - Object reference
# Optional argument:
#  1 - Comment
# Returns scalar:
#  0 - Event data.

sub getEmpty($;$) {
  # parameters
  my $self = shift;
  my ($comment) = @_;



  my @values;
  my $r;
  for my $ev_r (@{$self->{str}}) {
    if (lc($ev_r->{-type}) ne 'r') {
      push @values, '';
    } elsif ($ev_r->{-type} eq 'R') {
      push @values, substr($ev_r->{-sz_values}[0], index($ev_r->{-sz_values}[0], '=>')+2);
    } else {
      push @values, $ev_r->{-sz_values}[0];
    } # if #
    $r = $ev_r;
  } # for #
  $values[$#values] = $comment
      if ($comment and lc($r->{-type}) ne 'r');

  return join(',', @values);
} # Method getEmpty

1;
__END__
