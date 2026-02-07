#
package Gui::Week;
#
#   Document: Display week
#   Version:  1.21   Created: 2026-02-01 19:10
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Week.pmx
#

my $VERSION = '1.21';
my $DATEVER = '2026-02-01';

# History information:
#
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
# 1.14  2017-10-16  Roland Vallgren
#       References to other objects in own hash
# 1.15  2019-01-25  Roland Vallgren
#       Code improvement
#       Corrected: -error_popup is an eref
# 1.16  2019-02-26  Roland Vallgren
#       Use Scrolled for scrollbars
# 1.17  2019-03-25  Roland Vallgren
#       Correction due to "Failed to AUTOLOAD 'Tk::Scrollbar::yviewMoveto'"
#       Leave selection active when times text is updated
#       Color fractions that need to be adjusted
# 1.18  2019-04-04  Roland Vallgren
#       Week worktime scrolled away, times should show
# 1.19  2019-04-08  Roland Vallgren
#       Hyperlink from weekday to Edit lost, restored.
#       Not event time not shown if no time is registered.
#       Show 0 hours as "0" for event time
# 1.20  2019-05-16  Roland Vallgren
#       Press return in view to go to edit
#       Added "Redigera" in right click menu in time area
# 1.21  2023-12-22  Roland Vallgren
#       Get week schedule from calculate
#       Week work time can be specified with hours and hundreths or minutes
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
# Method:      new
#
# Description: Create object
#              Create week GUI
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
              win       => {name => 'week'},
              condensed => 0,
              plugin_can => {-button => undef},
             };

  $self->{-title} .= ': Beräkna veckoarbetstid';

  bless($self, $class);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _formatTimeColumn
#
# Description: Format input to at least 9 char to get even columns
#              Time is formatted to hours and hundreths
#              Text is space extended to at least 9 chars
#
# Optional Arguments:
#  - Object reference
#  - Time or text to show
# Optional Arguments:
#  - If true '0,00' is shown if the number of minutes is 0
# Returns:
#  Fomatted string

sub _formatTimeColumn($$;$) {
  # parameters
  my $self = shift;
  my ($v, $z) = @_;

        #'    hh,tt'
  return '         ' unless(defined($v));
  if ($v =~ /^-?\d+$/o) {
    return '         ' if (not($z) and ($v == 0));
    return '     0   ' unless($v);
    my $t = $self->{erefs}{-calculate}->hours($v);
          #'    hh,tt'
    return '     ' . $t if (length($t) < 5);
    return '    ' . $t;
  } # if #
        #'   Måndag'
  return sprintf('%9s', $v);
} # Method _formatTimeColumn

#----------------------------------------------------------------------------
#
# Method:      _formatWeekRow
#
# Description: Show times for the whole week
#
# Arguments:
#  - Object reference
#  - Widget to insert text
#  - Width of text beginning the row
#  - Text beginning the row
#  - Reference to weekdays array
#  - Key to get for each weekday
# Returns:
#  - Accumulated time for the whole week
#  - Flex time plus or minus

sub _formatWeekRow($$$$$) {
  # parameters
  my $self = shift;
  my ($insertBox, $ev_txt_max_len, $text, $weekdays_r, $key) = @_;


  my $row_time = 0;

  $insertBox->Insert(sprintf('  %-'. $ev_txt_max_len. 's', $text));

  for my $day_r (@$weekdays_r) {

    $insertBox->Insert($self->_formatTimeColumn($day_r->{$key}));

    $row_time += $day_r->{$key}
        if $day_r->{$key};

  } # for #

  $insertBox->Insert($self->_formatTimeColumn($row_time))
      if ($self->{rowsum});

  unless (wantarray()) {
    # TODO Ugly fix: worktime should not have linefeed
    $insertBox->Insert("\n");

    return $self->{erefs}{-calculate}->hours($row_time);
  } # unless #

  # TODO Get normal time for the week once
  my $normal = $self->{erefs}{-calculate}->getWeekScheduledTime($self->{first_date});
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

  return ($self->{erefs}{-calculate}->hours($row_time),
          $sign . $self->{erefs}{-calculate}->hours($flex)
         );
} # Method _formatWeekRow

#----------------------------------------------------------------------------
#
# Method:      _insertEventTime
#
# Description: Insert event time in text
#              If adjust is needed due to deciamls, add decimals tag
#     TODO: Rewrite to insert directly to times text area
#
# Arguments:
#  - Object reference
#  - Widget to insert text in
#  - Value to add
# Returns:
#  Time in minutes

sub _insertEventTime($$$) {
  # parameters
  my $self = shift;
  my ($insertBox, $minutes) = @_;


  my $hours = $self->_formatTimeColumn($minutes, 1);
  $insertBox->Insert($hours);

  return 0
      unless ($minutes);
  return $minutes
      if ($minutes < 0);

  # Add colouring tag if value need to be adjusted
  $insertBox->tagAdd('adjust', 'insert -2 char', 'insert')
      if (($minutes % $self->{adjust_level}) != 0);

  return $minutes;
} # Method _insertEventTime

#----------------------------------------------------------------------------
#
# Method:      _insertEventLine
#
# Description: Insert activity or event line in times area
#
# Arguments:
#  - Object reference
#  - Reference to week hash with values
#  - Event text max length
#  - Hash with either activity or event
#      activity      => Activity to insert (condensed event)
#      week_comments => Comments for activity to insert
#      event         => Event to insert
# Returns:
#  -

sub _insertEventLine($$$%) {
  # parameters
  my $self = shift;
  my ($weekdays_r, $ev_len, %arg) = @_;


  my $insertBox = $self->{win}{times};

  my $row_time = 0;

  if (exists($arg{activity})) {

    $insertBox->
        Insert(sprintf('  %-'. $ev_len. 's', $arg{activity}));

    for my $day_r (@$weekdays_r) {
      $row_time += $self->
          _insertEventTime($insertBox, $day_r->{activities}{$arg{activity}});
    } # for #

  } elsif (exists($arg{event})) {

    $insertBox->
        Insert(sprintf('  %-'. $ev_len. 's', $arg{event}));

    for my $day_r (@$weekdays_r) {
      $row_time += $self->
          _insertEventTime($insertBox, $day_r->{events}{$arg{event}});
    } # for #

  } # if #

  $insertBox->Insert($self->_formatTimeColumn($row_time))
      if ($self->{rowsum});

  if (exists($arg{week_comments})) {
    $insertBox->Insert('  ');
    $insertBox->
       Insert(join(', ', sort(keys(%{$arg{week_comments}{$arg{activity}}}))));
  } # if #

  $insertBox->Insert("\n");

  return 0;
} # Method _insertEventLine

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

  my ($lock, $locked) = ($self->{erefs}{-cfg}->isLocked($self->{last_date}));

  if ($lock) {
    if ($lock == 2) {
      $win_r->{lock_week} -> configure(-text => 'Tidbox låst');
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
    $win_r->{flex}      -> configure(-background => 'lightgrey');
    $win_r->{weekworktime}  -> configure(-background => 'lightgrey');
  } else {
    $win_r->{lock_week} -> configure(-state => 'normal');
    $win_r->{lock_week} -> configure(-text => 'Lås vecka');
    $win_r->{adjust}    -> configure(-state => 'normal')
        if ($self->{erefs}{-cfg}->get('adjust_level') > 1);
    $win_r->{weekdays}  -> configure(-background => 'white');
    $win_r->{times}     -> configure(-background => 'white');
    $win_r->{worktime}  -> configure(-background => 'white');
    $win_r->{wholeweek} -> configure(-background => 'white');
    $win_r->{flex}      -> configure(-background => 'white');
    $win_r->{weekworktime}  -> configure(-background => 'white');
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
      -> Scrolled('ROText',
                  -scrollbars => 'oe',
                 )
      -> pack(-side => 'left', -expand => '1', -fill => 'both');
  $win_r->{times}->configure(
                             -wrap => 'no',
                             -height => 10,
                             -width => $self->{textboxwidth},
                            );

  $win_r->{times}->bind('<Return>' => [$self => '_edit', $win_r->{times}]);

  my $menu = $win_r->{times}->menu();
  $menu->add('radiobutton',
             -command => [$self => '_edit', $win_r->{times}],
             -label => 'Redigera',
                  -indicatoron => 0
             );

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

  $win_r->{worktime}->bind('<Return>'=>[$self => '_edit', $win_r->{worktime}]);

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
      -> pack(-side => 'right');
  $win_r->{flex} = $win_r->{flex_label}
      -> Label()
      -> pack(-side => 'right');

  $win_r->{worktime_label} = $win_r->{wholeweek_area}
      -> LabFrame(-labelside => 'left',
                  -label => 'Planerad arbetstid: ',
                  -relief => 'flat')
      -> pack(-side => 'left');
  $win_r->{weekworktime} = $win_r->{worktime_label}
      -> Label()
      -> pack(-side => 'left');

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
  $win_r->{adjust} -> configure(-state => 'disabled')
      if ($self->{erefs}{-cfg}->get('adjust_level') <= 1);

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

  $self->{erefs}{-clock}->repeat(-minute => [$self => 'tick']);
  $self->{erefs}{-times}->setDisplay($win_r->{name}, [$self => 'update']);

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
    my $event_cfg_num=$self->{erefs}{-event_cfg}->getNum($self->{last_date})-1;

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
# Method:      _selection
#
# Description: Adjust background of selection to selection
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _selection($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};
  my @selectPos = $win_r->{times}->tagRanges('sel');
  if (@selectPos) {
    $win_r->{times}->tagAdd('grey', @selectPos);
    $win_r->{times}->tagConfigure('grey', -background => 'grey');
    $win_r->{times}->tagLower('grey', 'sel');
  } else {
    $win_r->{times}->tagDelete('grey');
  } # if #
  return 0;
} # Method _selection

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
  $self->{adjust_level} = $self->{erefs}{-cfg}->get('adjust_level');

  # Can not display an archived week
  return
    $win_r->{confirm}
       -> popup(
                -title => $self->{-title} . ': Bekräfta',
                -text  => ['Kan inte visa veckan för ' . $date,
                           'Registreringar till och med ' .
                               $self->{erefs}{-cfg}->get('archive_date') .
                               ' är arkiverade.'],
               )
    if ($date le $self->{erefs}{-cfg}->get('archive_date'));

  # Calculate for all days in week
  my $match_string;
  ($match_string, $self->{condensed}) = $self->{erefs}{-event_cfg}
      -> matchString($self->{condensed}, $date);

  @{$self->{problem}} = ();
  my $week_events = {};
  my $week_comments = {};
  my $week_cmt_len = {};
  my ($weekdays_r, $event_text_max_length, $comment_text_max_length) =
       $self->{erefs}{-calculate}
           -> weekWorkTimes($date, $self->{condensed}, [$self => 'problem'],
                            $week_events, $week_comments, $week_cmt_len);

  # Record week dates if new date specified
  $self->{first_date} = $weekdays_r->[0]{date};
  $self->{last_date}  = $weekdays_r->[6]{date};
  ($self->{year}, $self->{week}) =
      $self->{erefs}{-calculate}->weekNumber($self->{last_date});

  # Setup size and heading info for week calculate GUI
  my $textboxwidth = 68 + $event_text_max_length;
  $textboxwidth += $comment_text_max_length;
  $textboxwidth += 9
      if ($self->{rowsum});

  # If widths are changed, insert weekdays
  unless ($self->{textboxwidth} == $textboxwidth) {

    $win_r->{weekdays} -> configure(-state => 'normal');
    $win_r->{weekdays} -> delete('1.0', 'end');
    $win_r->{weekdays} -> configure(-width => $textboxwidth);
#    $win_r->{weekdays} -> insert('end', $line);

    $win_r->{weekdays} ->
        Insert(sprintf('  %-' . $event_text_max_length. 's', 'Kategori'));

    my $wDayCol = $event_text_max_length + 4;

    for my $wday (1..6,0) {
       $win_r->{weekdays} ->
          Insert($self->_formatTimeColumn($self->{erefs}{-calculate}->dayStr($wday)));

      # Add tag to weekday
      my $day = 'day' . $wday;
      $win_r->{weekdays} -> tagAdd($day,
                                   '1.'.($wDayCol+($wday==4?0:1)),
                                   '1.'.($wDayCol + 7));
      $win_r->{weekdays} -> tagConfigure($day, -underline => "1");
      $win_r->{weekdays} -> tagBind($day,
                                    '<Button-1>', [$self => '_edit', $wday] );

      # Keep weekday column to allow start of Edit
      $win_r->{weekday_col}[$wday] = $wDayCol;

      $wDayCol += 9;
    } # for #

    $win_r->{weekdays} -> Insert('    Summa')
        if ($self->{rowsum});

    $win_r->{weekdays} -> configure(-state => 'disabled');

    $win_r->{times}    -> configure(-width => $textboxwidth);
    $win_r->{worktime} -> configure(-width => $textboxwidth);

    $self->{textboxwidth} = $textboxwidth;

  } # unless #

  # Update window header and buttons
  $self->_showHead();
  $self->_rowsum(1);
  $self->_condenseButtons();

  # Get scroll, insert and selection position
  my ($scroll_pos) = $win_r->{times}->yview();
  my $insertPos = $win_r->{times}->index('insert');
  my @selectPos = $win_r->{times}->tagRanges('sel');
  $win_r->{times}->bind('<<Selection>>', [$self => '_selection'] );

  # Insert the data for the week

  # Clear textareas
  $win_r->{times}    -> delete('1.0', 'end');
  $win_r->{worktime} -> delete('1.0', 'end');

  # Insert whole time
  $self->_formatWeekRow($win_r->{times}, $event_text_max_length,
                        'Hela dagen', $weekdays_r, 'whole_time');

  # Insert paus time
  $self->_formatWeekRow($win_r->{times}, $event_text_max_length,
                        'Paus', $weekdays_r, 'paus_time');

  # Insert event times
  if ($self->{condensed}) {

    # Insert Condensed events
    my $activity = "\n";

    for my $event (sort(keys(%{$week_events}))) {

      if ($event =~ /$match_string/) {

        next
            if($1 eq $activity);

        $activity = $1;

        $self->_insertEventLine($weekdays_r, $event_text_max_length,
                                activity      => $activity,
                                week_comments => $week_comments);

      } else {

        $activity = "\n";

        $self->_insertEventLine($weekdays_r, $event_text_max_length,
                                event => $event);

      } # if #

    } # for #

  } else {

    # Insert events normal
    for my $event (sort(keys(%{$week_events}))) {
      $self->_insertEventLine($weekdays_r, $event_text_max_length,
                              event => $event);
    } # for #

  } # if #

  # Color mark needed adjust
  $win_r->{times}->tagConfigure('adjust', -background => 'yellow');

  # Insert non event time

  my $not_event_time = 0;

  for my $day_r (@$weekdays_r) {
    $not_event_time += $day_r->{not_event_time}
        if $day_r->{not_event_time};
  } # for #

  $self->_formatWeekRow($win_r->{times}, $event_text_max_length,
                        'Övrig tid', $weekdays_r, 'not_event_time')
      if ($not_event_time);

  # Insert work time
  my ($week_work_time, $week_flex_time) =
      $self->_formatWeekRow($win_r->{worktime}, $event_text_max_length,
                            'Arbetstid', $weekdays_r, 'work_time');

  # Insert work time for whole week
  $win_r->{wholeweek}->configure(-text => $week_work_time);
  $win_r->{flex}->configure(-text => $week_flex_time);
  $win_r->{weekworktime}->configure(-text =>
       $self->{erefs}{-calculate}->hours(
          $self->{erefs}{-calculate}->getWeekScheduledTime($self->{first_date})
                                        )
                                   );

  # Set scroll, insert and selection position same as before update
  $win_r->{times}->yviewMoveto($scroll_pos)
      if (defined($scroll_pos));
  $win_r->{times}->SetCursor($insertPos)
      if (defined($insertPos));
  $win_r->{times}->tagAdd('sel', @selectPos)
      if (@selectPos);

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

  my ($lock, $locked) = ($self->{erefs}{-cfg}->isLocked($self->{last_date}));
  if ($lock or $self->{erefs}{-cfg}->get('adjust_level') <= 1) {
    $win_r->{adjust}->configure(-state => 'disabled');
  } else {
    $win_r->{adjust}->configure(-state => 'normal');
  } # if #

  return $self->_display()
      unless (@dates);

  # Update the week window if a date is in the week
  $self->_display()
      if ($self->{erefs}{-calculate}->
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


  $self->update($self->{erefs}{-clock}->getDate());
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
  if (not defined($wday)) {
    # TODO Find position in text area to calculate weekday
    $date = $self->{first_date};
  } elsif(ref($wday)) {
    my $col = $wday->index('insert');
    $col =~ s/^.*?\.//;
    my $r = $self->{win}{weekday_col};
    return undef
        if ($col <= $$r[1]);
    return undef
        if ($col >= $$r[0] + 9);
    for my $i (0, 6, 5, 4, 3, 2, 1) {
      if ($col >= $self->{win}{weekday_col}[$i]) {
        $date = $self->{erefs}{-calculate}->
                     stepDate($self->{last_date}, -(6-$i)-1);
        last;
      } # if #
    } # for #
  } elsif($wday == 0) {
    $date = $self->{last_date};
  } else {
    $date = $self->{erefs}{-calculate}->
                 stepDate($self->{last_date}, -(6-$wday)-1);
  } # if #
  $self->{erefs}{-edit_win}->display($date);
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


  $self->{erefs}{-year_win}->display(substr($self->{first_date}, 0, 4));

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
      $self->{erefs}{-calculate}->stepDate($self->{first_date}, -7));
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
      $self->{erefs}{-calculate}->stepDate($self->{first_date}, 7));
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


  my $old_lock_date = $self->{erefs}{-cfg}->get('lock_date');

  if ($confirm and
      ($old_lock_date lt $self->{last_date})
     ) {
    # Lock up to and including this week
    $self->{erefs}{-cfg}->set(lock_date => $self->{last_date});

  } elsif ($confirm) {
    # Unlock this week and later
    $self->{erefs}{-cfg}->set(lock_date =>
        $self->{erefs}{-calculate}->stepDate($confirm, -7));

  } elsif (($self->{last_date} ge $self->{erefs}{-clock}->getDate()) and
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
    $self->{erefs}{-cfg}->set(lock_date => $self->{last_date});

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

  $self->{erefs}{-times}->undoAddLock($old_lock_date,
                               scalar($self->{erefs}{-cfg}->get('lock_date')));

  $self->{erefs}{-cfg}->save();

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


  $self->{erefs}{-times}->_undoSet()
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
      if ($self->{erefs}{-cfg}->isLocked($self->{first_date}));

  my $win_r = $self->{win};
  @{$self->{problem}} = ();

  my ($res, $ch, $rm, $prb) = $self->{erefs}{-calculate} ->
      adjustDays($self->{first_date},
                 scalar($self->{erefs}{-cfg}->get('adjust_level')),
                 7,
                 [$self => 'problem']);

  $self->{erefs}{-times}->save();

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
# Method:      get
#
# Description: Get a value, used by plugins to get information
#              about the week to export. Possible are:
#                confirm    Confirm window
#                first_date First date of the week
#                last_date  Last date of the week
#                year       Year of the week
#                week       Week number
#                condensed  Number for condensed level
#                rowsum     Show rowsum
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
                       -initialdir => ($^O eq 'MSWin32') ?
                                          $ENV{HOMEDRIVE} : $ENV{HOME},
                       -initialfile => 'export.csv',
                       -title => $self->{-title} . ': Export',
                      );
  return undef
      unless ($file);
  my $fh = FileHandle->new($file, '>');

  unless ($fh) {
    $self->callback($self->{erefs}{-error_popup},
                    'Kan inte öppna: "' . $file . '"' , $! );
    return 1;
  } # unless #


  # Can not export an archived week
  return
    $win_r->{confirm}
       -> popup(
                -title => $self->{-title} . ': Bekräfta',
                -text  => ['Kan inte exportera veckan för ' . $date,
                           'Registreringar till och med ' .
                               $self->{erefs}{-cfg}->get('archive_date') .
                               ' är arkiverade.'],
               )
    if ($date le $self->{erefs}{-cfg}->get('archive_date'));

  # Calculate for all days in week
  my $match_string;
  ($match_string, $self->{condensed}) = $self->{erefs}{-event_cfg}
      -> matchString($self->{condensed}, $date);

  @{$self->{problem}} = ();
  my $week_events = {};
  my $week_comments = {};
  my $week_cmt_len = {};
  my ($weekdays_r, $event_text_max_length, $comment_text_max_length) =
       $self->{erefs}{-calculate}
           -> weekWorkTimes($date, $self->{condensed}, [$self => 'problem'],
                            $week_events, $week_comments, $week_cmt_len);

  # Record week dates if new date specified
  $self->{first_date} = $weekdays_r->[0]{date};
  $self->{last_date}  = $weekdays_r->[6]{date};
  ($self->{year}, $self->{week}) =
      $self->{erefs}{-calculate}->weekNumber($self->{last_date});

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
          $line .= ';' . $self->{erefs}{-calculate}->hours(
                              $day_r->{activities}{$activity} || 0, ','
                                                   );
        } # for #

        my $tmp .= join(';', sort(keys(%{$week_comments->{$activity}})));
        $tmp =~ s/,/;/g;
        $line .= ';' . $tmp;

      } else {

        $line = $event;

        for my $day_r (@$weekdays_r) {
          $line .= ';' . $self->{erefs}{-calculate}->hours(
                              $day_r->{events}{$event} || 0, ','
                                                   );
        } # for #

      } # if #

    } else {
      # Insert normal event
      $line = $event;
      $line =~ s/,/;/g;

      for my $day_r (@$weekdays_r) {
          $line .= ';' . $self->{erefs}{-calculate}->hours(
                              $day_r->{events}{$event} || 0, ','
                                                   );
      } # for #

    } # if #

    $fh->print($line, "\n");

  } # for #
  # Close file
  $self->{erefs}{-log}->log('Saved', $file)
      if ($self->{erefs}{-log});

  unless ($fh->close()) {
    $self->callback($self->{erefs}{-error_popup},
                      'Kan inte skriva: "' . $file . '"' , $! );
    return 1;
  } # unless #

  # Problems detected during calculation
  $win_r->{confirm}
      -> popup(
               -title => 'Problem',
               -text  => ['Problem under beräkningen av av arbetstid'],
               -data  => [join("\n", @{$self->{problem}})],
              )
    if (@{$self->{problem}});


  return 0;
} # Method _export

1;
__END__
