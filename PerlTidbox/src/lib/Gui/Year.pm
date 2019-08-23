#
package Gui::Year;
#
#   Document: Display all weeks in the years
#   Version:  1.4   Created: 2019-08-15 14:17
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Year.pmx
#

my $VERSION = '1.4';
my $DATEVER = '2019-08-15';

# History information:
#
# 1.0  2007-06-27  Roland Vallgren
#      First issue
# 1.1  2008-04-05  Roland Vallgren
#      Added archive
# 1.2  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.3  2013-05-18  Roland Vallgren
#      Handle session lock
# 1.4  2017-10-16  Roland Vallgren
#      References to other objects in own hash
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

use constant NO_DATE => '0000-00-00';

use constant UNLOCKED => 0;
use constant LOCKED   => 1;
use constant ARCHIVED => 2;

use constant HEAD_ARCHIVE => 'Arkiv';

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create object
#              Create Year GUI
#
# Arguments:
#  0 - Object prototype
# Additional arguments as hash
#  -title      Tool title
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              @_,
              win    => {name => 'year'},
              date   => undef,
              weeks  => {},
             };

  $self->{-title} .= ': Översikt veckor';

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _weeks
#
# Description: Update out all years and all weeks
#
# Arguments:
#  0 - Object reference
# Returns:
#  True if there is changes

sub _weeks($;$) {
  # parameters
  my $self = shift;
  my ($year) = @_;


  my $calc = $self->{erefs}{-calculate};
  my $wref = $self->{weeks};
  my $c = 0;

  my ($date, $t_y, $t_w, $t_yw, $t_d, $wr);
  my ($p_date, $p_yw)= ('', '');

  my $arch = $self->{erefs}{-cfg}->get('archive_date');
  my $lock = $self->{erefs}{-cfg}->get('lock_date');

  for my $ref ($self->{erefs}{-times}->getSortedRefs($year)) {

    $date = substr($$ref, 0, 10);

    next
        if ($p_date eq $date);

    $p_date = $date;

    $t_d = substr($date, 5, 5);

    ($t_y, $t_w) = $calc->weekNumber($date);
    $t_yw = $t_y . 'v' . $t_w;

    if ($p_yw eq $t_yw) {

      if ($wr->{last} lt $t_d) {
        $wr->{last} = $t_d;
        $c = 1;
      } # if #

    } else {

      unless (exists($wref->{$t_y}{$t_w})) {
        $wref->{$t_y}{$t_w} =
              {
               first  => $t_d,
               last   => $t_d,
               monday => $calc->dayInWeek($t_y, $t_w, 1),
               sunday => $calc->dayInWeek($t_y, $t_w, 7),
               lock   => 0,
              };
        my $yr = $wref->{$t_y};
        $wr = $yr->{$t_w};

        unless (exists($yr->{last})) {
          $yr->{first} = $calc->dayInWeek($t_y, 1, 1);
          $yr->{last}  = $calc->stepDate(
                                         $calc->dayInWeek($t_y + 1, 1, 7),
                                         -7
                                        );
        } # unless #

        $c = 1;

      } else {

        $wr = $wref->{$t_y}{$t_w};

        if ($wr->{first} gt $t_d) {
          $wr->{first} = $t_d;
          $c = 1;
        } # if #

        if ($wr->{last} lt $t_d) {
          $wr->{last} = $t_d;
          $c = 1;
        } # if #

      } # unless #

      $p_yw = $t_yw;

    } # if #

    $self->{dirty}{$t_y} = 1
        if ($c);
  } # for #

  for $t_y (keys(%{$wref})) {
    next
        unless(ref($wref->{$t_y}));
    for $t_w (keys(%{$wref->{$t_y}})) {
      $wr = $wref->{$t_y}{$t_w};
      next
          unless(ref($wr));
      my $status;
      if ($wr->{sunday} le $arch) {
        $status = ARCHIVED;

      } elsif ($wr->{sunday} le $lock) {
        $status = LOCKED;

      } else {
        $status = UNLOCKED;

      } # if #

      if ($status != $wr->{lock}) {
        $wr->{lock} = $status;
        $self->{dirty}{$t_y} = 1;
        $c = 1;
      } # if #
    } # for #
    $self->{dirty}{$t_y} = 1
        if ($c);
  } # for #

  return $c;
} # Method _weeks

#----------------------------------------------------------------------------
#
# Method:      _reviseTab
#
# Description: Revise the contents for the tab
#                Weeks for the a year or archive contents for the archive
#              Changes will be displayed
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Name of tab
# Returns:
#  -

sub _reviseTab($;$) {
  # parameters
  my $self = shift;
  my ($name) = @_;


  $name = $self->{win}{notebook}->raised()
      unless $name;

  my $win_r = $self->{win};
  my $a_r = $win_r->{$name};

  if ($name eq HEAD_ARCHIVE) {
    # Add archive tab contents
    unless (exists($a_r->{archive_date_area})) {
      # Create archive area

      ### Archive date
      $a_r->{archive_date_area} = $a_r->{area}
          -> Frame(-bd => '2', -relief => 'raised')
          -> pack(-side => 'top', -expand => '0', -fill => 'x');

      $a_r->{archive_date_lb} = $a_r->{archive_date_area}
          -> Label(-text => 'Arkiv till och med:')
          -> pack(-side => 'left');

      $a_r->{archive_date} = $a_r->{archive_date_area}
          -> Label(-text => '')
          -> pack(-side => 'right');

      ### Load archive
      $a_r->{archive_area} = $a_r->{area}
          -> Frame(-bd => '2', -relief => 'raised')
          -> pack(-side => 'top', -expand => '0', -fill => 'x');

      $a_r->{archive_load_button} = $a_r->{archive_area}
          -> Button(-text => 'Ladda in arkiv',
                    -command => [$self => '_loadArchive'])
          -> pack(-side => 'top')
          unless ($self->{erefs}{-archive}->isLoaded());

    } # unless #

    my $ad = $self->{erefs}{-cfg}->get('archive_date');
    $a_r->{archive_date}->
        configure(-text => ($ad ne NO_DATE ? $ad : '(saknas)'));

    if (Exists($a_r->{archive_load_button})) {
      $a_r->{archive_load_button}->
          configure(-state => ($self->{erefs}{-archive}->fileExists() ?
                                  'normal' : 'disabled')
                   );
    } else {
      # Update or add a radiobutton for each archive set
      my $area = $a_r->{archive_area};
      my $n = 0;
      my $but;

      for my $date ($self->{erefs}{-archive}->getSets()) {
        $n++;
        $but = 'but_' . $n;

        my $text = 'Set nr ' . $n .
                   ': ' .  $self->{erefs}{-archive}->getSets($date) .
                   ' - ' . $date .
                   "\tArkiverat: " .
                      $self->{erefs}{-archive}->getSets($date, 'date_time');

        if (not exists($a_r->{$but})) {
          # Create a new button
          $a_r->{$but . '_a'} = $area
              -> Frame()
              -> pack(-side=>'top', -expand=>'1', -fill=>'x');
          $a_r->{$but} = $a_r->{$but . '_a'}
              -> Radiobutton(-text => $text,
                             -command => [$self, '_viewArchive'],
                             -variable => \$self->{date},
                             -value => $date,
                            )
              -> pack(-side=>'left');

          $a_r->{$but . '_t'}   = $text;

        } elsif ($a_r->{$but . '_t'} ne $text) {
          # Update an existing button
          $a_r->{$but}->configure(-text => $text,
                                  -value => $date
                                 );
          $a_r->{$but . '_t'}   = $text;

        } # if #

      } # for #

      # Remove buttons no longer needed
      while (1) {
        $n++;
        $but = 'but_' . $n;
        if (exists($a_r->{$but})) {
          $a_r->{$but . '_a'}->destroy();
          delete($a_r->{$but . '_a'});
          delete($a_r->{$but});
        } else {
          last;
        } # if #
      } # while #


    } # if #

  } else {
    # Update weeks setting
    $self->_weeks();

    # Find out geometry
    my $num = (grep(/\d/, keys(%{$self->{weeks}{$name}})) + 1) / 2;

    # Update or add a radiobutton for each week
    my $ref = $self->{weeks}{$name};
    my $area;
    my $n = $num;
    my $c = 0;

    for my $week (sort {$a <=> $b} (grep(/^\d/, keys(%{$ref})))) {

      if ($n < $num) {

        $n++;

      } else {

        $area = 'col_' . $c;

        unless (exists($a_r->{$area})) {

          my $xa = $a_r->{area}
              -> Frame()
              -> pack(-side => 'left', -expand => '1', -fill => 'y');
          $a_r->{$area} = $xa
              -> Frame(-bd => '2', -relief => 'raised')
              -> pack(-side => 'top', -expand => '0', -fill => 'both');

        } # unless #

        $c++;
        $n = 1;

      } # if #

      my $but = 'but_' . $c . '_' . $n;

      my $text = 'Vecka: ' . $week .
                 ' Datum: ' . $ref->{$week}{first} .
                      ' - ' . $ref->{$week}{last};

      $text .= ' : Låst!'
          unless ($ref->{$week}{lock} == UNLOCKED);

      if (not exists($a_r->{$but})) {
        # Create a new button
        $a_r->{$but . '_a'} = $a_r->{$area}
            -> Frame()
            -> pack(-side=>'top', -expand=>'1', -fill=>'x');
        $a_r->{$but} = $a_r->{$but . '_a'}
            -> Radiobutton(-text => $text,
                           -command => [$self, '_viewWeek'],
                           -variable => \$self->{date},
                           -value => $ref->{$week}{sunday},
                          )
            -> pack(-side=>'left');

        $a_r->{$but . '_t'}   = $text;

      } elsif ($a_r->{$but . '_t'} ne $text) {
        # Update an existing button
        $a_r->{$but}->configure(-text => $text,
                                -value => $ref->{$week}{sunday}
                               );
        $a_r->{$but . '_t'}   = $text;

      } # if #

      $a_r->{$but}->configure(-state =>
          ($ref->{$week}{lock} == ARCHIVED ? 'disabled' : 'normal')
                             );

    } # for #

  } # if #

  $self->{dirty}{$name} = 0;
  $self->{date} = '';

  return 0;
} # Method _reviseTab

#----------------------------------------------------------------------------
#
# Method:      _viewTab
#
# Description: A tab is raised
#              A year tab: clear date, disable week buttons and
#                          enable year button
#              Archive tab: Disable buttons
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Name of tab to view
# Returns:
#  -

sub _viewTab($;$) {
  # parameters
  my $self = shift;
  my ($name) = @_;


  $self->{date} = '';

  my $win_r = $self->{win};

  $name = $self->{win}{notebook}->raised()
      unless ($name);

  $self->_reviseTab($name)
      if ($self->{dirty}{$name});

  if ($name eq HEAD_ARCHIVE) {
    # Update buttons
    $win_r->{button_left}  -> configure(-text => 'Slå ihop med föregående',
                                        -state => 'disabled');
    $win_r->{button_midd}  -> configure(-text => 'Importera',
                                        -state => 'disabled');
    $win_r->{button_right} -> configure(-text => 'Ta bort',
                                        -state => 'disabled');

  } else {
    # Update buttons
    $win_r->{button_left}  -> configure(-text => 'Visa veckan',
                                        -state => 'disabled');
    $win_r->{button_midd}  -> configure(-text => 'Arkivera till och med vecka',
                                        -state => 'disabled');
    # Archive year button
    $win_r->{button_right} -> configure(
        -text => 'Arkivera till och med år ' . $name,
        -state => ((exists($self->{weeks}{$name}{last}) and
                    ($self->{weeks}{$name}{last} lt
                                 $self->{erefs}{-clock}->getDate()) and
                    ($self->{erefs}{-cfg}->get('archive_date') lt
                                       $self->{weeks}{$name}{last}) and
                     not $self->{erefs}{-cfg}->isSessionLocked()
                   )
                   ? 'normal' : 'disabled'
                  ));

  } # if #

  return 0;
} # Method _viewTab

#----------------------------------------------------------------------------
#
# Method:      _addTab
#
# Description: Add a tab
#
# Arguments:
#  0 - Object reference
#  1 - Name of the tab
# Returns:
#  -

sub _addTab($$) {
  # parameters
  my $self = shift;
  my ($name) = @_;


  my $win_r = $self->{win};

  $win_r->{$name}{tab} = $win_r->{notebook}
      -> add($name,
             -label => $name,
             -createcmd => [$self, '_reviseTab', $name],
             -raisecmd  => [$self, '_viewTab', $name],
            );

  $win_r->{$name}{area} = $win_r->{$name}{tab}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  return 0;
} # Method _addTab

#----------------------------------------------------------------------------
#
# Method:      _viewWeek
#
# Description: Enable buttons
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _viewWeek($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  # View week button
  $win_r->{button_left} -> configure(-state => 'normal');

  # Archive week button
  $win_r->{button_midd} -> configure(
       -state => (  ($self->{erefs}{-clock}->getDate() le $self->{date} or
                     $self->{erefs}{-cfg}->isSessionLocked())
                  ? 'disabled' : 'normal'
                 ));

  return 0;
} # Method _viewWeek

#----------------------------------------------------------------------------
#
# Method:      _viewArchive
#
# Description: Enable buttons
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _viewArchive($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  my $a_r = $win_r->{HEAD_ARCHIVE()};

  my $n = 0;
  my $but;

  # Enable buttons
  for my $date ($self->{erefs}{-archive}->getSets()) {
    $n++;
    $but = undef;
    next
        unless ($self->{date} eq $date);
    $but = 'but_' . $n;
    if (exists($a_r->{$but})) {
      if ($n == 1) {
        # Remove only allowed for the oldest
        $win_r->{button_right} ->
             configure(-state => $self->{erefs}{-cfg}->isSessionLocked()
                                              ? 'disabled' : 'normal'
                       );
        $win_r->{button_left}  -> configure(-state => 'disabled');
      } else {
        # There must be a previous to allow join
        $win_r->{button_right} -> configure(-state => 'disabled');
        $win_r->{button_left}  -> configure(
                    -state => $self->{erefs}{-cfg}->isSessionLocked()
                               ? 'disabled' : 'normal'
                                           );

      } # if #
    } # if #
  } # while #

  $win_r->{button_midd}  -> configure(
               -state => (($but and
                            not $self->{erefs}{-cfg}->isSessionLocked())
                              ? 'normal' : 'disabled'));

  return 0;
} # Method _viewArchive

#----------------------------------------------------------------------------
#
# Method:      _doArchive
#
# Description: Archive is confirmed, archive as requested
#
# Arguments:
#  0 - Object reference
#  1 - Last date
# Returns:
#  -

sub _doArchive($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  $self->{erefs}{-week_win}->withdraw();
  $self->{erefs}{-edit_win}->withdraw();
  $self->{erefs}{-archive}->archive($date);
  $self->{dirty}{+HEAD_ARCHIVE} = 1;
  $self->update('-',
                $self->{erefs}{-archive}->getSets($date),
                $date, 
               );

  return 0;
} # Method _doArchive

#----------------------------------------------------------------------------
#
# Method:      _askArchive
#
# Description: Archive selected week or year
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Archive the whole year
# Returns:
#  -

sub _askArchive($;$) {
  # parameters
  my $self = shift;
  my ($year) = @_;


  my $win_r = $self->{win};

  my $last_date;
  my $period;

  if (defined($year)) {

    $last_date = $self->{weeks}{$year}{last};
    $period = 'år ' . $year;

  } else {

    $last_date = $self->{date};
    $period = join(' vecka ',
                   $self->{erefs}{-calculate}->weekNumber($last_date));

  } # if #

  # Today can not be archived
  return $win_r->{confirm}
       -> popup(
                -title => $self->{-title} . ': Bekräfta',
                -text  => ['Idag eller senare datum ingår i perioden för arkivering.',
                           'Det kan inte arkiveras.'],
               )
      if ($last_date ge $self->{erefs}{-clock}->getDate());


  # Confirm to archive period
  $win_r->{confirm}
        -> popup(-title  => $self->{-title} . ': Bekräfta',,
                 -text   => ['Arkivera ' . $period,
                             'Till och med: ' . $last_date,
                             'OBS: All ångra information kommer att tas bort.',
                             'OBS: Detta går inte att ångra.',
                             'Vill du arkivera registreringar?'],
                 -action => [$self, '_doArchive', $last_date],
                );


  return 0;
} # Method _askArchive

#----------------------------------------------------------------------------
#
# Method:      _loadArchive
#
# Description: Load archive from file
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _loadArchive($) {
  # parameters
  my $self = shift;


  $self->{erefs}{-archive}->load();
  my $a_r = $self->{win}{+HEAD_ARCHIVE};

  $a_r->{archive_area}->destroy();

  $a_r->{archive_area} = $a_r->{area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $self->{dirty}{+HEAD_ARCHIVE} = 1;
  $self->_viewTab(HEAD_ARCHIVE);

  return 0;
} # Method _loadArchive

#----------------------------------------------------------------------------
#
# Method:      _button
#
# Description: Analyze button press and call associated method
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _button($$;@) {
  # parameters
  my $self = shift;
  my ($button, @args) = @_;


  return 0
     unless (defined($button));

  my $name = $self->{win}{notebook}->raised();

  if ($name ne HEAD_ARCHIVE) {
    unless ($button) {

      return 0
          unless $self->{date};

      # Show the selected week
      $self->withdraw();
      $self->{erefs}{-week_win}->display($self->{date});

      return 0;

    } # unless #

    # Archive up to selected week
    return $self->_askArchive()
        if ($button == 1);

    # Archive up to selected year
    $self->_askArchive($self->{win}{notebook}->raised());
    return 0;
  } # if #

  if ($button == 0) {
    # Join selected set with previous set
    $self->{erefs}{-archive} -> joinSets($self->{date});
    $self->{dirty}{+HEAD_ARCHIVE} = 1;

  } elsif ($button == 1) {
    # Import archive set
    $self->{erefs}{-archive} -> importSet($self->{date});
    $self->{dirty}{+HEAD_ARCHIVE} = 1;
    return $self->_display()

  } elsif ($button == 2) {
    # Confirm to remove archive set
    $self->{win}{confirm}
          -> popup(-title  => $self->{-title} . ': Bekräfta',,
                   -text   => ['Tag bort arkiv set: ' . $self->{date},
                               'OBS: Detta går inte att ångra.',
                               'Vill du ta bort settet?'],
                   -action => [$self, '_button', 3, $self->{date}],
                  );
    return;

  } elsif ($button == 3) {
    # Remove archive set
    $self->{erefs}{-archive} -> removeSet($args[0]);
    $self->{dirty}{+HEAD_ARCHIVE} = 1;

    # Clear weeks of any removed dates
    $self->_weeks();

  } # if #

  $self->{date} = '';
  $self->_viewTab();

  return 0;
} # Method _button

#----------------------------------------------------------------------------
#
# Method:      _setup
#
# Description: Setup the contents of the year window
#
# Arguments:
#  0 - Object reference
#  1 - First year to display
# Returns:
#  -

sub _setup($$) {
  # parameters
  my $self = shift;
  my ($year) = @_;


  my $win_r = $self->{win};

  # Show clock as window heading
  $self->{erefs}{-clock}->setDisplay($win_r->{name}, $win_r->{title});

  # Create a notebook
  $win_r->{notebook} = $win_r->{area}
      -> NoteBook(-dynamicgeometry => 1)
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  # Add a tab for archive and for each year (add weeks when needed)

  $self->_weeks();

  for my $n (HEAD_ARCHIVE, sort(keys(%{$self->{weeks}}))) {
    $self->_addTab($n);
  } # for #

  ### Button area ###

  # View week button
  $win_r->{button_left} = $win_r->{button_area}
      -> Button(-text => '',
                -command => [$self, '_button', 0],
                -state => 'disabled',
               )
      -> pack(-side => 'left');

  # Archive week button
  $win_r->{button_midd} = $win_r->{button_area}
      -> Button(-text => '',
                -command => [$self, '_button', 1],
                -state => 'disabled',
               )
      -> pack(-side => 'left');

  # Archive year button
  $win_r->{button_right} = $win_r->{button_area}
      -> Button(-text => '',
                -command => [$self, '_button', 2],
               )
      -> pack(-side => 'left');

  # Done button
  $win_r->{done} = $win_r->{button_area}
      -> Button(-text => 'Klart',
                -command => [$self => 'withdraw'])
      -> pack(-side => 'right');

  # Activate the tab for the wanted year
  unless (exists($self->{weeks}{$year})) {
    if ($year le substr($self->{erefs}{-cfg}->get('archive_date'), 0, 4)) {
      $year = HEAD_ARCHIVE;
    } else {
      $year = $self->{erefs}{-clock}->getYear();
    } # if #
  } # if #
  $self->{win}{notebook}->raise($year);

  ### Register for event changes ###
  $self->{erefs}{-times}->setDisplay($win_r->{name}, [$self => 'update']);

  return 0;
} # Method _setup

#----------------------------------------------------------------------------
#
# Method:      _display
#
# Description: Calculate and display work times for the week
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - New date to display
# Returns:
#  -

sub _display($;$) {
  # parameters
  my $self = shift;
  my ($year) = @_;


  if (exists($self->{first_done})) {
    my $win_r = $self->{win};

    # Add tab for any new year
    if ($self->_weeks()) {
      for my $y (sort(keys(%{$self->{weeks}}))) {
        $self->_addTab($y)
            unless (exists($win_r->{$y}));
      } # for #
    } # if #

    # Show another tab if requested tab does not exist
    if ($year and not exists($self->{weeks}{$year})) {
      if ($year le substr($self->{erefs}{-cfg}->get('archive_date'), 0, 4)) {
        $year = HEAD_ARCHIVE;
      } else {
        $year = $self->{erefs}{-clock}->getYear();
      } # if #
    } # if #

    # Activate the tab
    if (not $year or $year eq $self->{win}{notebook}->raised()) {
      $self->_reviseTab($year);
      $self->_viewTab($year);

    } else {
      $self->{win}{notebook}->raise($year);

    } # if #
  } else {
    $self->{first_done} = 1;
  } # if #

  return 0;
} # Method _display

#----------------------------------------------------------------------------
#
# Method:      update
#
# Description: Update year window. Contents is updated if a date is
#              within the shown year, if dates is specified.
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 .. n - Dates that were changed
# Returns:
#  -

sub update($;@) {
  # parameters
  my $self = shift;
  my (@dates) = @_;


  my $win_r = $self->{win};

  return 0
      unless (Exists($win_r->{win}));
  return 0
      if $win_r->{win}->state() eq 'withdrawn';

  return $self->_display()
      unless (@dates);

  # Check if new year is added
  for my $date (@dates) {
    $self->_addTab(substr($date, 0, 4))
        unless (($date eq '-') or
                ($date eq NO_DATE) or
                exists($win_r->{substr($date, 0, 4)}));
  } # for #

  # Check if the change is in the displayed year
  my $year = $win_r->{notebook}->raised();

  if ($year ne HEAD_ARCHIVE) {
    my $y_r = $self->{weeks}{$year};

    $self->_display()
        if ($self->{erefs}{-calculate}->
                  impactedDate([$y_r->{first}, $y_r->{last}], @dates));

  } # if #

  return 0;
} # Method update

1;
__END__
