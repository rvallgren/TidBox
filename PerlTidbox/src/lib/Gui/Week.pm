#
package Gui::Week;
#
#   Document: Display week
#   Version:  1.13   Created: 2017-09-26 11:04
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Week.pmx
#

my $VERSION = '1.13';
my $DATEVER = '2017-09-26';

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
# 1.12  2017-02-24  Roland Vallgren
#       Display flex time as +/- hours
# 1.13  2017-06-13  Roland Vallgren
#       Added links to start edit from weekdays
#       Added export of week data
#       Removed usage of Terp.pm
#       Added handling of plugin to add buttons
#       Setting terp_normal_worktime renamed to ordinary_week_work_time
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
use Tk::ROText;
use Tk::LabFrame;

use Gui::Confirm;

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
              plugin_can => {-button => undef},
             };

  $self->{-title} .= ': Ber�kna veckoarbetstid';

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
        #'   M�ndag'
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

  if (wantarray()) {
    my $normal = $self->{-cfg}->get('ordinary_week_work_time') * 60;
    my ($flex, $sign);
    if ($row_time > $normal) {
      $flex = $row_time - $normal;
      $sign = '+';
    } elsif ($row_time < $normal) {
      $flex = $normal - $row_time;
      $sign = '-';
    } else {
      $flex = '0';
      $sign = '';
    } # if #

    return ($self->{-calculate}->hours($row_time),
            $sign . $self->{-calculate}->hours($flex)
           );
  } # if #
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
  my $text =  join(' ', '�r:'   , $self->{year}       ,
                        'Vecka:', $self->{week}       ,
                        'Datum:', $self->{first_date} ,
                        '-'     , $self->{last_date}  );

  my ($lock, $locked) = ($self->{-cfg}->isLocked($self->{last_date}));

  if ($lock) {
    if ($lock == 2) {
      $win_r->{lock_week} -> configure(-state => 'disabled');
    } else {
      $win_r->{lock_week} -> configure(-state => 'normal');
      $win_r->{lock_week} -> configure(-text => 'L�s upp vecka');
    } # if #
    $text .= '  ' . $locked;
    $win_r->{adjust}    -> configure(-state => 'disabled');
    $win_r->{weekdays}  -> configure(-background => 'lightgrey');
    $win_r->{times}     -> configure(-background => 'lightgrey');
    $win_r->{worktime}  -> configure(-background => 'lightgrey');
    $win_r->{wholeweek} -> configure(-background => 'lightgrey');
    $win_r->{flex}      -> configure(-background => 'lightgrey');
  } else {
    $win_r->{lock_week} -> configure(-state => 'normal');
    $win_r->{lock_week} -> configure(-text => 'L�s vecka');
    $win_r->{adjust}    -> configure(-state => 'normal');
    $win_r->{weekdays}  -> configure(-background => 'white');
    $win_r->{times}     -> configure(-background => 'white');
    $win_r->{worktime}  -> configure(-background => 'white');
    $win_r->{wholeweek} -> configure(-background => 'white');
    $win_r->{flex}      -> configure(-background => 'white');
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

  $win_r->{flex_label} = $win_r->{wholeweek_area}
      -> LabFrame(-labelside => 'left',
                  -label => 'Plus/minus-tid: ',
                  -relief => 'flat')
      -> pack(-side => 'left');
  $win_r->{flex} = $win_r->{flex_label}
      -> Label()
      -> pack(-side => 'right');

  ### Button area ###

  # View year button
  $win_r->{view_year} = $win_r->{button_area}
      -> Button(-text => '�r',
                -command => [$self => '_year'])
      -> pack(-side => 'left');

  # Previous week button
  $win_r->{prev} = $win_r->{button_area}
      -> Button(-text => 'F�reg�ende vecka',
                -command => [$self => '_prev'])
      -> pack(-side => 'left');

  # Next week button
  $win_r->{next} = $win_r->{button_area}
      -> Button(-text => 'N�sta vecka',
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

  # Export
  $win_r->{export} = $win_r->{button_area}
      -> Button(-text => 'Exportera', -command => [$self => '_export'])
      -> pack(-side => 'left');

  while (my ($name, $ref) = each(%{$self->{plugin}})) {
    if (exists($ref->{-button})) {
      my ($label, $callback) = $self->callback($ref->{-button});
      $win_r->{'button_' . $name} = $win_r->{button_area}
          -> Button(-text => $label, -command => $callback)
          -> pack(-side => 'left');
    } # if #
  } # while #

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
                -title => $self->{-title} . ': Bekr�fta',
                -text  => ['Kan inte visa veckan f�r ' . $date,
                           'Registreringar till och med ' .
                               $self->{-cfg}->get('archive_date') .
                               ' �r arkiverade.'],
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

  # Add tags to weekdays
  my $wDayCol = $event_text_max_length + 4;

  for my $wday (1..6,0) {
    my $day = 'day' . $wday;
    $win_r->{weekdays} -> tagAdd($day,
                                 '1.'.($wDayCol+($wday==4?0:1)),  '1.'.($wDayCol + 7));
    $win_r->{weekdays} -> tagConfigure($day, -underline => "1");
    $win_r->{weekdays} -> tagBind($day, '<Button-1>', [$self => '_edit', $wday] );
    $wDayCol += 9;
  } # for #

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
                        '�vrig tid', $weekdays_r, 'not_event_time');

  my ($week_work_time, $week_flex_time) =
      $self->_formatWeekRow($win_r->{worktime}, $event_text_max_length,
                            'Arbetstid', $weekdays_r, 'work_time');

  $win_r->{wholeweek}->configure(-text => $week_work_time);
  $win_r->{flex}->configure(-text => $week_flex_time);

  # Set scroll position same as before update
  $win_r->{times} -> yviewMoveto($scroll_pos)
      if ($scroll_pos);

  # Problems detected during calculation
  $win_r->{confirm}
      -> popup(
               -title => 'Problem',
               -text  => ['Problem under ber�kningen av av arbetstid'],
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
# Method:      _edit
#
# Description: Start editing the selected day
#
# Arguments:
#  - Object reference
#  - Day of week to edit
# Returns:
#  -

sub _edit($$) {
  # parameters
  my $self = shift;
  my ($wday) = @_;

  my $date;
  if($wday == 0) {
    $date = $self->{last_date};
  } else {
    $date = $self->{-calculate}->stepDate($self->{last_date}, -(6-$wday)-1);
  } # if #
  $self->{-edit_win}->display($date);
  return 0;
} # Method _edit

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
                  -title => 'bekr�fta',
                  -text  => ['Vill du l�sa idag?',
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
                  -title => 'bekr�fta',
                  -text  => ['Vill du l�sa upp vecka ' . $self->{week} . '?',
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

  $broke = "\n\n" . 'Justeringen avbr�ts p� grund av problem'
       if ($res);

  if ($ch or $rm) {
    $win_r->{confirm}
         -> popup(
                  -title => 'resultat av justering',
                  -text  => ['Justering resultat' . $broke . ':'],
                  -data  => [$prb],
                  -buttons => [
                               'St�ng', [ $self, '_undo', 0 ],
                               '�ngra', [ $self, '_undo', 1 ],
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
# Method:      get
#
# Description: Get a setting
#
# Arguments:
#  - Object reference
#  - Key to get
# Returns:
#  Value of setting

sub get($$) {
  # parameters
  my $self = shift;
  my ($key) = @_;

  return $self->{win}{confirm}
      if ($key eq 'confirm');

  return $self->{$key};
} # Method get

#----------------------------------------------------------------------------
#
# Method:      _export
#
# Description: Calculate and export work times for the week
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - New date to display
# Returns:
#  -

sub _export($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  my $win_r = $self->{win};
  $date = $self->{last_date} unless $date;

  # Get filename to export to
  my $file = $win_r->{win}
        -> getSaveFile(-defaultextension => '.csv',
                       -filetypes => [
                           ['csv files' , '.csv'],
                           ['Text files', '.txt'],
                           ['All Files' , '*'   ],
                                     ],
                       -initialdir => ($^O eq 'MSWin32') ? $ENV{HOMEDRIVE} : $ENV{HOME},
                       -initialfile => 'export.csv',
                       -title => $self->{-title} . ': Export',
                      );
  return undef
      unless ($file);
  my $fh = new FileHandle($file, '>');

  unless ($fh) {
    $self->callback($self->{-error_popup}, 'Kan inte �ppna: "' . $file . '"' , $! );
    return 1;
  } # unless #


  # Can not export an archived week
  return
    $win_r->{confirm}
       -> popup(
                -title => $self->{-title} . ': Bekr�fta',
                -text  => ['Kan inte exportera veckan f�r ' . $date,
                           'Registreringar till och med ' .
                               $self->{-cfg}->get('archive_date') .
                               ' �r arkiverade.'],
               )
    if ($date le $self->{-cfg}->get('archive_date'));

  # Calculate for all days in week
  my $match_string;
  ($match_string, $self->{condensed}) = $self->{-event_cfg}
      -> matchString($self->{condensed}, $date);

  @{$self->{problem}} = ();
  my $week_events = {};
  my $week_comments = {};
  my $week_cmt_len = {};
  my ($weekdays_r, $event_text_max_length, $comment_text_max_length) =
       $self->{-calculate}
           -> weekWorkTimes($date, $self->{condensed}, [$self => 'problem'],
                            $week_events, $week_comments, $week_cmt_len);

  # Record week dates if new date specified
  $self->{first_date} = $weekdays_r->[0]{date};
  $self->{last_date}  = $weekdays_r->[6]{date};
  ($self->{year}, $self->{week}) =
      $self->{-calculate}->weekNumber($self->{last_date});

  # Print the data for the week

  # Insert event times
  # TODO We can not handle ',' in events right now
  #      Comma ',' is replaced with semicolon ';' ...
  #      Comma in event text can not be differentiated from comma in times.dat
  my $activity = "\n";
  for my $event (sort(keys(%{$week_events}))) {
    my $line;
    if ($self->{condensed}) {
      # Insert condensed event

      if ($event =~ /$match_string/) {

        next if($1 eq $activity);
        $activity = $1;

        $line = $activity;
        $line =~ s/,/;/g;

        for my $day_r (@$weekdays_r) {
          $line .= ';' . $self->{-calculate}->hours(
                              $day_r->{activities}{$activity} || 0, ','
                                                   );
        } # for #

        my $tmp .= join(';', sort(keys(%{$week_comments->{$activity}})));
        $tmp =~ s/,/;/g;
        $line .= ';' . $tmp;

      } else {

        $line = $event;

        for my $day_r (@$weekdays_r) {
          $line .= ';' . $self->{-calculate}->hours(
                              $day_r->{events}{$event} || 0, ','
                                                   );
        } # for #

      } # if #

    } else {
      # Insert normal event
      $line = $event;
      $line =~ s/,/;/g;

      for my $day_r (@$weekdays_r) {
          $line .= ';' . $self->{-calculate}->hours(
                              $day_r->{events}{$event} || 0, ','
                                                   );
      } # for #

    } # if #

    $fh->print($line, "\n");

  } # for #
  # Close file
  $self->{-log}->log('Saved', $file)
      if ($self->{-log});

  unless ($fh->close()) {
    $self->callback($self->{-error_popup}, 'Kan inte skriva: "' . $file . '"' , $! );
    return 1;
  } # unless #

  # Problems detected during calculation
  $win_r->{confirm}
      -> popup(
               -title => 'Problem',
               -text  => ['Problem under ber�kningen av av arbetstid'],
               -data  => [join("\n", @{$self->{problem}})],
              )
    if (@{$self->{problem}});


  return 0;
} # Method _export

1;
__END__
