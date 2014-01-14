#
package Gui::Week;
#
#   Document: Display week
#   Version:  1.11   Created: 2013-05-27 19:17
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Week.pmx
#

my $VERSION = '1.11';
my $DATEVER = '2013-05-27';

# History information:
#
# PA1  2006-10-27  Roland Vallgren
#      First issue.
# PA2  2006-11-17  Roland Vallgren
#      Use GUI base class
# PA3  2006-12-11  Roland Vallgren
#      Use clock to get one minute tick for update
# PA4  2007-01-31  Roland Vallgren
#      Do not recalculate if withdrawn
#      Added adjust of week
#      Request confirmation to unlock a week
#      Corrected use of Confirm
# PA5  2007-03-10  Roland Vallgren
#      Adapted to new behaviour in Gui::Base
#        Let the GuiBase class add the confirm instance
#      Handle problems detected during calculation of worktime
#      Save file after adjust
# 1.6  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
# 1.7  2007-06-17  Roland Vallgren
#      Subscribe to event changes
# 1.8  2008-09-07  Roland Vallgren
#      Display when adjust is done is handled by Times
#      Undo adjust from confirm popup
# 1.9  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Terp need cfg to get settings
# 1.10  2009-07-08  Roland Vallgren
#       Event cfg match expr is compiled
# 1.11  2013-05-18  Roland Vallgren
#       Use isLocked to check lock
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent Gui::Base;

use strict;
use warnings;
use Carp;
use integer;

use Tk;
use Tk::ROText;

use Gui::Confirm;
use Terp;

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
# Description: Create object
#              Create week GUI
#
# Arguments:
#  0 - Object prototype
# Additional arguments as hash
#  -cfg        Reference to configuration hash
#  -event_cfg  Event configuration object
#  -parent_win Parent window
#  -title      Tool title
#  -times      Reference to times object
#  -calculate  Reference to calculator
#  -clock      Reference to clock
#  -year_win   Reference to Year window
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              @_,
              win       => {name => 'week'},
              condensed => 0,
             };

  $self->{-title} .= ': Beräkna veckoarbetstid';

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _formatTime
#
# Description: Format input to at least 9 char to get even columns
#              Time is formatted to hours and hundreths
#              Text is space extended to at least 9 chars
#
# Optional Arguments:
#  0 - Object reference
#  1 - Time or text to show
# Returns:
#  Fomatted string

sub _formatTime($$) {
  # parameters
  my $self = shift;
  my ($v) = @_;

        #'    hh,tt'
  return '         ' unless($v);
  if ($v =~ /^-?\d+$/o) {
    my $t = $self->{-calculate}->hours($v);
          #'    hh,tt'
    return '     ' . $t if (length($t) < 5);
    return '    ' . $t;
  } # if #
        #'   Måndag'
  return sprintf('%9s', $v);
} # Method _formatTime

#----------------------------------------------------------------------------
#
# Method:      _formatWeekRow
#
# Description: Show times for the whole week
#
# Arguments:
#  0 - Object reference
#  1 - Widget to insert text
#  2 - Width of text beginning the row
#  3 - Text beginning the row
#  4 - Reference to weekdays array
#  5 - Key to get for each weekday
# Returns:
#  Accumulated time for the whole week

sub _formatWeekRow($$$$$) {
  # parameters
  my $self = shift;
  my ($insert_box, $ev_txt_max_len, $text, $weekdays_r, $key) = @_;


  my $row_time = 0;

  my $line = sprintf('  %-'. $ev_txt_max_len. 's', $text);

  for my $day_r (@$weekdays_r) {

    $line .= $self->_formatTime($day_r->{$key});

    $row_time += $day_r->{$key} if $day_r->{$key};

  } # for #

  $line .= $self->_formatTime($row_time) if ($self->{rowsum});

  $insert_box->insert('end', $line . "\n");

  return $self->{-calculate}->hours($row_time);
} # Method _formatWeekRow

#----------------------------------------------------------------------------
#
# Method:      _showHead
#
# Description: Show window header
#              Week number Start date - End date Lock status
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _showHead($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  my $text =  join(' ', 'År:'   , $self->{year}       ,
                        'Vecka:', $self->{week}       ,
                        'Datum:', $self->{first_date} ,
                        '-'     , $self->{last_date}  );

  my ($lock, $locked) = ($self->{-cfg}->isLocked($self->{last_date}));

  if ($lock) {
    if ($lock == 2) {
      $win_r->{lock_week} -> configure(-state => 'disabled');
    } else {
      $win_r->{lock_week} -> configure(-state => 'normal');
      $win_r->{lock_week} -> configure(-text => 'Lås upp vecka');
    } # if #
    $text .= '  ' . $locked;
    $win_r->{adjust}    -> configure(-state => 'disabled');
    $win_r->{weekdays}  -> configure(-background => 'lightgrey');
    $win_r->{times}     -> configure(-background => 'lightgrey');
    $win_r->{worktime}  -> configure(-background => 'lightgrey');
    $win_r->{wholeweek} -> configure(-background => 'lightgrey');
  } else {
    $win_r->{lock_week} -> configure(-state => 'normal');
    $win_r->{lock_week} -> configure(-text => 'Lås vecka');
    $win_r->{adjust}    -> configure(-state => 'normal');
    $win_r->{weekdays}  -> configure(-background => 'white');
    $win_r->{times}     -> configure(-background => 'white');
    $win_r->{worktime}  -> configure(-background => 'white');
    $win_r->{wholeweek} -> configure(-background => 'white');
  } # if #

  $win_r->{title} -> configure(-text => $text);

  return 0;
} # Method _showHead

#----------------------------------------------------------------------------
#
# Method:      _setup
#
# Description: Setup the contents of the week window
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _setup($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};

  # Set some defaults
  $self->{textboxwidth} = 0;

  ### Column headings ###
  $win_r->{weekday_area} = $win_r->{area}
      -> Frame()
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{weekdays} = $win_r->{weekday_area}
      -> ROText(
                -wrap => 'no',
                -height => 1,
                -width => $self->{textboxwidth},
               )
      -> pack(-side => 'left', -expand => '1', -fill => 'x');

  ### Text area to show times ###
  $win_r->{times_area} = $win_r->{area}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both');

  $win_r->{times} = $win_r->{times_area}
      -> ROText(
                -wrap => 'no',
                -height => 10,
                -width => $self->{textboxwidth},
               )
      -> pack(-side => 'left', -expand => '1', -fill => 'both');

  $win_r->{scrollbar} = $win_r->{times_area}
      -> Scrollbar(-command => [yview => $win_r->{times}])
      -> pack(-side => 'left', -fill => 'y');

  $win_r->{times}
      -> configure(-yscrollcommand => [set => $win_r->{scrollbar}]);

  ### Worktime box ###
  $win_r->{worktime_area} = $win_r->{area}
      -> Frame()
      -> pack(-side => 'top', -expand => '0', -fill => 'x');

  $win_r->{worktime} = $win_r->{worktime_area}
      -> ROText(
                -wrap => 'no',
                -height => 1,
                -width => $self->{textboxwidth},
               )
      -> pack(-side => 'left', -expand => '1', -fill => 'x');

  ### Total worktime for whole week ###
  $win_r->{wholeweek_area} = $win_r->{area}
      -> Frame(-bd => '2', -relief => 'sunken')
      -> pack(-side => 'top', -fill => 'x');

  $win_r->{wholeweek_label} = $win_r->{wholeweek_area}
      -> LabFrame(-labelside => 'left',
                  -label => 'Hela veckan: ',
                  -relief => 'flat')
      -> pack(-side => 'right');
  $win_r->{wholeweek} = $win_r->{wholeweek_label}
      -> Label()
      -> pack(-side => 'right');

  ### Button area ###

  # View year button
  $win_r->{view_year} = $win_r->{button_area}
      -> Button(-text => 'År',
                -command => [$self => '_year'])
      -> pack(-side => 'left');

  # Previous week button
  $win_r->{prev} = $win_r->{button_area}
      -> Button(-text => 'Föregående vecka',
                -command => [$self => '_prev'])
      -> pack(-side => 'left');

  # Next week button
  $win_r->{next} = $win_r->{button_area}
      -> Button(-text => 'Nästa vecka',
                -command => [$self => '_next'])
      -> pack(-side => 'left');

  # Condensed recalculate buttons
  $win_r->{condense} = $win_r->{button_area}
      -> Button(-text => 'Samla',
                -command => [$self => '_condense'],
                -state => 'disabled')
      -> pack(-side => 'left');
  $win_r->{spread} = $win_r->{button_area}
      -> Button(-text => 'Sprid',
                -command => [$self => '_condense', 1],
                -state => 'disabled')
      -> pack(-side => 'left');

  # Row sum recalculate button
  $win_r->{rowsum} = $win_r->{button_area}
      -> Button(-command => [$self => '_rowsum'])
      -> pack(-side => 'left');

  # Week lock/unlock button
  $win_r->{lock_week} = $win_r->{button_area}
      -> Button(-command => [$self => '_lock'])
      -> pack(-side => 'left');

  # Week adjust button
  $win_r->{adjust} = $win_r->{button_area}
      -> Button(-text => 'Justera vecka',
                -command => [$self => '_adjust'])
      -> pack(-side => 'left');

  # Terp
  $win_r->{terp} = $win_r->{button_area}
      -> Button(-text => 'Till Terp-mall', -command => [$self => '_terp'])
      -> pack(-side => 'left');

  # Done button
  $win_r->{done} = $win_r->{button_area}
      -> Button(-text => 'Klart',
                -command => [$self => 'withdraw'])
      -> pack(-side => 'right');

  ### Register for one minute ticks and event changes ###

  $self->{-clock}->repeat(-minute => [$self => 'tick']);
  $self->{-times}->setDisplay($win_r->{name}, [$self => 'update']);

  return 0;
} # Method _setup

#----------------------------------------------------------------------------
#
# Method:      _condenseButtons
#
# Description: Set condense buttons status
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _condenseButtons($) {
  # parameters
  my $self = shift;


  unless ($self->{condensed} > 0) {
    $self->{win}{condense} -> configure(-state => 'normal');
    $self->{win}{spread}   -> configure(-state => 'disabled');
  } else {
    my $event_cfg_num = $self->{-event_cfg}->getNum($self->{last_date}) - 1;

    unless ($self->{condensed} <  $event_cfg_num) {
      $self->{win}{condense} -> configure(-state => 'disabled');
      $self->{win}{spread}   -> configure(-state => 'normal');
    } else {
      $self->{win}{condense} -> configure(-state => 'normal');
      $self->{win}{spread}   -> configure(-state => 'normal');
    } # unless #
  } # unless #

  return 0;
} # Method _condenseButtons

#----------------------------------------------------------------------------
#
# Method:      problem
#
# Description: Record problem detected during calculation
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 .. Problem strings
# Returns:
#  Reference to problems array if no problem to record is supplied

sub problem($;@) {
  # parameters
  my $self = shift(@_);

  return $self->{problem}
      unless (@_);
  push @{$self->{problem}}, @_;
  return 0;
} # Method problem

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
  my ($date) = @_;


  my $win_r = $self->{win};
  $date = $self->{last_date} unless $date;

  # Can not display an archived week
  return
    $win_r->{confirm}
       -> popup(
                -title => $self->{-title} . ': Bekräfta',
                -text  => ['Kan inte visa veckan för ' . $date,
                           'Registreringar till och med ' .
                               $self->{-cfg}->get('archive_date') .
                               ' är arkiverade.'],
               )
    if ($date le $self->{-cfg}->get('archive_date'));

  # Calculate for all days in week
  my $match_string;
  ($match_string, $self->{condensed}) = $self->{-event_cfg}
      -> matchString($self->{condensed}, $date);

  @{$self->{problem}} = ();
  my (%week_events, %week_comments, %week_cmt_len);
  my ($weekdays_r, $event_text_max_length, $comment_text_max_length) =
       $self->{-calculate}
           -> weekWorkTimes($date, $self->{condensed}, [$self => 'problem'],
                            \%week_events, \%week_comments, \%week_cmt_len);

  # Record week dates if new date specified
  $self->{first_date} = $weekdays_r->[0]{date};
  $self->{last_date}  = $weekdays_r->[6]{date};
  ($self->{year}, $self->{week}) =
      $self->{-calculate}->weekNumber($self->{last_date});

  # Setup size and heading info for week calculate GUI
  my $textboxwidth = 68 + $event_text_max_length;
  $textboxwidth += $comment_text_max_length;
  $textboxwidth += 9
      if ($self->{rowsum});

  # Change widths if required
  unless ($self->{textboxwidth} == $textboxwidth) {

    my $line = sprintf('  %-' . $event_text_max_length. 's', 'Kategori');
    for my $wday (1..6,0) {
      $line .= $self->_formatTime($self->{-calculate}->dayStr($wday));
    } # for #
    $line .= '    Summa' if ($self->{rowsum});

    $win_r->{weekdays} -> configure(-state => 'normal');
    $win_r->{weekdays} -> delete('1.0', 'end');
    $win_r->{weekdays} -> configure(-width => $textboxwidth);
    $win_r->{weekdays} -> insert('end', $line);
    $win_r->{weekdays} -> configure(-state => 'disabled');

    $win_r->{times}    -> configure(-width => $textboxwidth);
    $win_r->{worktime} -> configure(-width => $textboxwidth);

    $self->{textboxwidth} = $textboxwidth;
  } # unless #

  # Update window header and buttons
  $self->_showHead();
  $self->_rowsum(1);
  $self->_condenseButtons();

  # Insert the data for the week

  my ($scroll_pos) = $win_r->{scrollbar}->get();
  $win_r->{times}    -> delete('1.0', 'end');
  $win_r->{worktime} -> delete('1.0', 'end');

  $self->_formatWeekRow($win_r->{times}, $event_text_max_length,
                        'Hela dagen', $weekdays_r, 'whole_time');

  $self->_formatWeekRow($win_r->{times}, $event_text_max_length,
                        'Paus', $weekdays_r, 'paus_time');

  if ($self->{condensed}) {
    my $activity = "\n";
    my $row_time;
    my $line;

    for my $event (sort(keys(%week_events))) {

      $row_time = 0;

      if ($event =~ /$match_string/) {

        next if($1 eq $activity);
        $activity = $1;

        $line = sprintf('  %-'. $event_text_max_length. 's', $activity);

        for my $day_r (@$weekdays_r) {
          $line .= $self->_formatTime($day_r->{activities}{$activity});
          $row_time += $day_r->{activities}{$activity}
              if (exists($day_r->{activities}{$activity}));
        } # for #

        $line .= $self->_formatTime($row_time)
            if ($self->{rowsum});

        $line .= '  ' . join(', ', sort(keys(%{$week_comments{$activity}})));

      } else {

        $activity = "\n";

        $line = sprintf('  %-'. $event_text_max_length. 's', $event);

        for my $day_r (@$weekdays_r) {
          $line .= $self->_formatTime($day_r->{events}{$event});
          $row_time += $day_r->{events}{$event}
              if (exists($day_r->{events}{$event}));
        } # for #

        $line .= $self->_formatTime($row_time)
            if ($self->{rowsum});

      } # if #

      $win_r->{times}
          -> insert('end', $line . "\n");

    } # for #

  } else {
    my $row_time;
    my $line;

    for my $event (sort(keys(%week_events))) {

      $row_time = 0;
      $line = sprintf('  %-'. $event_text_max_length. 's', $event);

      for my $day_r (@$weekdays_r) {
        $line .= $self->_formatTime($day_r->{events}{$event});
        $row_time += $day_r->{events}{$event}
            if (exists($day_r->{events}{$event}));
      } # for #

      $line .= $self->_formatTime($row_time)
          if ($self->{rowsum});

      $win_r->{times}
          -> insert('end', $line . "\n");
    } # for #

  } # if #

  $self->_formatWeekRow($win_r->{times}, $event_text_max_length,
                        'Övrig tid', $weekdays_r, 'not_event_time');

  my $week_work_time =
      $self->_formatWeekRow($win_r->{worktime}, $event_text_max_length,
                            'Arbetstid', $weekdays_r, 'work_time');

  $win_r->{wholeweek}->configure(-text => $week_work_time);

  # Set scroll position same as before update
  $win_r->{times} -> yviewMoveto($scroll_pos)
      if ($scroll_pos);

  # Problems detected during calculation
  $win_r->{confirm}
      -> popup(
               -title => 'Problem',
               -text  => ['Problem under beräkningen av av arbetstid'],
               -data  => [join("\n", @{$self->{problem}})],
              )
    if (@{$self->{problem}});


  return 0;
} # Method _display

#----------------------------------------------------------------------------
#
# Method:      update
#
# Description: Update week window. Contents is recalculated if a date is
#              within the shown week, if dates are specified.
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

  return 0 unless (Exists($win_r->{win}));
  return 0 if $win_r->{win}->state() eq 'withdrawn';

  return $self->_display()
      unless (@dates);


  # Update the week window if a date is in the week
  $self->_display()
      if ($self->{-calculate}->
            impactedDate([$self->{first_date}, $self->{last_date}], @dates));

  return 0;
} # Method update

#----------------------------------------------------------------------------
#
# Method:      tick
#
# Description: Update week One minute clock tick from clock
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub tick($) {
  # parameters
  my $self = shift;


  $self->update($self->{-clock}->getDate());
  return 0;
} # Method tick

#----------------------------------------------------------------------------
#
# Method:      _year
#
# Description: Show whole year window
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _year($) {
  # parameters
  my $self = shift;


  $self->{-year_win}->display(substr($self->{first_date}, 0, 4));

  return 0;
} # Method _year

#----------------------------------------------------------------------------
#
# Method:      _prev
#
# Description: Show previous week
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _prev($) {
  # parameters
  my $self = shift;

  $self->_display(
      $self->{-calculate}->stepDate($self->{first_date}, -7));
  return 0;
} # Method _prev

#----------------------------------------------------------------------------
#
# Method:      _next
#
# Description: Show next week
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _next($) {
  # parameters
  my $self = shift;

  $self->_display(
      $self->{-calculate}->stepDate($self->{first_date}, 7));
  return 0;
} # Method _next

#----------------------------------------------------------------------------
#
# Method:      _condense
#
# Description: Recalculate in more condensed mode
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Less condensed mode
# Returns:
#  -

sub _condense($;$) {
  # parameters
  my $self = shift;
  my ($less) = @_;


  if ($less) {
    $self->{condensed}--;
  } else {
    $self->{condensed}++;
  } # if #

  $self->_display();
  return 0;
} # Method _condense

#----------------------------------------------------------------------------
#
# Method:      _rowsum
#
# Description: Toggle rowsum and recalculate
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - If defined, only update button
# Returns:
#  -

sub _rowsum($;$) {
  # parameters
  my $self = shift;
  my ($show) = @_;


  unless ($show) {
    if ($self->{rowsum}) {
      $self->{rowsum} = 0;
    } else {
      $self->{rowsum} = 1;
    } # if #
    $self->_display();
  } # unless #

  if ($self->{rowsum}) {
    $self->{win}{rowsum} -> configure(-text => 'Ej Radsumma');
  } else {
    $self->{win}{rowsum} -> configure(-text => 'Radsumma');
  } # if #

  return 0;
} # Method _rowsum

#----------------------------------------------------------------------------
#
# Method:      _lock
#
# Description: Lock up to this week or unlock if locked
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Confirmed date
# Returns:
#  -

sub _lock($;$) {
  # parameters
  my $self = shift;
  my ($confirm) = @_;


  my $old_lock_date = $self->{-cfg}->get('lock_date');

  if ($confirm and
      ($old_lock_date lt $self->{last_date})
     ) {
    # Lock up to and including this week
    $self->{-cfg}->set(lock_date => $self->{last_date});

  } elsif ($confirm) {
    # Unlock this week and later
    $self->{-cfg}->set(lock_date =>
        $self->{-calculate}->stepDate($confirm, -7));

  } elsif (($self->{last_date} ge $self->{-clock}->getDate()) and
         ($old_lock_date lt $self->{last_date})
        ) {
    # Confirm to lock today or later date
    my $win_r = $self->{win};
    $win_r->{confirm}
         -> popup(
                  -title => 'bekräfta',
                  -text  => ['Vill du låsa idag?',
                             ],
                  -action => [$self, '_lock', $self->{last_date}],
                 );
    return 0;

  } elsif ($old_lock_date lt $self->{last_date}) {
    # Lock up to and including this week
    $self->{-cfg}->set(lock_date => $self->{last_date});

  } else {
    # Confirm the unlock
    my $win_r = $self->{win};
    $win_r->{confirm}
         -> popup(
                  -title => 'bekräfta',
                  -text  => ['Vill du låsa upp vecka ' . $self->{week} . '?',
                             ],
                  -action => [$self, '_lock', $self->{last_date}],
                 );
    return 0;

  } # if #

  $self->{-times}->undoAddLock($old_lock_date, 
                               scalar($self->{-cfg}->get('lock_date')));

  $self->{-cfg}->save();

  $self->_showHead();


  return 0;
} # Method _lock

#----------------------------------------------------------------------------
#
# Method:      _undo
#
# Description: Undo adjust if requested
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - True if last adjust should be undone
# Returns:
#  -

sub _undo($;$) {
  # parameters
  my $self = shift;
  my ($undo) = @_;


  $self->{-times}->_undoSet()
      if ($undo);

  return 0;
} # Method _undo

#----------------------------------------------------------------------------
#
# Method:      _adjust
#
# Description: Adjust week
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _adjust($) {
  # parameters
  my $self = shift;


  return 0
      if ($self->{-cfg}->isLocked($self->{first_date}));

  my $win_r = $self->{win};
  @{$self->{problem}} = ();

  my ($res, $ch, $rm, $prb) = $self->{-calculate} ->
      adjustDays($self->{first_date}, 
                 scalar($self->{-cfg}->get('adjust_level')),
                 7,
                 [$self => 'problem']);

  $self->{-times}->save();


  my $broke = '';

  $broke = "\n\n" . 'Justeringen avbröts på grund av problem'
       if ($res);

  if ($ch or $rm) {
    $win_r->{confirm}
         -> popup(
                  -title => 'resultat av justering',
                  -text  => ['Justering resultat' . $broke . ':'],
                  -data  => [$prb],
                  -buttons => [
                               'Stäng', [ $self, '_undo', 0 ],
                               'Ångra', [ $self, '_undo', 1 ],
                              ]
                 );
  } else {
    $win_r->{confirm}
         -> popup(
                  -title => 'resultat av justering',
                  -text  => ['Inga justeringar gjordes' . $broke . ':'],
                  -data  => [$prb],
                 );
  } # if #

  return 0;
} # Method _adjust

#----------------------------------------------------------------------------
#
# Method:      _terp
#
# Description: Export week to terp template file
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _terp($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  my $tpt = $self->{-cfg}->get('terp_template');

  $tpt = $win_r->{win}
        -> getOpenFile(-defaultextension => '.csv',
                       -filetypes => [
                           ['csv files' , '.csv'],
                           ['Text files', '.txt'],
                           ['All Files' , '*'   ],
                                     ],
                       -initialdir => ($^O eq 'MSWin32') ? $ENV{HOMEDRIVE} : $ENV{HOME},
                       -initialfile => 'export.csv',
                       -title => $self->{-title} . ': Terp mall',
                      )
      unless ($tpt and (-f $tpt));

  unless ($tpt) {
    $win_r->{confirm}
       ->popup(
               -title => ': Fel',
               -text  => ['Ingen TERP mall angiven!'
                         ],
              );
    $self->{-cfg}->set(terp_template => undef);
    return 0;
  } # unless #

  unless (-f $tpt) {
    $win_r->{confirm}
       -> popup(
                -title => ': Fel',
                -text  => ['Kan inte hitta TERP mall: '.
                           $tpt
                          ],
               );
    $self->{-cfg}->set(terp_template => undef);
    return 0;
  } # unless #

  my $res =
    exportTo Terp(
                  $self->{last_date} ,
                  $self->{-event_cfg},
                  $self->{-calculate},
                  $self->{-cfg}      ,
                  $win_r             ,
                  $tpt,
                 );
  if (defined($res)) {
    $self->{-cfg}->set(terp_template => $tpt);
  } else {
    $self->{-cfg}->set(terp_template => undef);
  } # if #

  return 0;
} # Method _terp

1;
__END__
