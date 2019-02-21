#
package Gui::EventConfig;
#
#   Document: Event Configuration Gui
#   Version:  1.2   Created: 2019-02-13 21:26
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: EventConfig.pmx
#

my $VERSION = '1.2';
my $DATEVER = '2019-02-13';

# History information:

# 1.0  2015-12-09  Roland Vallgren
#      Event gui moved to own perl module
#      New cfg is not added if equal to previous
# 1.1  2017-05-02  Roland Vallgren
#      Update min week number when last event cfg is removed
# 1.2  2017-10-05  Roland Vallgren
#      Don't need FileBase
#      Renamed EventCfg::addCfg to EventCfg::addNewCfg
#      References to other objects in own hash
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
use Tk::LabFrame;
use Tk::TextUndo;

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

# Edit settings field width
use constant EDIT_WIDTH => '20';

#############################################################################
#
# Function section
#
#############################################################################

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

# TODO: How to detect changed radio button text?
  if (lc($ref->{type_edit_type_var}) eq 'r') {
    $ref->{button_set} -> configure(-state => 'normal');
    $ref->{change} = 1;
  } elsif ($ref->{size_OK}  and
           $ref->{label_OK} and
       (
         $ref->{label_proposed} ne $ref->{ev_ref}{text}
         or
         $ref->{type_edit_type_var} ne $ref->{ev_ref}{type}
         or
         (
           ( lc($ref->{type_edit_type_var}) eq 'r' )
           or
           ( lc($ref->{type_edit_type_var}) ne 'r' and
             $ref->{size_proposed} != $ref->{ev_ref}{sz_values} )
         )
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
# Method:      new
#
# Description: Create event configuration edit gui
#
# Arguments:
#  - Object prototype
# Optional arguments hash:
#  -area       Window where to add the configuration area
#  -modified   Callback for modified settings
#  -invalid    Callback for invalid date
#  -calculate  Reference to calcualtor
#  -clock                   clock
#  -cfg                     configuration
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;
  my %args = @_;
  my $self;

  my $edit_r = {notify => $args{-modified}};
  my $types_def = $args{erefs}{-event_cfg}->getDefinition();
  my $EVENT_CFG = $args{erefs}{-event_cfg}->getDefinition(1);

  $self = {
           edit  => $edit_r,
           erefs => $args{erefs},
           -invalid   => $args{-invalid},
           types_def  => $types_def,
           EVENT_CFG  => $EVENT_CFG,
           earlier_copy => {},
           earlier_index => {},
           earlier_removed => [],
           earlier_removed_was_last => undef,
           earlier_selector => undef,
          };

  bless($self, $class);

  ## Event cfg edit area ##
  $edit_r->{set_area} =
      $args{-area} -> Frame()
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
  $edit_r->{edit_list_box} -> bind('<<ListboxSelect>>' => [$self => 'display']);

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
    -> Menubutton(-text        => '-',
                  -borderwidth => '1',
                  -relief      => 'raised',
                  -state       => 'disabled',
                 )
    -> pack(-side => 'right');

  $edit_r->{type_edit_menu} = $edit_r->{type_edit_menu_but}
    -> Menu(-tearoff => "false");
  for my $key (sort
                {$types_def->{$a}[2] <=> $types_def->{$b}[2]}
                (keys(%{$types_def}))
              ) {
    $edit_r->{type_edit_menu}
      -> add( 'radiobutton',
              -command     => [showType => $self],
              -label       => $types_def->{$key}[1],
              -variable    => \$edit_r->{type_edit_type_var},
              -value       => $key,
              -indicatoron => 0,
            );
  } # for #

  # Disable free text entry
  $edit_r->{type_edit_menu} -> entryconfigure('end', -state => 'disabled');

  # Associate Menubutton with Menu.
  $edit_r->{type_edit_menu_but} ->
                 configure(-menu => $edit_r->{type_edit_menu});

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

  # Right area: Radio button values: Text
  $edit_r->{radio_edit_area} = $edit_r->{entry_sec_area}
      -> Frame()
      -> pack(-side => 'top', -fill => 'x');

  $edit_r->{radio_edit_label} = $edit_r->{radio_edit_area}
      -> Label(-text => 'Radioknapp')
      -> pack(-side => 'top');

  $edit_r->{radio_edit_text_area} = $edit_r->{radio_edit_area}
      -> Frame(-bd => '2', -relief => 'sunken')
      -> pack(-side => 'top', -fill => 'x');

  $edit_r->{radio_edit_text} = $edit_r->{radio_edit_text_area}
      -> TextUndo(
                -wrap => 'no',
                -height => 9,
                -width => 40,
               )
      -> pack(-side => 'left', -expand => '1', -fill => 'both');
  $edit_r->{radio_edit_text} -> tagAdd('syntax', '1.0', 'end');
  $edit_r->{radio_edit_text} -> bind('<KeyRelease>', [$self => '_syntaxCheck']);

  $edit_r->{radio_edit_scrollbar} = $edit_r->{radio_edit_text_area}
      -> Scrollbar(-command => [yview => $edit_r->{radio_edit_text}])
      -> pack(-side => 'left', -fill => 'y');

  $edit_r->{radio_edit_text}
      -> configure(-yscrollcommand => [set => $edit_r->{radio_edit_scrollbar}]);

  # Message
  $edit_r->{entry_message_area} = $edit_r->{radio_edit_area}
      -> Frame(-bd => '2', -relief => 'sunken')
      -> pack(-side => 'bottom', -fill => 'x');

  $edit_r->{entry_message_text} = $edit_r->{entry_message_area}
      -> Label()
      -> pack(-side => 'left');

  # Defaults, Set, Add and Delete buttons
  $edit_r->{entry_button_area} = $edit_r->{entry_edit_area}
      -> Frame()
      -> pack(-side => 'bottom');

  $self->{templates_selector} = '';
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
  for my $key (sort(keys(%$EVENT_CFG))) {
    $edit_r->{defaults_menu}
        -> add('radiobutton',
               -command => [selectTemplate => $self],
               -label => $key,
               -variable => \$self->{templates_selector},
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
                    erefs => {
                      -calculate => $self->{erefs}{-calculate},
                             },
                    -week      => 1,
                    -invalid   => $args{-invalid},
                    -notify    => $args{-modified},
                    -label     => 'Från och med vecka:',
                   );

  ### Earlier EventCfg ###
  $edit_r->{earlier_sec_area} = $edit_r->{set_area}
      -> Frame()
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $edit_r->{earlier_area} = $edit_r->{earlier_sec_area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'left');

  ### Earlier menu button ###
  $edit_r->{earlier_but} = $edit_r->{earlier_area}
      -> Menubutton(-text => 'Tidigare', -bd => '2', -relief => 'raised')
      -> pack(-side => 'left');

  ### Earlier menu ###
  $edit_r->{earlier_menu} = $edit_r->{earlier_but}
      -> Menu(-tearoff => 'false');
  # Associate Menubutton with Menu.
  $edit_r->{earlier_but} -> configure(-menu => $edit_r->{earlier_menu});

  $edit_r->{earlier_selected_label} = $edit_r->{earlier_area}
      -> Label(-text => 'aktuell')
      -> pack(-side => 'left');

  # View, Remove buttons
  $edit_r->{button_earlier_view} = $edit_r->{earlier_area}
      -> Button(-text => 'Visa', -command => [ealierView => $self])
      -> pack(-side => 'left');

  $edit_r->{button_earlier_remove} = $edit_r->{earlier_area}
      -> Button(-text => 'Ta bort',
                -state => 'disabled',
                -command => [earlierRemove => $self])
      -> pack(-side => 'left');

  # Set initial max_date
  $self->setMaxDate();

  # Change -max_date for Time widget at midnight
  $self->{erefs}{-clock}->repeat(-date => [$self, 'setMaxDate']);
  

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _showStatus
#
# Description: Show status of radio button
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _showStatus($;$) {
  # parameters
  my $self = shift;
  my ($text) = @_;

  $self->{edit}->{entry_message_text}-> configure(-text=> $text || '');
  return undef;
} # Method _showStatus

#----------------------------------------------------------------------------
#
# Method:      _highlightErrRow
#
# Description: Show status of radio button edit
#
# Arguments:
#  - Object reference
#  - Error text
#  - Line
#  - Length
# Returns:
#  -

sub _highlightErrRow($$$$) {
  # parameters
  my $self = shift;
  my ($t, $x, $l) = @_;

  my $text_r = $self->{edit}->{radio_edit_text};
  $text_r->tagAdd('err', $x.'.0', $x.'.'.$l);
  $text_r->tagConfigure('err', -background => 'grey');
  $self->_showStatus($t);
  return undef;
} # Method _highlightErrRow

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


  my $edit_r = $self->{edit};

  return 1 unless (ref($edit_r->{ev_ref}));

  return 0 if ($insert and ($proposed !~ /^\w*$/));
  if (length($proposed) and $proposed) {
    $edit_r->{label_OK} = 1;
    $edit_r->{label_proposed} = $proposed;
  } else {
    $edit_r->{label_OK} = 0;
  } # if #
  _chg_state($edit_r);
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


  my $edit_r = $self->{edit};

  return 1 unless (ref($edit_r->{ev_ref}));

  if (lc($edit_r->{type_edit_type_var}) ne 'r') {
    # Size entry
    return 0 if ($insert and ($proposed !~ /^\d*$/) or (length($proposed) > 2));
    if (length($proposed) and $proposed) {
      $edit_r->{size_OK} = 1;
      $edit_r->{size_proposed} = $proposed;
    } else {
      $edit_r->{size_OK} = 0;
    } # if #
    _chg_state($edit_r);
    return 1;

  } else {
    return 1;
  } # if #

  return 0;
} # Method sizeKey

#----------------------------------------------------------------------------
#
# Method:      _radioButtonGet
#
# Description: Get contents of radio button settings
#
# Arguments:
#  0 - Object reference
# Returns:
#  Undef: Invalid radio button contents
#  String with reatio button settings

sub _radioButtonGet($) {
  # parameters
  my $self = shift;

  my $edit_r = $self->{edit};

  return undef
      if (lc($edit_r->{type_edit_type_var}) ne 'r');

  my $text_r = $edit_r->{radio_edit_text};
  $text_r->tagDelete('err');
  my $tmp = $text_r -> get('1.0', 'end');
  $tmp =~ s/\n/;/g;
  $tmp =~ s/^[\s;]+//;
  $tmp =~ s/[\s;]+$//;
  $tmp =~ s/\s*=>\s*/=>/g;
  $tmp =~ s/;\s+/;/g;
  $tmp =~ s/\s+;/;/g;
  return $self->_showStatus("Värde saknas")
      unless (length($tmp) > 0);
  return $self->_showStatus("Flera blankrader ej tillåtet")
      if ((index($tmp, "\r")  > 0) or
          (index($tmp, ';;;') > 0)    );

  if ($edit_r->{type_edit_type_var} eq 'R') {
    my $r = 0;
    for my $t (split(';', $tmp)) {
      $r++;
      next
          unless $t;
      my $i = index($t, '=>');
      return $self->_highlightErrRow("'=>' saknas", $r, length($t))
          if ($i < 0);
      return $self->_highlightErrRow("'=>' är först", $r, length($t))
          if ($i == 0);
      return $self->_highlightErrRow("'=>' är sist", $r, length($t))
          if ($i >= length($t) - 2);
      $i = index($t, '=>', $i+1);
      return $self->_highlightErrRow("Flera '=>'", $r, length($t))
          if ($i > 0);
    } # for #
  } # if #

  return $tmp;
} # Method _radioButtonGet

#----------------------------------------------------------------------------
#
# Method:      _syntaxCheck
#
# Description: Syntax check of radio button settings
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _syntaxCheck($) {
  # parameters
  my $self = shift;


# TODO: How to apply this to the buttons like _check-state?
  if (defined($self->_radioButtonGet())) {
    $self->_showStatus();
  } # if #

  return 0;
} # Method _syntaxCheck

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

  my $edit_r = $self->{edit};

  $edit_r->{type_edit_menu_but}
         -> configure(
             -text => $self->{types_def}{$edit_r->{type_edit_type_var}}[1]
                     );

  if ($edit_r->{type_edit_type_var} ne $edit_r->{type_edit_type_previous}
      and
      (lc($edit_r->{type_edit_type_var})      eq 'r' or
       lc($edit_r->{type_edit_type_previous}) eq 'r'
      )
     )
  {
    if (lc($edit_r->{type_edit_type_var}) eq 'r') {
      $edit_r->{size_edit_entry} -> delete(0, 'end');
      $edit_r->{size_edit_entry} -> configure(-state => 'disabled');

      $edit_r->{radio_edit_text} -> configure(-state => 'normal');
      $edit_r->{radio_edit_text} -> delete('1.0', 'end');
      $edit_r->{radio_edit_text} -> tagAdd('syntax', '1.0', 'end');
      $edit_r->{button_set} -> configure(-state => 'normal');
    } else {
      $edit_r->{size_edit_entry} -> configure(-state => 'normal');
      $edit_r->{size_edit_entry} -> delete(0, 'end');

      $edit_r->{radio_edit_text} -> delete('1.0', 'end');
      $edit_r->{radio_edit_text} -> configure(-state => 'disabled');
    } # if #
    $edit_r->{type_edit_type_previous} = $edit_r->{type_edit_type_var};
    $edit_r->{size_OK} = 0;
  } # if #

  _chg_state($edit_r);

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


  my $edit_r = $self->{edit};

  $edit_r->{edit_list_box}->selectionSet($display)
      if (defined($display));

  $edit_r->{edit_list_box}->focus();
  my $cur_selection = $edit_r->{edit_list_box}->curselection();
  $cur_selection = $cur_selection->[0]
      if ref($cur_selection);

  if (defined($cur_selection)) {
    $edit_r->{edit_line_ref} = $edit_r->{edit_list_box}->get($cur_selection);
    my $ev_ref = $edit_r->{edit_list_refs}{$edit_r->{edit_line_ref}};

    # Signal validation routine "sizeKey" to accept any input
    $edit_r->{ev_ref} = undef;

    # Label setting
    $edit_r->{label_edit_entry} -> configure(-state => 'normal');
    $edit_r->{label_edit_entry} -> delete(0, 'end');
    $edit_r->{label_edit_entry} -> insert(0, $ev_ref->{text});
    $edit_r->{label_proposed} = $ev_ref->{text};
    $edit_r->{label_OK}       = 1;

    # Type setting
    $edit_r->{type_edit_menu_but}
           -> configure(-text => $ev_ref->{type_desc}, -state => 'normal');
    $edit_r->{type_edit_type_var} = $ev_ref->{type};
    $edit_r->{type_edit_type_previous} = $edit_r->{type_edit_type_var};
    $edit_r->{type_edit_menu} ->
        entryconfigure('end',
            -state => ($cur_selection < 
                         $#{$self->{cfg}}) ? 'disabled' : 'normal'
                       );

    # Size or radiobutton values setting
    $edit_r->{size_edit_entry} -> configure(-state => 'normal');
    if (lc($ev_ref->{type}) eq 'r') {
      $edit_r->{size_edit_entry} -> delete(0, 'end');
      $edit_r->{size_edit_entry} -> configure(-state => 'disabled');
    } else {
      $edit_r->{size_edit_entry} -> delete(0, 'end');
      $edit_r->{size_edit_entry} -> insert(0, $ev_ref->{sz_values});
      $edit_r->{size_proposed} = $ev_ref->{sz_values};
    } # if #
    $edit_r->{size_OK}       = 1;

    # Radiobutton values setting
    $edit_r->{radio_edit_text} -> configure(-state => 'normal');
    if (lc($ev_ref->{type}) ne 'r') {
      $edit_r->{radio_edit_text} -> delete('1.0', 'end');
      $edit_r->{radio_edit_text} -> configure(-state => 'disabled');
      $edit_r->{button_set} -> configure(-state => 'disabled');
    } else {
      $edit_r->{radio_edit_text} -> delete('1.0', 'end');
      $edit_r->{radio_edit_text} -> tagAdd('syntax', '1.0', 'end');
      for my $e (split(';', $ev_ref->{sz_values})) {
        # TODO =>
        $e =~ s/\s*=>\s*/ => /;
        $edit_r->{radio_edit_text}
            -> insert('end', $e . "\n");
      } # for #
      $edit_r->{radio_edit_text}->ResetUndo();
      $edit_r->{size_proposed} = $ev_ref->{sz_values};
      $edit_r->{button_set} -> configure(-state => 'normal');
      $edit_r->{change} = 1;

    } # if #

    # Change button setting
    $edit_r->{button_add} -> configure(-state => 'normal');
    if ($cur_selection < $#{$self->{cfg}}) {
      $edit_r->{button_remove} -> configure(-state => 'normal');
    } else {
      $edit_r->{button_remove} -> configure(-state => 'disabled');
    } # if #

    $edit_r->{ev_ref} = $ev_ref;
    $self->_showStatus("");
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


  my $edit_r = $self->{edit};

  $self->_showStatus("");

  # Display event cfg entries in listbox

  if (exists($edit_r->{edit_list_refs})) {
    %{$edit_r->{edit_list_refs}} = ();
  } else {
    $edit_r->{edit_list_refs} = {};
  } # if #

  $edit_r->{edit_list_box}      -> delete(0, 'end');
  my $edit_list_refs = $edit_r->{edit_list_refs};
  for my $ev_st (@{$self->{cfg}}) {
    my ($text, $type, $sz_values) = split(':', $ev_st);

    my $type_desc = '-';
    $type_desc = $self->{types_def}{$type}[1]
        if (exists($self->{types_def}{$type}));

    my $entry;
    if (lc($type) ne 'r') {
      $entry = sprintf('Etikett: %-10s  Typ: %-32s  Bredd: %2d',
                       $text, $type_desc, $sz_values);
    } else {
      $entry = sprintf('Etikett: %-10s  Typ: %-32s  Värden: %s',
                       $text, $type_desc, $sz_values);
    } # if #

    $edit_r->{ev_ref} = 0;
    $edit_list_refs->{$entry} = { ref => \$ev_st,
                                  text => $text,
                                  sz_values => $sz_values,
                                  type => $type,
                                  type_desc => $type_desc,
                                };
    $edit_r->{edit_list_box} -> insert("end", $entry);
  } # for #


  if (defined($display)) {
    $self->display($display);
  } else {
    $edit_r->{label_edit_entry}   -> delete(0, 'end');
    $edit_r->{label_edit_entry}   -> configure(-state => 'disabled');
    $edit_r->{size_edit_frame}    -> configure(-label => 'Bredd:');
    $edit_r->{size_edit_entry}    -> delete(0, 'end');
    $edit_r->{size_edit_entry}    -> configure(-width => EDIT_WIDTH,
                                               -state => 'disabled');
    $edit_r->{radio_edit_text}    -> delete('1.0', 'end');
    $edit_r->{radio_edit_text}    -> configure(-state => 'disabled');
    $edit_r->{type_edit_menu_but} -> configure(-text => '-',
                                               -state => 'disabled');
    $edit_r->{button_set}         -> configure(-state => 'disabled');
    $edit_r->{button_add}         -> configure(-state => 'disabled');
    $edit_r->{button_remove}      -> configure(-state => 'disabled');
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


  my $edit_r = $self->{edit};
  my $radio;
  if (lc($edit_r->{type_edit_type_var}) eq 'r') {
    $radio = $self->_radioButtonGet();
    return 0
        unless $radio;
    $self->_showStatus();
  } # if #

  return 0
      unless ($edit_r->{change});

  if (ref($edit_r->{ev_ref})) {
    my $ev_ref= $edit_r->{ev_ref};

    ${$ev_ref->{ref}} =
           $edit_r->{label_edit_entry} -> get() . ':' .
           $edit_r->{type_edit_type_var}        . ':';
    if (lc($edit_r->{type_edit_type_var}) ne 'r') {
      ${$ev_ref->{ref}} .= $edit_r->{size_edit_entry} -> get() ;
    } else {
      ${$ev_ref->{ref}} .= $radio;
    } # if #
    $self->update();
    $edit_r->{button_add}     -> configure(-state => 'disabled');
    $edit_r->{button_remove}  -> configure(-state => 'disabled');
    $edit_r->{modified} = 2;
    $self->callback($edit_r->{notify}, 'modified_event_cfg');
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


  my $edit_r = $self->{edit};

  my $index = $edit_r->{edit_list_box}->curselection();
  $index = $index->[0] if ref($index);

  @{$self->{cfg}} = (@{$self->{cfg}}[0 .. $index-1],
                     'Ny:A:6',
                     @{$self->{cfg}}[$index .. $#{$self->{cfg}}]);
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


  my $edit_r = $self->{edit};

  my $index = $edit_r->{edit_list_box}->curselection();
  $index = $index->[0] if ref($index);

  @{$self->{cfg}} = (@{$self->{cfg}}[0 .. $index-1],
                     @{$self->{cfg}}[$index+1 .. $#{$self->{cfg}}]);
  $edit_r->{modified} = 2;
  $self->callback($edit_r->{notify}, 'modified_event_cfg');
  $self->update();
  return 0;
} # Method remove

#----------------------------------------------------------------------------
#
# Method:      selectTemplate
#
# Description: Select a setting template
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub selectTemplate($) {
  # parameters
  my $self = shift;


  my $edit_r = $self->{edit};

  @{$self->{cfg}} = @{$self->{EVENT_CFG}{$self->{templates_selector}}};

  $edit_r->{modified} = 2;
  $self->callback($edit_r->{notify}, 'modified_event_cfg');
  $self->update();

  $self->{templates_selector} = '';

  return 0;
} # Method selectTemplate

#----------------------------------------------------------------------------
#
# Method:      isLocked
#
# Description: Check if week to change configuration for is locked
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 if not locked

sub isLocked($) {
  # parameters
  my $self = shift;


  my $edit_r = $self->{edit};

  return 0
      unless ($edit_r->{modified});

  my $date = $edit_r->{week_no}->get(1);

  return 0
      unless $date;

  return ($self->{erefs}{-cfg}->isLocked($date), $date);
} # Method isLocked

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


  my $edit_r = $self->{edit};
  my $return = 0;

  if ($edit_r->{modified}) {
    my $date = $edit_r->{week_no}->get(1);

    return 0
        unless $date;

    return 0
        if ($self->{erefs}{-cfg}->isLocked($date));

    if ($self->{erefs}{-event_cfg}->addCfg($self->{cfg}, $date)) {

      $return = $edit_r->{modified} - 1;
      $edit_r->{week_no} -> update(-min_date => $date);
      $self->{erefs}{-event_cfg}->notifyClients($date);
      $self->{earlier_removed_was_last} = undef;

    } # if #

    $edit_r->{modified} = 0;
  } # if #

  while (@{$self->{earlier_removed}}) {
    my $date = shift(@{$self->{earlier_removed}});
    $self->{erefs}{-event_cfg}->removeCfg($date);

    $self->{erefs}{-event_cfg}->
           notifyClients($self->{earlier_removed_was_last});
    $self->{earlier_removed_was_last} = undef;
  } # while #

  $self->_rebuildEarlier();

  return $return;
} # Method apply

#----------------------------------------------------------------------------
#
# Method:      _showWeekNo
#
# Description: Calculate week no from date, '0000-00-00' show 'tidigare'
#
# Arguments:
#  - Object reference
#  - Date
# Returns:
#  -

sub _showWeekNo($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  return 'tidigare'
      if ($date eq '0000-00-00');
  return join('v', $self->{erefs}{-calculate}->weekNumber($date));
} # Method _showWeekNo

#----------------------------------------------------------------------------
#
# Method:      _rebuildEarlier
#
# Description: Rebuild earlier EventCfg menu, copy from EventCfg
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _rebuildEarlier($) {
  # parameters
  my $self = shift;


  my $old = $self->{earlier_copy};
  my $cnt_r = $self->{earlier_index};

  my $edit_r = $self->{edit};

  # Make a copy of the configuration
  my $get = $self->{erefs}{-event_cfg}->getEarlierEventCfg();
  my $ref = {};
  $self->{earlier_copy} = $ref;
  while (my ($d, $r) = each(%$get)) {
    $ref->{$d} = [@{$r}];
  } # while #
  {
    my ($d, $r) = $self->{erefs}{-event_cfg}->getDateEventCfg();
    $ref->{$d} = [@{$r}];
  }

  # Remove old items from menu
  my $cnt = 0;
  my $mnu = $edit_r->{earlier_menu};
  for my $d (sort(keys(%{$old}))) {
    if (exists($ref->{$d})) {
      $cnt++;
    } else {
      $mnu->delete($cnt);
      delete($cnt_r->{$d});
    } # if #
  } # for #

  # Add new items
  my $prev_r;
  my $msg = '';
  $cnt = 0;
  for my $date (sort(keys(%{$ref}))) {
    if ($prev_r and 
        $self->{erefs}{-event_cfg}->compareCfg($prev_r, $ref->{$date}) == 0
       )
    {
       $msg = ' (lika som föregående)';
    } else {
       $msg = '';
    } # if #

    if (exists($old->{$date})) {
      $mnu->entryconfigure($cnt,
                           -label => $self->_showWeekNo($date) . $msg,
                           -value => $date);
    } else {
      $mnu->insert($cnt,
                   'radiobutton',
                   -command => [selectEarlier => $self],
                   -label => $self->_showWeekNo($date) . $msg,
                   -variable => \$self->{earlier_selector},
                   -value => $date,
                   -indicatoron => 0
                  );
    } # if #

    $cnt_r->{$date}=$cnt;
    $cnt++;
    $prev_r = $ref->{$date};
  } # for #

  return 0;
} # Method _rebuildEarlier

#----------------------------------------------------------------------------
#
# Method:      ealierView
#
# Description: View earlier EventCfg
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub ealierView($) {
  # parameters
  my $self = shift;


  return 0
      unless ($self->{earlier_selector});

  my $date = $self->{earlier_selector};

  return 0
      unless (exists($self->{earlier_copy}{$date}));

  @{$self->{cfg}} = @{$self->{earlier_copy}{$date}};

  my $edit_r = $self->{edit};
  $edit_r->{modified} = 2;
  $self->callback($edit_r->{notify}, 'modified_event_cfg');
  $self->update();

  return 0;
} # Method ealierView

#----------------------------------------------------------------------------
#
# Method:      earlierRemove
#
# Description: Remove an EventCfg for selected version
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub earlierRemove($) {
  # parameters
  my $self = shift;


  return 0
      unless ($self->{earlier_selector});

  my $date = $self->{earlier_selector};

  return 0
      if ($date eq '0000-00-00');

  return 0
      unless (exists($self->{earlier_copy}{$date}));

  return $self->callback($self->{-invalid},
                      'Vecka före ' .
                      join('v', $self->{erefs}{-calculate}->weekNumber($date)) .
                      ' är låst')
      if ($self->{erefs}{-cfg}->isLocked($date));

  my $edit_r = $self->{edit};

  my $ix = $self->{earlier_index}{$date};
  $edit_r->{earlier_menu}->delete($ix);
  delete($self->{earlier_copy}{$date});
  delete($self->{earlier_index}{$date});
  push(@{$self->{earlier_removed}}, $date);
  my $dateBeforeRemoved = '0000-00-00';
  while (my ($key, $val) = each(%{$self->{earlier_index}})) {
    $self->{earlier_index}{$key}--
        if ($val > $ix);
    $dateBeforeRemoved = $key
        if ($dateBeforeRemoved lt $key);
  } # while #

  if ($dateBeforeRemoved lt $date) {
    # Last removed, step to previous to be used
    $edit_r->{week_no} -> update(-min_date => $dateBeforeRemoved);
    $self->{earlier_removed_was_last} = $dateBeforeRemoved;
  } # if #

  $self->callback($edit_r->{notify}, 'modified_event_cfg');

  $self->{earlier_selector} = undef;
  $edit_r->{earlier_selected_label}
        -> configure(-text=> 'Borttagen');

  $edit_r->{button_earlier_view}->configure(-state => 'disabled');
  $edit_r->{button_earlier_remove}->configure(-state => 'disabled');

  return 0;
} # Method earlierRemove

#----------------------------------------------------------------------------
#
# Method:      selectEarlier
#
# Description: Select an earlier event cfg
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub selectEarlier($) {
  # parameters
  my $self = shift;


  my $edit_r = $self->{edit};

  $edit_r->{earlier_selected_label}
        -> configure(-text=> $self->_showWeekNo($self->{earlier_selector}));
  $edit_r->{button_earlier_view}->configure(-state => 'normal');
  my $date = $self->{earlier_selector};
  if ($date eq '0000-00-00') {
    $edit_r->{button_earlier_remove}->configure(-state => 'disabled');
  } else {
    $edit_r->{button_earlier_remove}->configure(-state => 'normal');
  } # if #

  return 0;
} # Method selectEarlier

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


  my $edit_r = $self->{edit};

  # Copy event configuration
  my @tmp = $self->{erefs}{-event_cfg}->getDateEventCfg();
  $edit_r->{week_no} -> update(-min_date => $tmp[0]);
  @{$self->{cfg}} = @{$tmp[1]};

  $self->_rebuildEarlier();
  $self->update();
  $edit_r->{week_no} -> set(undef, $self->{erefs}{-clock}->getDate());
  $edit_r->{modified} = 0;

  return 0;
} # Method showEdit

#----------------------------------------------------------------------------
#
# Method:      setMaxDate
#
# Description: Set max date for event cfg changes to this week
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub setMaxDate($) {
  # parameters
  my $self = shift;

  $self->{edit}{week_no} -> update(
                  -max_date  => $self->{erefs}{-calculate} ->
                                dayInWeek($self->{erefs}{-clock}->getYear(),
                                          $self->{erefs}{-clock}->getWeek(), 7),
                                   );

  return 0;
} # Method setMaxDate

1;
__END__
