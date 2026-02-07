#
package Gui::ScheduleConfig;
#
#   Document: Schedule Configuration Gui
#   Version:  1.0   Created: 2026-02-01 19:23
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: ScheduleConfig.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2026-02-01';

# History information:

# 1.0  2015-12-09  Roland Vallgren
#      First issue with inspiration from Event config gui
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

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create schedule configuration edit gui
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

  $self = {
           edit  => $edit_r,
           erefs => $args{erefs},
           -invalid   => $args{-invalid},
          };

  bless($self, $class);

  ## Schedule cfg edit area ##
  $edit_r->{set_area} =
      $args{-area} -> Frame()
          -> pack(-side=>'top', -expand => '1', -fill=>'both');

  # Ordinary week worktime
  $edit_r->{ordinary_worktime_area} = $edit_r->{set_area}
      -> Labelframe(-bd => '4',
                    -relief => 'ridge',
                    -text => 'Normal arbetstid för övriga veckor: ' )
      -> pack(-side => 'bottom', -expand => '0', -fill => 'x');

  $edit_r->{ordinary_worktime_lb} = $edit_r->{ordinary_worktime_area}
      -> Label(-text => 'Arbetstid: ')
      -> pack(-side => 'left');

  $edit_r->{ordinary_worktime_entry} = $edit_r->{ordinary_worktime_area}
      -> Entry(-width    => 12,
               -validate => 'key',
               -justify  => 'center',
               -textvariable    => \$edit_r->{ordinary_week_work_time},
               -validatecommand => [$self => '_hh_mm_or_h_decimal_entry_key_notify'],
              )
      -> pack(-side => 'left');
  # Edit week schedule
  $edit_r->{week_schedule_area} = $edit_r->{set_area}
      -> Labelframe(-bd => '4',
                    -relief => 'ridge',
                    -text => 'Redigera vecka: ')
      -> pack(-side => 'bottom', -expand => '0', -fill => 'x');

  # Week
  $edit_r->{week_worktime_no} =
      new Gui::Time(
                    -area      => $edit_r->{week_schedule_area},
                    erefs => {
                      -calculate => $self->{erefs}{-calculate},
                             },
                    -week      => 1,
                    -invalid   => $args{-invalid},
                    -notify    => $args{-modified},
                    -label     => 'Vecka:',
                   );

  # Week Schedule entry
  $edit_r->{entry_edit_area} = $edit_r->{week_schedule_area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top');

  $edit_r->{week_worktime_value} = '';
  $edit_r->{week_worktime_descr} = '';

  $edit_r->{week_worktime_lb} = $edit_r->{entry_edit_area}
      -> Label(-text => 'Arbestid: ')
      -> pack(-side => 'left');

  $edit_r->{week_worktime_entry} = $edit_r->{entry_edit_area}
      -> Entry(-width    => 8,
               -validate => 'key',
               -justify  => 'center',
               -textvariable    => \$edit_r->{week_worktime_value},
               -validatecommand => [$self => '_hh_mm_or_h_decimal_entry_key'],
              )
      -> pack(-side => 'left');

  $edit_r->{week_worktime_descr_lb} = $edit_r->{entry_edit_area}
      -> Label(-text => 'Beskrivning: ')
      -> pack(-side => 'left');

  $edit_r->{week_descr_entry} = $edit_r->{entry_edit_area}
      -> Entry(-width    => 30,
               -justify  => 'left',
               -textvariable    => \$edit_r->{week_worktime_descr},
              )
      -> pack(-side => 'left');

  # Set, Add and Delete buttons
  $edit_r->{entry_button_area} = $edit_r->{week_schedule_area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top');

  # Change, New and Remove buttons
  $edit_r->{button_set} = $edit_r->{entry_button_area}
      -> Button(-text => 'Rensa', -command => [clear => $self])
      -> pack(-side => 'left');
  $edit_r->{button_set} = $edit_r->{entry_button_area}
      -> Button(-text => 'Ändra', -command => [change => $self])
      -> pack(-side => 'left');
  $edit_r->{button_add} = $edit_r->{entry_button_area}
      -> Button(-text => 'Lägg till', -command => [add_week => $self])
      -> pack(-side => 'left');
  $edit_r->{button_remove} = $edit_r->{entry_button_area}
      -> Button(-text => 'Ta bort', -command => [remove => $self])
      -> pack(-side => 'left');

  ### Listbox Labelframe ###
  $edit_r->{list_edit_area} = $edit_r->{set_area}
      -> Labelframe(-bd => '2',
                    -relief => 'ridge',
                    -text => 'Veckor med annan arbetstid: ')
      -> pack(-side => 'bottom', -expand => '1', -fill => 'both');

  $edit_r->{edit_list_box} = $edit_r->{list_edit_area}
       -> Scrolled('Listbox', -scrollbars => 'oe')
       -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $edit_r->{edit_list_box}
      -> configure(-width => 30,
                   -height => 5,
                   -exportselection => 0);
  $edit_r->{edit_list_box} -> bind('<<ListboxSelect>>' => [$self => 'display']);

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _hh_mm_or_h_decimal_entry_key
#
# Description: Validate that only digits, comma or colon are entered.
#              1: Begin with a digit 1-9
#              2: Optional 0-9
#              3: Comma or colon, that is HHJ:MM or h,decimal (Decimal dot allowed)
#              4,5: Tenths and hundreds or minutes 0-59
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
#  -

sub _hh_mm_or_h_decimal_entry_key() {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;

  return 0
    if ($proposed !~ /^
              (?:
                [1-9]\d?
                  (?:
                    [,.]\d{0,2}
                   |
                    :[0-5]?\d?
                  )?
              )?
                            $/ox);

  return 1;
} # Method _hh_mm_or_h_decimal_entry_key

#----------------------------------------------------------------------------
#
# Method:      _hh_mm_or_h_decimal_entry_key_notify
#
# Description: Validate that only digits, comma or colon are entered.
#              1: Begin with a digit 1-9
#              2: Optional 0-9
#              3: Comma or colon, that is HHJ:MM or h,decimal (Decimal dot allowed)
#              4,5: Tenths and hundreds or minutes 0-59
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
#  -

sub _hh_mm_or_h_decimal_entry_key_notify() {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;


  return 0
    if ($proposed !~ /^
              (?:
                [1-9]\d?
                  (?:
                    [,.]\d{0,2}
                   |
                    :[0-5]?\d?
                  )?
              )?
                            $/ox);


  $self->callback($self->{edit}->{notify}, 'modified_schedule');
  return 1;
} # Method _hh_mm_or_h_decimal_entry_key

#----------------------------------------------------------------------------
#
# Method:      clear
#
# Description: Clear entry edit
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub clear($;$) {
  # parameters
  my $self = shift;


  my $edit_r = $self->{edit};
  $edit_r->{week_worktime_no} -> clear();
  # Set worktime and description
  $edit_r->{week_worktime_value} = '';
  $edit_r->{week_worktime_descr} = '';

  return 0;
} # Method display

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
    my $entry = $edit_r->{edit_list_refs}{$edit_r->{edit_line_ref}};

    # Set week
    $edit_r->{week_worktime_no} -> set(undef, $entry->{key});

    # Set worktime and description
    $edit_r->{week_worktime_value} = $entry->{ref}[0];
    $edit_r->{week_worktime_descr} = $entry->{ref}[1];


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
#  - Object reference
# Optional Arguments:
#  - Do full update
# Returns:
#  -

sub update($;$) {
  # parameters
  my $self = shift;
  my ($update_all) = @_;


  my $edit_r = $self->{edit};

  # Display schedule in listbox

  if (exists($edit_r->{edit_list_refs})) {
    %{$edit_r->{edit_list_refs}} = ();
  } else {
    $edit_r->{edit_list_refs} = {};
    $edit_r->{ordinary_week_work_time} = 40;
  } # if #


  $edit_r->{edit_list_box} -> delete(0, 'end');
  my $edit_list_refs = $edit_r->{edit_list_refs};
  for my $key (sort(keys(%{$self->{cfg}}))) {
    if ($key eq 'ordinary_week_work_time') {
      $edit_r->{ordinary_week_work_time} = $self->{cfg}{$key}
          if $update_all;
    } else {
      my $ref = $self->{cfg}{$key};
      my $week = join('v', $self->{erefs}{-calculate}->weekNumber($key));
      my $entry = sprintf('Vecka: %-10s  Arbetstid: %8s  Beskrivning: %-s',
                          $week, $ref->[0], $ref->[1]);

      $edit_r->{entry_ref} = 0;
      $edit_list_refs->{$entry} = { key   => $key,
                                    week  => $week,
                                    ref   => $ref,
                                  };
      # Insert in ascending order, later date above
      $edit_r->{edit_list_box} -> insert(0, $entry);
    } # if #

  } # for #

  $edit_r->{week_worktime_no} -> clear();

  $edit_r->{week_worktime_value} = '';
  $edit_r->{week_worktime_descr} = '';

  return 0;
} # Method update

#----------------------------------------------------------------------------
#
# Method:      do_chg
#
# Description: Add or change settings for an entry
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub do_chg($) {
  # parameters
  my $self = shift;


  my $edit_r = $self->{edit};

  my $date     = $edit_r->{week_worktime_no}->get(1);
  return undef
    unless defined($date);
  my $worktime = $edit_r->{week_worktime_value};
  return undef
    unless ($worktime);
  my $descr    = $edit_r->{week_worktime_descr};

  # TODO Should we handle schedule back in time? For now, ignore
  return undef
    unless ($date ge $self->{date});
  $self->{cfg}{$date} = [$worktime, $descr];

  $edit_r->{modified} = 1;
  $self->callback($edit_r->{notify}, 'modified_schedule');
  $self->update();

  return ;
} # Method do_chg

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

  my $date = $edit_r->{week_worktime_no}->get(1);
  return undef
    unless defined($date);
  return undef
    unless exists($self->{cfg}{$date});


  return $self->do_chg();
} # Method change

#----------------------------------------------------------------------------
#
# Method:      add_week
#
# Description: Add a week with specific worktime
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub add_week($) {
  # parameters
  my $self = shift;


  my $edit_r = $self->{edit};

  my $date = $edit_r->{week_worktime_no}->get(1);
  return undef
    unless defined($date);
  return undef
    if exists($self->{cfg}{$date});

  return $self->do_chg();
} # Method add_week

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

  my $cur_selection = $edit_r->{edit_list_box}->curselection();
  $cur_selection = $cur_selection->[0] if ref($cur_selection);

  if (defined($cur_selection)) {
    $edit_r->{edit_line_ref} = $edit_r->{edit_list_box}->get($cur_selection);
    my $entry = $edit_r->{edit_list_refs}{$edit_r->{edit_line_ref}};
    delete($self->{cfg}{$entry->{key}})
      if (exists($self->{cfg}{$entry->{key}}));

    $edit_r->{modified} = 1;
    $self->callback($edit_r->{notify}, 'modified_schedule');
    $self->update();
  }
  return 0;
} # Method remove

#----------------------------------------------------------------------------
#
# Method:      showEdit
#
# Description: Show schedule configuration edit
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub showEdit($) {
  # parameters
  my $self = shift;


  my $edit_r = $self->{edit};

  # Copy schedule configuration
  my ($start_week, $cfg_ref) = $self->{erefs}{-schedule}->getDateSchedule();

  # Find out date of monday this week
  my $monday_date = $self->{erefs}{-clock}->getDate();
  (undef, $monday_date) = $self->{erefs}{-calculate}
    -> evalTimeDate(undef,
                  undef,
                  join('v',
                     $self->{erefs}{-calculate}->weekNumber($monday_date)).'m',
                   );

  # Split into earlier and future weeks

  my ($earlier_ref, $future_ref) =
      $self->{erefs}{-schedule}->splitSet($cfg_ref, $monday_date);


  $self->{earlier} = $earlier_ref;
  $self->{earlier_start} = $start_week;
  $self->{cfg} = $future_ref;
  $self->{date} = $monday_date;

  $self->update(1);
  $edit_r->{modified} = 0;

  return 0;
} # Method showEdit

#----------------------------------------------------------------------------
#
# Method:      apply
#
# Description: Apply new schedule configuration settings
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


  return 0
      if ($self->{erefs}{-cfg}->isLocked($self->{date}));

  # Get ordinary week worktime
  $self->{cfg}{ordinary_week_work_time} = $edit_r->{ordinary_week_work_time};

  # Is start week of earlier set before this week
  if ($self->{earlier_start} lt $self->{date}) {
    # Save earlier set and future set
    $self->{erefs}{-schedule}->
           updateCfg($self->{cfg}, $self->{date},
                     $self->{earlier}, $self->{earlier_start});
  } else {
    # Same start, only save future set
    $self->{erefs}{-schedule}->
           updateCfg($self->{cfg}, $self->{date});
  } # if #

  $edit_r->{modified} = 0;

  return 1;
} # Method apply

1;
__END__
