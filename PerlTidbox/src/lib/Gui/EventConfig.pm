#
package Gui::EventConfig;
#
#   Document: Event Configuration Gui
#   Version:  1.0   Created: 2016-01-27 11:58
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: EventConfig.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2016-01-27';

# History information:

# 1.0  2015-12-09  Roland Vallgren
#      Event gui moved to own perl module
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
  my $types_def = $args{-event_cfg}->getDefinition();
  my $EVENT_CFG = $args{-event_cfg}->getDefinition(1);

  $self = {
           edit  => $edit_r,
             -calculate => $args{-calculate},
             -clock     => $args{-clock},
             -cfg       => $args{-cfg},
             -event_cfg => $args{-event_cfg},
             types_def  => $types_def,
             EVENT_CFG  => $EVENT_CFG,
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
  for my $key (sort(keys(%$EVENT_CFG))) {
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
                    -calculate => $self->{-calculate},
                    -week      => 1,
                    -invalid   => $args{-invalid},
                    -notify    => $args{-modified},
                    -label     => 'Från och med vecka:',
                   );

  # Set initial max_date
  $self->setMaxDate();

  # Change -max_date for Time widget at midnight
  $self->{-clock}->repeat(-date => [$self, 'setMaxDate']);
  

  return ($self);
} # Method new

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
    # Radio button entry
    return 0
        if ($insert and ($proposed !~ /^[^,:]*$/));

    if (($proposed =~ m/^[^\r\n]+$/)     and
        (index($proposed, ';;;') lt 0)   and
        (substr($proposed, 0, 1) ne ';') and
        (substr($proposed, -1)   ne ';')
       ) {

      my $ok = 1;
      if ($edit_r->{type_edit_type_var} eq 'R') {
        for my $t (split(';', $proposed)) {
          next
              unless $t;
          my $i = index($t, '=>');
          $ok = 0
              unless ($i > 0 and $i < length($t) - 2);

        } # for #
      } # if #

      $edit_r->{size_OK} = $ok;
      $edit_r->{size_proposed} = $proposed
          if $ok;
    } else {
      $edit_r->{size_OK} = 0;
    } # if #
    _chg_state($edit_r);
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

  my $edit_r = $self->{edit};

  $edit_r->{type_edit_menu_but}
         -> configure(-text => $self->{types_def}{$edit_r->{type_edit_type_var}}[1]);

  if ($edit_r->{type_edit_type_var} ne $edit_r->{ev_ref}{type} and
      (lc($edit_r->{type_edit_type_var}) eq 'r' or
       lc($edit_r->{ev_ref}{type})       eq 'r'
      )
     )
  {
    $edit_r->{size_edit_entry} -> delete(0, 'end');
    if (lc($edit_r->{type_edit_type_var}) ne 'r') {
      $edit_r->{size_edit_entry} -> configure(-justify => 'right');
      $edit_r->{size_edit_entry} -> configure(-width => EDIT_WIDTH);
      $edit_r->{size_edit_frame} -> configure(-label => 'Bredd:');
    } else {
      $edit_r->{size_edit_entry} -> configure(-justify => 'left');
      $edit_r->{size_edit_entry} -> configure(-width => 30);
      $edit_r->{size_edit_frame} -> configure(-label => 'Värden:');
    } # if #
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
    $edit_r->{type_edit_menu} ->
        entryconfigure('end',
            -state => ($cur_selection < 
                         $#{$edit_r->{cfg}}) ? 'disabled' : 'normal'
                       );

    # Size or radiobutton values setting
    $edit_r->{size_edit_entry} -> configure(-state => 'normal');
    $edit_r->{size_edit_entry} -> delete(0, 'end');
    $edit_r->{size_edit_entry} -> insert(0, $ev_ref->{sz_values});
    if (lc($ev_ref->{type}) ne 'r') {
      $edit_r->{size_edit_entry} -> configure(-justify => 'right');
      $edit_r->{size_edit_frame} -> configure(-label => 'Bredd:');
    } else {
      $edit_r->{size_edit_entry} -> configure(-justify => 'left');
      $edit_r->{size_edit_frame} -> configure(-label => 'Värden:');
    } # if #
    $edit_r->{size_edit_entry} -> configure(
       -width => (length($ev_ref->{sz_values}) > EDIT_WIDTH) ?
                 (length($ev_ref->{sz_values}))  :
                  EDIT_WIDTH);
    $edit_r->{size_proposed} = $ev_ref->{sz_values};
    $edit_r->{size_OK}       = 1;

    # Change button setting
    $edit_r->{button_set} -> configure(-state => 'disabled');
    $edit_r->{button_add} -> configure(-state => 'normal');
    if ($cur_selection < $#{$edit_r->{cfg}}) {
      $edit_r->{button_remove} -> configure(-state => 'normal');
    } else {
      $edit_r->{button_remove} -> configure(-state => 'disabled');
    } # if #

    $edit_r->{ev_ref} = $ev_ref;
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

  # Display event cfg entries in listbox

  if (exists($edit_r->{edit_list_refs})) {
    %{$edit_r->{edit_list_refs}} = ();
  } else {
    $edit_r->{edit_list_refs} = {};
  } # if #

  $edit_r->{edit_list_box}      -> delete(0, 'end');
  my $edit_list_refs = $edit_r->{edit_list_refs};
  for my $ev_st (@{$edit_r->{cfg}}) {
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
    $edit_r->{size_edit_frame}    -> configure(-label => '');
    $edit_r->{size_edit_entry}    -> delete(0, 'end');
    $edit_r->{size_edit_entry}    -> configure(-width => EDIT_WIDTH, -state => 'disabled');
    $edit_r->{type_edit_menu_but} -> configure(-text => '-', -state => 'disabled');
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
  return 0 unless ($edit_r->{change});

  if (ref($edit_r->{ev_ref})) {
    my $ev_ref= $edit_r->{ev_ref};
    ${$ev_ref->{ref}} =
           $edit_r->{label_edit_entry} -> get() . ':' .
           $edit_r->{type_edit_type_var}        . ':' .
           $edit_r->{size_edit_entry}  -> get() ;
    $self->update();
    $edit_r->{button_add}     -> configure(-state => 'disabled');
    $edit_r->{button_remove}  -> configure(-state => 'disabled');
    $edit_r->{modified} = 2;
    $self->callback($edit_r->{notify});
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

  @{$edit_r->{cfg}} = (@{$edit_r->{cfg}}[0 .. $index-1],
                       'Ny:A:6',
                       @{$edit_r->{cfg}}[$index .. $#{$edit_r->{cfg}}]);
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

  @{$edit_r->{cfg}} = (@{$edit_r->{cfg}}[0 .. $index-1],
                       @{$edit_r->{cfg}}[$index+1 .. $#{$edit_r->{cfg}}]);
  $edit_r->{modified} = 2;
  $self->callback($edit_r->{notify}, 'modified_event_cfg');
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


  my $edit_r = $self->{edit};

  @{$edit_r->{cfg}} = @{$self->{EVENT_CFG}{$self->{defaults_selector}}};

  $edit_r->{modified} = 2;
  $self->callback($edit_r->{notify}, 'modified_event_cfg');
  $self->update();

  $self->{defaults_selector} = '';

  return 0;
} # Method select

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

  return ($self->{-cfg}->isLocked($date), $date);
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

  return 0
      unless ($edit_r->{modified});

  my $date = $edit_r->{week_no}->get(1);

  return 0
      unless $date;

  return 0
      if ($self->{-cfg}->isLocked($date));

  $edit_r->{week_no} -> update(-min_date => $date);

  $self->{-event_cfg}->addCfg($date, $edit_r->{cfg});

  $self->{-event_cfg}->notifyClients($date);

  my $return = $edit_r->{modified} - 1;

  $edit_r->{modified} = 0;

  return $return;
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


  my $edit_r = $self->{edit};

  # Copy event configuration
  my @tmp = $self->{-event_cfg}->getDateEventCfg();
  $edit_r->{week_no} -> update(-min_date => $tmp[0]);
  @{$edit_r->{cfg}} = @{$tmp[1]};

  $self->update();
  $edit_r->{week_no} -> set(undef, $self->{-clock}->getDate());
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
                    -max_date  => $self->{-calculate} ->
                                  dayInWeek($self->{-clock}->getYear(),
                                            $self->{-clock}->getWeek(), 7),
                                   );

  return 0;
} # Method setMaxDate

1;
__END__
