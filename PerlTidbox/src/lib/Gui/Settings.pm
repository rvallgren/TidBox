#
package Gui::Settings;
#
#   Document: Gui::Settings
#   Version:  2.2   Created: 2017-09-26 10:38
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Settings.pmx
#

my $VERSION = '2.2';
my $DATEVER = '2017-09-26';

# History information:
#
# 1.0  2007-03-07  Roland Vallgren
#      First issue.
# 1.1  2007-03-26  Roland Vallgren
#      Return fault
#      Corrected modified handling for event_cfg
#      Use date set in event_cfg
# 1.2  2007-07-15  Roland Vallgren
#      Moved supervision settings to Supervision.pmx
# 1.3  2008-09-06  Roland Vallgren
#      Main window edit earlier data
# 1.4  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Added Terp settings tab
# 1.5  2009-07-14  Roland Vallgren
#      Evalutaion notice removed from daylist setting
#      Added timeout for status messages
# 1.6  2012-05-09  Roland Vallgren
#      not_set_start => start_operation :  none, workday, event, end pause
# 1.7  2012-09-10  Roland Vallgren
#      EventCfg need win_r for message popup
# 1.8  2013-05-18  Roland Vallgren
#      Handle session lock
# 2.0  2015-08-10  Roland Vallgren
#      Added tab for start of Tidbox
#      Added settings for handling of resume
#      Improved handling of invalid values
# 2.1  2015-12-16  Roland Vallgren
#      Moved Gui for Event to own Gui class
# 2.2  2017-05-23  Roland Vallgren
#      Added plugin handling
#      Removed Terp, moved to MyTime plugin
#      Setting for ordinary work time for a week is now a common setting
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

use Tk;
use Tk::NoteBook;

use Gui::Confirm;
use Gui::Event;
use Gui::EventConfig;
use Gui::SupervisionConfig;

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
# Settings description
#
# Settings modifiable in Settings:
#
#   start_operation    How to register start of tidbox
#                       0:  No action
#                       1:  Register Start workday, if it is the first today
#                       2:  Register Event start tidbox
#                       3:  Register End Pause
#                       4:  Register an own defined start Event (??? 2 ???)
#   start_operation_event   User Event to register when Tidbox is started
#   resume_operation    How to register resume of tidbox
#                       0:  No action
#                       1:  Register Start workday, if it is the first today
#                       2:  Register Event resume tidbox
#                       3:  Register End Pause
#                       4:  Register an own defined resume Event (??? 2 ???)
#   resume_operation_time    Sleep or hibernation timeout to register
#   resume_operation_event   User Event to register when Tidbox is resumed
#   remember_positions      Behåll skärmpositioner:
#   save_threshold          Autospara redigeringar efter
#   earlier_menu_size       Antal i Tidigare menyn:
#   adjust_level            Justera händelser till:
#   show_data               Visa status:
#   show_reg_date           Visa datum i pågående aktivitet:
#   show_message_timeout    Tid för visa status information:
#   $^O.'_do_backup'        Spara säkerhetskopia {OS}
#   $^O.'_backup_directory' Katalog för säkerhetskopia {OS}
#   ordinary_week_work_time  Ordinarie veckoarbetstid
#
# Settings defined in specific windows
#
#   lock_date               Week: Date for locked week
#   archive_date            Year: Date for archive
#   last_version            Main: Tool version
#
# Special settings
#
#   {win_name}_geometry     Named window: Position
#

#----------------------------------------------------------------------------
#
# Constants
#
#   Settings settable in Settings

use constant SETTABLE_CFGS =>
    qw(
        start_operation
        start_operation_event
        resume_operation
        resume_operation_time
        resume_operation_event
        remember_positions
        save_threshold
        earlier_menu_size
        main_show_daylist
        adjust_level
        show_data
        show_reg_date
        show_message_timeout
        ordinary_week_work_time
      );

use constant BACKUP_ENA => $^O . '_do_backup';
use constant BACKUP_DIR => $^O . '_backup_directory';
#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create settings Gui
#
# Arguments:
#  0 - Object prototype
# Additional arguments as hash
#  -about_popup Reference to about_popup
#  -cfg        Reference to configuration hash
#  -event_cfg  Event configuration object
#  -parent_win Parent window
#  -week_win   Week window
#  -earlier    Earlier menu
#  -title      Tool title
#  -times      Reference to add times object
#  -rewrite    Reference to rewrite data routine
#  -calculate  Reference to calculator
#  -clock      Reference to clock
#  -rewrite    Rewrite times data
#  -supv_update Update supevision data
#  -edit_update Reference to edit update list routine
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              @_,
              win        => {name => 'sett'},
              condensed  => 0,
              errors     => undef,
              plugin_can => { -area    => undef,
                              -apply   => undef,
                              -restore => undef,
                            },
             };

  $self->{-title} .= ': Inställningar';

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _not_allowed
#
# Description: Tell that a not allowed value was enterd
#
# Arguments:
#  - Object reference
#  - List of message texts
# Returns:
#  -

sub _not_allowed($@) {
  # parameters
  my $self = shift;

  my @e;
  push @e, @{$self->{errors}}
      if (ref($self->{errors}));
  push @e, @_;
  $self->{win}{confirm}
       -> popup(
                -title => ': Felaktig inmatning',
                -text  => ['Ej tillåtet värde i inställningar'],
                -data  => [join("\n", @e)],
               );
  $self->{errors} = undef;
  return 0;
} # Method _not_allowed

#----------------------------------------------------------------------------
#
# Method:      _not_allow_add
#
# Description: Add not allowed information in coming dialog
#
# Arguments:
#  - Object reference
#  - List of message texts
# Returns:
#  -

sub _not_allow_add($@) {
  # parameters
  my $self = shift;

  if (ref($self->{errors})) {
    push @{$self->{errors}}, @_;

  } else {
    $self -> _not_allowed(@_);

  } # if #
  return 0;
} # Method _not_allow_add

#----------------------------------------------------------------------------
#
# Method:      _discard
#
# Description: Discard changes
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _discard($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  $win_r->{button_ok}      -> configure(-state => 'disabled');
  $win_r->{button_apply}   -> configure(-state => 'disabled');
  $win_r->{button_restore} -> configure(-state => 'disabled');

  $self->{changed}  = 0;
  $self->{modified} = undef;
  %{$self->{mod}} = ();
  return 0;
} # Method _discard

#----------------------------------------------------------------------------
#
# Method:      _restore
#
# Description: Restor settings from configuration data
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _restore($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  # Signal to _modified to not bother
  $self->{modified} = undef;

  # Copy editable configuration data
  my %tmp = $self->{-cfg}->get(SETTABLE_CFGS,
                               BACKUP_ENA(),
                               BACKUP_DIR());
  while (my ($key, $val) = each(%tmp)) {
    $self->{cfg}{$key} = $val;
  } # while #


  ### Insert Configuration data ###

  $self->{-event_cfg_setup}->showEdit();

  $self->{-supervision_cfg_setup}->showEdit();

  if ($self->{cfg}{BACKUP_ENA()}) {
    $win_r->{backup_button}->
        configure(-state => "normal",
                  -text => $self->{cfg}{BACKUP_DIR()},
                 );
  } else {
    $win_r->{backup_button}->
        configure(-state => "disabled",
                  -text => 'Välj katalog',
                 );
  } # if #



  $self->{start_tidbox_win_r}{event_handling}
      -> set($self->{cfg}{start_operation_event}, 1);

  $self->{resume_tidbox_win_r}{event_handling}
      -> set($self->{cfg}{resume_operation_event}, 1);

  ### Insert plugin configuration data ###
  while (my ($name, $ref) = each(%{$self->{plugin}})) {
    $self->callback($ref->{-restore})
        if (exists($ref->{-restore}));
  } # while #

  # No changes registered
  $self->_discard();
  $self->{modified} = 0;

  return 0;
} # Method _restore

#----------------------------------------------------------------------------
#
# Method:      _apply
#
# Description: Apply
#              If there are changes update cfg data and gui
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _apply($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  # Check if any lock prohibits changes
  my ($lock, $txt, $lockdate, $date) = $self->{-event_cfg_setup}->isLocked();
  if ($lock == 1) {
    $win_r->{confirm}
        -> popup(-title => 'information',
                 -text  => ['Kan inte ändra för: '. $date,
                            'Alla veckor till och med ' .
                                 $lockdate . ' är låsta.'],
                );
    return 1;

  } elsif ($lock == 2) {
    $win_r->{confirm}
        -> popup(-title => 'information',
                 -text  => ['Tidbox är låst av en annan Tidbox!'],
                );
    return 1;

  } # if #
  

  # Check entries
  $self->{errors} = [];
  $self->_not_allow_add('Tidigare menyn måste har minst en rad.')
      if ($self->{cfg}{earlier_menu_size} <= 0);
  $self->_not_allow_add('Tiden för "Autospara redigeringar" måste vara minst en minut.')
      if ($self->{cfg}{save_threshold} <= 0);
  $self->_not_allow_add('Säkerhetskopia vald för "' . $^O . '" men ingen katalog är definierad.')
      if ($self->{cfg}{BACKUP_ENA()} and not $self->{cfg}{BACKUP_DIR()});

  $self->{-supervision_cfg_setup}->getData();

  my $tmp_starttb_event = $self->{start_tidbox_win_r}{event_handling}
      -> get([$self => '_not_allow_add']);
  my $tmp_resumetb_event = $self->{resume_tidbox_win_r}{event_handling}
      -> get([$self => '_not_allow_add']);

  if (@{$self->{errors}} > 0) {
    $self->_not_allowed();
    return 1;
  } # if #


  if ($self->{modified}) {
    # Handle event configuration
    if ($self->{mod}{event_cfg}) {

      if ($self->{-event_cfg_setup}->apply()) {
        $self->{-week_win}->withdraw();
        $self->{-event_cfg}->save(1);
      } # if #

      $self->{mod}{event_cfg} = 0;

    } # if #

    # Handle start tidbox event
    if ($self->{mod}{start_operation_event}) {

      $self->{cfg}{start_operation_event} = $tmp_starttb_event;

      $self->{mod}{start_operation_event} = 0;

    } # if #

    # Handle resume tidbox event
    if ($self->{mod}{resume_operation_event}) {

      $self->{cfg}{resume_operation_event} = $tmp_resumetb_event;

      $self->{mod}{resume_operation_event} = 0;

    } # if #

  ### Insert plugin configuration data ###
  while (my ($name, $ref) = each(%{$self->{plugin}})) {
    $self->callback($ref->{-apply})
        if (exists($ref->{-apply}));
  } # while #

    # Update configuration data
    $self->{-cfg}->set(%{$self->{cfg}});
    $self->{-cfg}->save(1);
    $self->{-cfg}->bakInit();

    # Update supervision
    if ($self->{mod}{supervision}) {

      $self->{-supervision}->save(1)
          if ($self->{-supervision_cfg_setup}->apply());
      $self->{mod}{supervision} = 0;
    } # if #

    # Update windows
    $self->callback($self->{-edit_update});
    $self->callback($self->{-main_status});
    $self->callback($self->{-week_update});

  } # if #
  $self->_restore();

  return 0;
} # Method _apply

#----------------------------------------------------------------------------
#
# Method:      _modified
#
# Description:
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - What setting is modified
# Returns:
#  -

sub _modified($;$) {
  # parameters
  my $self = shift;
  my ($setting) = @_;

  # Do no "modified" activities while the Settings is buildt
  # The buttons are added last
  my $win_r = $self->{win};
  return 0 unless $win_r->{button_ok};
  $self->{modified} = 1;

  if ($setting) {
    if ($setting eq '_do_backup') {
      if ($self->{cfg}{BACKUP_ENA()}) {
        $win_r->{backup_button}->
            configure(-state => "normal",
                      -text => $self->{cfg}{BACKUP_DIR()} ?
                               $self->{cfg}{BACKUP_DIR()} :
                               'Välj katalog',
                     );
      } else {
        $win_r->{backup_button}->
            configure(-state => "disabled",
                      -text => 'Välj katalog',
                     );
        $self->{cfg}{BACKUP_DIR()} = undef;
      } # if #

    } else {
      $self->{mod}{$setting} = 1;
    } # if #
  } # if #
  my $state = $self->{-cfg}->isSessionLocked()
                ? 'disabled' : 'normal';

  $win_r->{button_ok}      -> configure(-state => $state);
  $win_r->{button_apply}   -> configure(-state => $state);
  $win_r->{button_restore} -> configure(-state => 'normal');
  return 1;
} # Method _modified

#----------------------------------------------------------------------------
#
# Method:      _number_entry_key
#
# Description: Validate that only digits are entered.
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

sub _number_entry_key() {
  # parameters
  my $self = shift;
  my ($proposed, $change, $current, $index, $insert) = @_;

  return 0 if ($proposed !~ /^\d*$/ or (length($proposed) > 2));
  $self->_modified();
  return 1;
} # Method _number_entry_key

#----------------------------------------------------------------------------
#
# Method:      _chooseBakDirectory
#
# Description: Choose a backup directory
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _chooseBakDirectory($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  my $startdir = $self->{cfg}{BACKUP_DIR()} ?
                     $self->{cfg}{BACKUP_DIR()} :
                     (($^O eq 'MSWin32') ?
                           File::Spec->catfile(
                                               $ENV{HOMEDRIVE},
                                               ''
                                              )
                           :
                           $ENV{HOME}
                     );

  my $dir = $win_r->{win}
        -> chooseDirectory(-initialdir => $startdir,
                           -parent => $win_r->{win},
                           -title => $self->{-title} . ': Katalog för säkerhetskopia',
                          );

  return 0
      unless $dir;

  $self->{cfg}{BACKUP_DIR()} = $dir;
  $self->_modified('_do_backup');

  return 0;
} # Method _chooseBakDirectory

#----------------------------------------------------------------------------
#
# Method:      _setupClear
#
# Description: Clear start or resume event setup
#
# Arguments:
#  - Object reference
#  - 'start' or 'resume'
# Returns:
#  -

sub _setupClear($$) {
  # parameters
  my $self = shift;
  my ($action) = @_;

  my $win_r = $self->{win};

  $self->{$action . '_tidbox_win_r'}{event_handling}
      -> clear();
  $self->callback([$self => '_modified', $action . '_tidbox']);


  return 0;
} # Method _setupClear

#----------------------------------------------------------------------------
#
# Method:      _previous
#
# Description: Insert previous for start or resume event configuration
#
# Arguments:
#  - Object reference
#  - Reference to event to add
#  - 'start' or 'resume'
# Returns:
#  -

sub _previous($$$) {
  # parameters
  my $self = shift;
  my ($action, $ref) = @_;

  $self->{$action . '_tidbox_win_r'}{event_handling}
      -> set($$ref);
  return 0;
} # Method _previous

#----------------------------------------------------------------------------
#
# Method:      _addButtonsStart
#
# Description: Add buttons for the start event dialog
#
# Arguments:
#  0 - Object reference
#  1 - Area were to add
# Returns:
#  -

sub _addButtonsStart($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;

  my $win_r = $self->{win};
  $self->{-earlier}->create($area, 'right', [$self => '_previous', 'start']);
  $win_r->{set_start_clear} = $area
      -> Button(-text => 'Rensa', -command => [$self => '_setupClear', 'start'])
      -> pack(-side => 'right');
  return 0;
} # Method _addButtonsStart

#----------------------------------------------------------------------------
#
# Method:      _addButtonsResume
#
# Description: Add buttons for the resume event dialog
#
# Arguments:
#  0 - Object reference
#  1 - Area were to add
# Returns:
#  -

sub _addButtonsResume($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;

  my $win_r = $self->{win};
  $self->{-earlier}->create($area, 'right', [$self => '_previous', 'resume']);
  $win_r->{set_resume_clear} = $area
      -> Button(-text => 'Rensa', -command => [$self => '_setupClear', 'resume'])
      -> pack(-side => 'right');
  return 0;
} # Method _addButtonsResume

#----------------------------------------------------------------------------
#
# Method:      _setup
#
# Description: Setup the contents of the settings window
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _setup($) {
  # parameters
  my $self = shift;
  my $i;


  my $win_r = $self->{win};

  # Show clock as window heading
  $self->{-clock}->setDisplay($win_r->{name}, $win_r->{title});

  # Copy configuration data
  %{$self->{cfg}} = $self->{-cfg}->get(SETTABLE_CFGS);

  # Create a notebook
  $win_r->{notebook} = $win_r->{area}
      -> NoteBook(-dynamicgeometry => 1)
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  ### TAB: General settings ###
  $win_r->{general_tab} = $win_r->{notebook}
      -> add('general', -label => 'Generell');

  # Remember window positions
  $win_r->{remember_win_pos_area} = $win_r->{general_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{remember_win_pos_lb} = $win_r->{remember_win_pos_area}
      -> Label(-text => 'Behåll skärmpositioner:')
      -> pack(-side => 'left');

  $win_r->{remember_win_pos} = $win_r->{remember_win_pos_area}
      -> Checkbutton(-variable => \$self->{cfg}{remember_positions},
                     -command  => [$self=>'_modified'],
                     -onvalue  => 1,
                     -offvalue => 0)
      -> pack(-side => 'left');

  # Save threshold
  $win_r->{save_threshold_area} = $win_r->{general_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{save_threshold_lb} = $win_r->{save_threshold_area}
      -> Label(-text => 'Autospara redigeringar efter ')
      -> pack(-side => 'left');

  $win_r->{save_threshold_entry} = $win_r->{save_threshold_area}
      -> Entry(-width           => 3,
               -validate        => 'key',
               -justify         => 'center',
               -textvariable    => \$self->{cfg}{save_threshold},
               -validatecommand => [$self => '_number_entry_key'],
              )
      -> pack(-side => 'left');

  $win_r->{save_threshold_note} = $win_r->{save_threshold_area}
      -> Label(-text => ' minuter (sparas direkt om redigera stängs eller vid byte av dag)')
      -> pack(-side => 'left');

  # Earlier menu size
  $win_r->{earlier_menu_size_area} = $win_r->{general_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{earlier_menu_size_lb} = $win_r->{earlier_menu_size_area}
      -> Label(-text => 'Antal i Tidigare menyn: ')
      -> pack(-side => 'left');

  $win_r->{earlier_menu_size_entry} = $win_r->{earlier_menu_size_area}
      -> Entry(-width    => 3,
               -validate => 'key',
               -justify  => 'center',
               -textvariable    => \$self->{cfg}{earlier_menu_size},
               -validatecommand => [$self => '_number_entry_key'],
              )
      -> pack(-side => 'left');

  $win_r->{earlier_menu_size_note} = $win_r->{earlier_menu_size_area}
      -> Label(-text => ' (menyerna minskas endast efter omstart)')
      -> pack(-side => 'left');

  # Ordinary week worktime (temporary)
  $win_r->{ordinary_worktime_area} = $win_r->{general_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{ordinary_worktime_lb} = $win_r->{ordinary_worktime_area}
      -> Label(-text => 'Ordinarie veckoarbetstid: ')
      -> pack(-side => 'left');

  $win_r->{ordinary_worktime_entry} = $win_r->{ordinary_worktime_area}
      -> Entry(-width    => 3,
               -validate => 'key',
               -justify  => 'center',
               -textvariable    => \$self->{cfg}{ordinary_week_work_time},
               -validatecommand => [$self => '_number_entry_key'],
              )
      -> pack(-side => 'left');

  $win_r->{ordinary_worktime_note} = $win_r->{ordinary_worktime_area}
      -> Label(-text => ' (kan komma att ersättas med schema i senare versioner)')
      -> pack(-side => 'left');

  # Adjust precision
  $win_r->{adjust_area} = $win_r->{general_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{adjust_lb} = $win_r->{adjust_area}
      -> Label(-text => 'Justera händelser till:')
      -> pack(-side => 'left');

  my @i =   ( 6,     # "Tiondels timma"
             30,     # "Halvtimma"
            );
  for my $s ("Tiondels timma"  ,
             "Halvtimma"       ,
            )
  {
    $win_r->{adjust_choise} = $win_r->{adjust_area}
        -> Radiobutton(-text => $s,
                       -command => [$self => '_modified'],
                       -variable => \$self->{cfg}{adjust_level},
                       -value => shift(@i),
                      )
        -> pack(-side => 'left');
  } # for #

  # Backup directory
  $win_r->{backup_area} = $win_r->{general_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{backup_lb} = $win_r->{backup_area}
      -> Label(-text => 'Spara säkerhetskopia "' . $^O . '":' )
      -> pack(-side => 'left');

  $win_r->{backup_do} = $win_r->{backup_area}
      -> Checkbutton(-variable => \$self->{cfg}{BACKUP_ENA()},
                     -command  => [$self=>'_modified', '_do_backup'],
                    )
      -> pack(-side => 'left');

  $win_r->{backup_button} = $win_r->{backup_area}
      -> Button(
                -command => [$self => '_chooseBakDirectory'],
               )
      -> pack(-side => 'left');


  ### TAB: Status settings ###
  $win_r->{status_tab} = $win_r->{notebook}
      -> add('status', -label => 'Status');

  # Show daylist in main window
  $win_r->{set_main_show_daylist_area} = $win_r->{status_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{set_main_show_daylist_lb} = $win_r->{set_main_show_daylist_area}
      -> Label(-text => 'Visa lista med dagens aktiviteter i huvudfönstret:')
      -> pack(-side => 'left');

  $win_r->{set_main_show_daylist} = $win_r->{set_main_show_daylist_area}
      -> Checkbutton(-variable => \$self->{cfg}{main_show_daylist},
                     -command  => [$self => '_modified'],
                     -onvalue  => 1,
                     -offvalue => 0)
      -> pack(-side => 'left');

  $win_r->{set_main_show_daylist_note} = $win_r->{set_main_show_daylist_area}
      -> Label(-text => "Starta om Tidbox för att aktivera ändring.")
      -> pack(-side => 'left');

  # Show data setting
  $win_r->{show_data_area} = $win_r->{status_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{show_data_lb} = $win_r->{show_data_area}
      -> Label(-text => 'Visa status:')
      -> pack(-side => 'left');

  $i = 0;
  for my $s ("Pågående aktivitet"        ,
             "Arbetstid idag"            ,
             "Arbetstid hela veckan"     ,
             "Tid för aktuell aktivitet" )
  {
    $win_r->{show_data_choise} = $win_r->{show_data_area}
        -> Radiobutton(-text => $s,
                       -command => [$self => '_modified'],
                       -variable => \$self->{cfg}{show_data},
                       -value => $i)
        -> pack(-side => 'left');
    $i++;
  } # for #

  # Show date in show_registered
  $win_r->{set_show_reg_date_area} = $win_r->{status_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{set_show_reg_date_lb} = $win_r->{set_show_reg_date_area}
      -> Label(-text => 'Visa datum i pågående aktivitet:')
      -> pack(-side => 'left');

  $win_r->{set_show_reg_date} = $win_r->{set_show_reg_date_area}
      -> Checkbutton(-variable => \$self->{cfg}{show_reg_date},
                     -command  => [$self => '_modified'],
                     -onvalue  => 1,
                     -offvalue => 0)
      -> pack(-side => 'left');

  # Show status message timeout
  $win_r->{set_show_message_timeout_area} = $win_r->{status_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{set_show_message_timeout_lb} = $win_r->{set_show_message_timeout_area}
      -> Label(-text => 'Visa status information i ')
      -> pack(-side => 'left');

  $win_r->{set_show_message_timeout} = $win_r->{set_show_message_timeout_area}
      -> Entry(-width           => 3,
               -validate        => 'key',
               -justify         => 'center',
               -textvariable    => \$self->{cfg}{show_message_timeout},
               -validatecommand => [$self => '_number_entry_key'],
              )
      -> pack(-side => 'left');


  $win_r->{set_main_show_daylist_note} = $win_r->{set_show_message_timeout_area}
      -> Label(-text => 'minuter')
      -> pack(-side => 'left');

  # Supervision setting

  $self->{-supervision_cfg_setup} =
      new Gui::SupervisionConfig(-area      => $win_r->{status_tab},
                -supervision => $self->{-supervision},
                -event_cfg   => $self->{-event_cfg},
                -earlier     => $self->{-earlier},
                -calculate   => $self->{-calculate},
                -modified    => [$self => '_modified', 'supervision'],
                -invalid     => [$self => '_not_allow_add'],
                          );

  ### TAB: Event configuration settings ###
  $win_r->{edit_tab} = $win_r->{notebook}
      -> add('events', -label => 'Händelser');
  $self->{-event_cfg_setup} =
      new Gui::EventConfig(-area      => $win_r->{edit_tab},
                           -win_r     => $win_r,
                           -modified  => [ $self => '_modified', 'event_cfg'],
                           -event_cfg => $self->{-event_cfg},
                           -invalid   => [$self => '_not_allowed'],
                           -calculate => $self->{-calculate},
                           -clock     => $self->{-clock},
                           -cfg       => $self->{-cfg},
                          );

  ### TAB: Start Tidbox ###
  $win_r->{start_tab} = $win_r->{notebook}
      -> add('starttb', -label => 'Starta');

  # Select action when Tidbox is started
  $win_r->{set_start_time_area} = $win_r->{start_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{start_operation_lb} = $win_r->{set_start_time_area}
      -> Label(-text => 'När TidBox startas:')
      -> pack(-side => 'left');

  $i = 0;
  for my $s ("Ingen åtgärd"      ,
             "Börja arbetsdagen" ,
             "Börja händelse"    ,
             "Sluta paus"        ,
             "Börja egen händelse" )
  {
    $win_r->{start_operation_choise} = $win_r->{set_start_time_area}
        -> Radiobutton(-text => $s,
                       -command => [$self => '_modified'],
                       -variable => \$self->{cfg}{start_operation},
                       -value => $i)
        -> pack(-side => 'left');
    $i++;
  } # for #

  # Select event to register when started

  ## Area ##
  $win_r->{set_start_event_area} = $win_r->{start_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  ### Label ###
  $win_r->{set_start_event_label} = $win_r->{set_start_event_area}
      -> Label(-text => 'Egen händelse:')
      -> pack(-side => 'left');

  ### Event cfg ##
  my $starttb_win_r = { name => 'StartTidBox',
                        -area => $win_r->{set_start_event_area},
                      };
  $self->{start_tidbox_win_r} = $starttb_win_r;

  $starttb_win_r->{event_handling} =
      new Gui::Event(
                    -event_cfg  => $self->{-event_cfg},
                    -area       => $starttb_win_r->{-area},
                    -parentName => $starttb_win_r->{name},
                    -validate => [$self => '_modified', 'start_operation_event'],
                    -buttons  => [$self => '_addButtonsStart'],
                   );

  # Select action when Tidbox is resumed after hibernate, sleep, etc
  $win_r->{set_resume_time_area} = $win_r->{start_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{resume_operation_lb} = $win_r->{set_resume_time_area}
      -> Label(-text => 'När TidBox upptäcker återstart efter sömnläge:')
      -> pack(-side => 'left');

  $i = 0;
  for my $s ("Ingen åtgärd"      ,
             "Börja arbetsdagen" ,
             "Börja händelse"    ,
             "Sluta paus"        ,
             "Börja egen händelse" )
  {
    $win_r->{resume_operation_choise} = $win_r->{set_resume_time_area}
        -> Radiobutton(-text => $s,
                       -command => [$self => '_modified'],
                       -variable => \$self->{cfg}{resume_operation},
                       -value => $i)
        -> pack(-side => 'left');
    $i++;
  } # for #

  # Resume detection time
  $win_r->{set_resume_time_area} = $win_r->{start_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{set_resume_time_lb} = $win_r->{set_resume_time_area}
      -> Label(-text => 'Minsta tid som sömnläget varat: ')
      -> pack(-side => 'left');

  $win_r->{set_resume_time} = $win_r->{set_resume_time_area}
      -> Entry(-width           => 3,
               -validate        => 'key',
               -justify         => 'center',
               -textvariable    => \$self->{cfg}{resume_operation_time},
               -validatecommand => [$self => '_number_entry_key'],
              )
      -> pack(-side => 'left');

  $win_r->{set_resume_time_note} = $win_r->{set_resume_time_area}
      -> Label(-text => 'minuter')
      -> pack(-side => 'left');

  # Select event to register when started

  ## Area ##
  $win_r->{set_resume_event_area} = $win_r->{start_tab}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  ### Label ###
  $win_r->{set_resume_event_label} = $win_r->{set_resume_event_area}
      -> Label(-text => 'Egen händelse:')
      -> pack(-side => 'left');

  ### Event cfg ##
  my $resumetb_win_r = { name => 'ResumeTidBox',
                         -area => $win_r->{set_resume_event_area},
                       };
  $self->{resume_tidbox_win_r} = $resumetb_win_r;

  $resumetb_win_r->{event_handling} =
      new Gui::Event(
                    -event_cfg  => $self->{-event_cfg},
                    -area       => $resumetb_win_r->{-area},
                    -parentName => $resumetb_win_r->{name},
                    -validate  => [$self => '_modified', 'resume_operation_event'],
                    -buttons   => [$self => '_addButtonsResume'],
                   );

  ### TABs: Add tab for all plugins that use it ###
  while (my ($name, $ref) = each(%{$self->{plugin}})) {
    if (exists($ref->{-area})) {
      my $tab = $name . '_tab';
      $win_r->{$tab} = $win_r->{notebook}
          -> add($name, -label => $name);
      $self->callback($ref->{-area}, $win_r->{$tab});
    } # if #
  } # while #

  ### Add buttons to the button area ###

  # About button
  $win_r->{button_about} = $win_r->{button_area}
      -> Button(-text => 'Om tidbox',
                -command => [$self -> {-about_popup}, $win_r])
      -> pack(-side => 'left');

  # Break button
  $win_r->{button_break} = $win_r->{button_area}
      -> Button( -text => 'Avbryt', -command => [$self => 'withdraw'])
      -> pack(-side => 'right');
  $self->{done} = [$self => '_discard'];

  # OK button
  $win_r->{button_ok} = $win_r->{button_area}
      -> Button(-text => 'OK',
                -command => [$self => 'withdraw', 'apply'],
                -state => 'disabled')
      -> pack(-side => 'right');
  $self->{apply} = [$self => '_apply'];

  # Apply button
  $win_r->{button_apply} = $win_r->{button_area}
      -> Button(-text => 'Verkställ',
                -command => [$self => '_apply'],
                -state => 'disabled')
      -> pack(-side => 'right');

  # Restore button
  $win_r->{button_restore} = $win_r->{button_area}
      -> Button(-text => 'Återställ',
                -command => [$self => '_restore'],
                -state => 'disabled')
      -> pack(-side => 'right');

  return 0;
} # Method _setup

#----------------------------------------------------------------------------
#
# Method:      _display
#
# Description: Show the settings gui
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _display($) {
  # parameters
  my $self = shift;


  $self->_restore()
      unless (defined($self->{modified}));

  return 0;
} # Method _display

1;
__END__
