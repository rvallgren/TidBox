#
package Plugin::MyTimeXls;
#
#   Document: Plugin MyTimeXls
#   Version:  0.6   Created: 2026-02-01 19:12
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: MyTimeXls.pmx
#

my $VERSION = '0.6';
my $DATEVER = '2026-02-01';

# History information:
#
# 0.6  2024-01-03  Roland Vallgren
#      Get week schedule from Calculate and _formatTime moved to Calculate
# 0.5  2019-04-12  Roland Vallgren
#      "Doctor visit -SE" is not a valid Type in MyTime
# 0.4  2019-02-16  Roland Vallgren
#      New release of MyTime 2019-02-16
#      First column, project number, is text, not a number
# 0.3  2018-11-30  Roland Vallgren
#      Removed calculation of daily flex-time
#      Handle changes in MyTime Excel sheet format introduced 2018-11-29
# 0.2  2018-11-19  Roland Vallgren
#      Added calculation of daily flex-time
# 0.1  2018-09-11  Roland Vallgren
#      First issue based on MyTime.pm.
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

use File::Path qw();
use File::Spec;

use Spreadsheet::WriteExcel;
#use Excel::Writer::XLSX;

# Register version information
{
  use TidVersion qw(register_plugin_version);
  register_plugin_version(-name    => __PACKAGE__,
                  -version => $VERSION,
                  -date    => $DATEVER,
                  );
}
#----------------------------------------------------------------------------
#
# Constants
#


use constant
{

  PLUGIN_INFORMATION =>
     'Plugin för att exportera tid registrerad i Tidbox till Tieto MyTime Excel.' ,

  CSV_DECIMAL_KOMMA    => '.',


#  XLS_HEADER_TEMPLATE =>
# Format used 2018 week 46 and 47
#       'Project;Project name;Task;Type;Monday;Comment1;Tuesday;Comment2;' .
#       'Wednesday;Comment3;Thursday;Comment4;Friday;Comment5;Saturday;Comment6;' .
#       'Sunday;Comment7' ,
# Format introduced 2018-11-29, that is Thursday week 48
  XLS_HEADER_TEMPLATE =>
         'Project;Project name;Task number;Task name;Type;' .
          'Monday;Comment1;Time from1;Time to1;' .
         'Tuesday;Comment2;Time from2;Time to2;' .
       'Wednesday;Comment3;Time from3;Time to3;' .
        'Thursday;Comment4;Time from4;Time to4;' .
          'Friday;Comment5;Time from5;Time to5;' .
        'Saturday;Comment6;Time from6;Time to6;' .
          'Sunday;Comment7;Time from7;Time to7'
      ,
};


# 133756	GLOBAL-FLEXTIME	01 - Flex time in/out	Normal /flex -SE
# 133756, ,01 - Flex time in/out, Normal /flex -SE


# MyTimeXls configuration settings
my $PLUGIN_CFG = {
                  mytimexls_directory => '',
#            mytimexls_calculate_flextime => 0,
#            mytimexls_flex_time_template =>
#              ['133756' ,'' ,'01 - Flex time in/out', 'Normal /flex -SE'],
                 };

# MyTime event cfg example of event configurations
my $EVENT_CFG = {
    MyTimeXls => [ 'Project:d:6',
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
    MyTimeRadioXls => [ 'Project:R:' .
                  '?'        . '=>'. '?'                             . ';' .
                  'Projekt'  . '=>'. '12345'                         . ';' .
                  'Frånvaro' . '=>'. '172158'                                ,
                'Task:R:' .
                  'Projektarbete '. '=>'. '01.01 - Project work'       . ';' .
                  'Projektledning'. '=>'. '01.02 - Project manager'    . ';' .
                  'Utbildning    '. '=>'. '7.3 - Radio 5G/LTEJob Trai' . ';' .
                  'Frånvaro-Sem  '. '=>'. '1 - Vacation'               . ';' .
                  'Frånvaro-Sjuk '. '=>'. '2 - Illness'                . ';' .
                  'Frånvaro-Övrig'. '=>'. '3 - Other absence'          . ';' .
                  'Ledig-Nordic  '. '=>'. '01.1 - Nordic_UnassigHour'         ,
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
    MyTimeXlsAllaTyper =>
              [ 'Project:d:6',
                'Task:D:6',
                'Type:r:' .
                  'Normal -SE'                     . ';' .
                  'Normal / hourly paid -SE'       . ';' .
                  'Normal /paid -SE'               . ';' .
                  'Normal /saved -SE'              . ';;' .
                  'On Call II -SE'                 . ';' .
                  'On Call Over-1 Single/Paid-SE'  . ';' .
                  'On Call Over-1 Single/Saved-SE' . ';' .
                  'On Call Over-2 Double/Paid-SE'  . ';' .
                  'On Call Over-2 Double/Saved-SE' . ';' .
                  'On Call Over-3 Double/Paid-SE'  . ';' .
                  'On call Over-3 Single/Paid-SE'  . ';;' .
                  'Overtime Double /paid -SE'      . ';' .
                  'Overtime Double /saved -SE'     . ';' .
                  'Overtime Double Hourly /p -SE'  . ';' .
                  'Overtime Single /paid -SE'      . ';' .
                  'Overtime Single /saved -SE'     . ';' .
                  'Overtime Single Hourly /p -SE'  . ';;' .
                  'Shift 1 -SE'                    . ';' .
                  'Shift 2 -SE'                    . ';' .
                  'Shift 3 -SE'                    . ';' .
                  'Shift 4 -SE'                    . ';;' .
                  'Travelling I /not paid -SE'     . ';' .
                  'Travelling I /paid -SE'         . ';' .
                  'Travelling II /not paid -SE'    . ';' .
                  'Travelling II /paid -SE'        . ';;' .
                  'Sick Leave -SE'                 . ';' .
                  'Care of child Leave -SE'        . ';' .
                  'Care of close relat. Leave -SE' . ';' .
                  'Short Notice Compensation-SE'   . ';' .
                  'Parental Leave -SE'             . ';' .
                  'Father Leave -SE'               . ';;' .
                  'Vacation -SE'                   . ';' .
                  'Leave of Absence /paid -SE'     . ';' .
                  'Leave of Absence /unpaid -SE'   . ';' .
                  'Military Refresher -SE'         . ';' .
                  'Military Service -SE'           . ';;' .
                  'Occupational Injury -SE'        . ';' .
                  'Study Leave /unpaid /v -SE'     . ';' .
                  'Compensation for Overtime -SE'  . ';' .
                  'Comp for daily/weekly rest -SE' . ';'
                                                           ,
                'Details:.:24',
              ],
                };

# Subroutines

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create Plugin::MyTime object
#
# Arguments:
#  - Object prototype
# Returns:
#  Object reference

sub new($$%) {
  my $class = shift;
  $class = ref($class) || $class;
  my $args = shift;

  my $self = {
               win => {},
               cfg => {
                       %{$PLUGIN_CFG},
                      },
# TODO This should be handled in plugin base class or something similar
               name => __PACKAGE__,
             };

  bless($self, $class);


  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      getPluginInformation
#
# Description: Return information about the plugin
#              Default is value of PLUGIN_INFORMATION
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub getPluginInformation($) {
  # parameters
  my $self = shift;

  return [PLUGIN_INFORMATION];
} # Method getPluginInformation

#----------------------------------------------------------------------------
#
# Method:      getPluginCfg
#
# Description: Return default plugin configuration
#              Default is value of PLUGIN_CFG
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub getPluginCfg($) {
  # parameters
  my $self = shift;

  return { %{$PLUGIN_CFG} };
} # Method getPluginCfg

#----------------------------------------------------------------------------
#
# Method:      registerPlugin
#
# Description: Register plugin capabilities in Tidbox
#              - Week
#                  Export work time
#              - Settings Tab
#                  week work time
#                  Export csv template (hardcoded???)
#                  Export directory
#               - EventCfg
#                  Template for EventCfg
#
# Arguments:
#  0 - Object reference
# Returns:
#  - Reference to MyTime Plugin Object

sub registerPlugin($) {
  # parameters
  my $self = shift;


  $self->{erefs}{-sett_win} ->addPlugin($self->{name},
                                 -area    => [$self => 'addMyTimeSettings'],
                                 -apply   => [$self => 'apply'],
                                 -restore => [$self => 'restore'],
                                );
  $self->{erefs}{-event_cfg}->addPlugin($self->{name},
                                 -template => [$self => 'addMyTimeTemplate']
                                );
  $self->{erefs}{-week_win} ->addPlugin($self->{name},
                                 -button => [$self => 'addMyTimeExport'  ]
                                );

  # Get event configuration information
  $self->_fetchEventCfgDefinition();

  return 0;
} # Method registerPlugin

#----------------------------------------------------------------------------
#
# Method:      addMyTimeSettings
#
# Description: Add MyTimeXls plugin settings gui in Settings
#              Expected to use a tab
#
# Arguments:
#  - Object reference
#  - Area to add into, exclusively used by MyTimeXls
# Returns:
#  -

sub addMyTimeSettings($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;


  return undef
      unless (Exists($area));

  my $win_r = $self->{win};
  $win_r->{area} = $area;

  # MyTime Excel file save directory
  $win_r->{excel_area} = $area
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{excel_dir_label} = $win_r->{excel_area}
      -> Label(-text => 'Katalog där MyTime Excel-filer sparas:' )
      -> pack(-side => 'left');

  $win_r->{dir_button} = $win_r->{excel_area}
      -> Button(
                -command => [$self => '_chooseMyTimeXlsDirectory'],
                -state => 'normal',
               )
      -> pack(-side => 'left');


  return 0;
} # Method addMyTimeSettings

#----------------------------------------------------------------------------
#
# Method:      addMyTimeTemplate
#
# Description: Add template for MyTime in Event Configuration
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub addMyTimeTemplate($) {
  # parameters
  my $self = shift;

  return $EVENT_CFG;
} # Method addMyTimeTemplate

#----------------------------------------------------------------------------
#
# Method:      addMyTimeExport
#
# Description: Return MyTime export label and callback
#
# Arguments:
#  - Object reference
# Returns:
#  - Button label
#  - Callback to perform the export

sub addMyTimeExport($) {
  # parameters
  my $self = shift;

  return ('Skapa MyTime xls', [$self, 'exportSetup']);
} # Method addMyTimeExportButton

#----------------------------------------------------------------------------
#
# Method:      _fetchEventCfgDefinition
#
# Description: Fetch EventCfg types def, use for splitting events
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _fetchEventCfgDefinition($) {
  # parameters
  my $self = shift;
  my () = @_;


  $self->{types_def}  = $self->{erefs}{-event_cfg}->getDefinition();
  return 0;
} # Method _fetchEventCfgDefinition

#----------------------------------------------------------------------------
#
# Method:      selectDirButton
#
# Description: Set label on select Excel directory button
#              TODO Plugin base class could be created
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub selectDirButton($) {
  # parameters
  my $self = shift;

  $self->{win}->{dir_button}->
      configure(
                -text => $self->{cfg}{mytimexls_directory} ||
                         'Välj katalog',
# TODO The button is not correctly initiated
               )
      if (exists($self->{win}->{dir_button}));
  return 0;
} # Method selectDirButton

#----------------------------------------------------------------------------
#
# Method:      restore
#
# Description: Restore configuration settings
#              TODO Plugin base class could be created
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub restore($) {
  # parameters
  my $self = shift;
  my () = @_;

  # Get plugin settings from plugin manager
  for my $key (keys(%{$self->{cfg}})) {
    $self->{cfg}{$key} = $self->{erefs}{-plugin}->get($self->{name}, $key);
  } # for #

  $self->selectDirButton();

  return 0;
} # Method restore

#----------------------------------------------------------------------------
#
# Method:      apply
#
# Description: Apply changed settings
#              TODO Plugin base class could be created
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub apply($) {
  # parameters
  my $self = shift;
  my () = @_;


  $self->{erefs}{-plugin}->put($self->{name}, %{$self->{cfg}});

  return 0;
} # Method apply

#----------------------------------------------------------------------------
#
# Method:      _modified
#
# Description: A setting is modified, signal Settings, etc.
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _modified($) {
  # parameters
  my $self = shift;

  $self->{erefs}{-sett_win}->_modified($self->{name});
  return 0;
} # Method _modified

#----------------------------------------------------------------------------
#
# Method:      _chooseMyTimeXlsDirectory
#
# Description: Choose a directory to store MyTime Excel files in
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _chooseMyTimeXlsDirectory($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  my $startdir =
        $self->{erefs}{-plugin}->get($self->{name}, 'mytimexls_directory');

  my $dir = $win_r->{area}
        -> chooseDirectory(-initialdir => $startdir,
                           -parent => $win_r->{area},
                           -title => $self->{name} .
                                       ': Katalog för MyTime Excel filer',
                          );

  # Normalize directory path from chooseDirectory()
  # Make sure '/' and '\' are for the actual filesystem, Windows or Unix
  my $cdir = File::Spec->canonpath($dir) ;

  $self->{cfg}{mytimexls_directory} = $cdir;
  $self->_modified();
  $self->selectDirButton();

  return 0;
} # Method _chooseMyTimeXlsDirectory

#----------------------------------------------------------------------------
#
# Method:      _workSheetWriteRow
#
# Description: Write a row of data to the worksheet
#
# Arguments:
#  - Object reference
#  - Worksheet reference
#  - Reference to row array
# Returns:
#  -

sub _workSheetWriteRow($) {
  # parameters
  my $self = shift;
  my ($worksheet, $row, $r) = @_;


  my $c = 0;
  for my $v (@$row) {
    if ($c < 4) {
      $worksheet->write_string($$r, $c, $v );
    } else {
      $worksheet->write($$r, $c, $v );
    } # if #
    $c++;
  } # for #
  ${$r}++;

  return 0;
} # Method _workSheetWriteRow

#----------------------------------------------------------------------------
#
# Method:      problems
#
# Description: Record problem detected during calculation
#
# Arguments:
#  0 - Object reference
#  1 .. Problem strings
# Returns:
#  -

sub problem($@) {
  # parameters
  my $self = shift(@_);

  push @{$self->{problem}}, @_;
  return 0;
} # Method problem

#----------------------------------------------------------------------------
#
# Method:      exportSetup
#
# Description: Setup export time data to MyTime template
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub exportSetup($) {
  # parameters
  my $self = shift;


  my $win_r = $self->{win};
  my $confirm = $self->{erefs}{-week_win}->get('confirm'),
  my $directory =
        $self->{erefs}{-plugin}->get($self->{name}, 'mytimexls_directory');

  unless ($directory) {
    $confirm
       ->popup(
               -title => ': Fel',
               -text  => ['Ingen MyTime Excel katalog angiven!',
                          'Välj en katalog i Inställningar'
                         ],
              );
    return 0;
  } # unless #

  unless (-d $directory) {
    eval { File::Path->make_path($directory, { mode => 0700 }) };
    if ($@) {
      $self->{erefs}{-log}->log('Create directory failed', $@);
      return undef
    } # if #
    $self->{erefs}{-log}->
            log('Created MyTime Excel directory:', $directory);
  } # unless #

  my $res =
    $self->_doExport(
                  $directory,
                 );

  return $res;
} # Method exportSetup

#----------------------------------------------------------------------------
#
# Method:      _doExport
#
# Description: Calculate work time for week and export to MyTime Excel file
#              MyTime_<week start date>_<week end date>.xls
#
# Format for Excel file
#
# ;Info text;Required value;;Optional value;;;;;;;;;;;;;
# Project;Project name;Task;Type;Monday;Comment1;Tuesday;Comment2;\
# Wednesday;Comment3;Thursday;Comment4;Friday;Comment5;Saturday;Comment6;\
# Sunday;Comment7
# 24404;ABSENCE 305;+1.1 - Vac - annual;Normal -LV;1;;2.2;Comment;3,3;;\
# 4.0;;5;Comment; ; ; ;
# 184349;HR & Time Management Domain;01.2 - MyTime Supp App;Normal -LV;\
# 0.1;Comment;0,1;Comment;0.1;Comment;0.01;Comment;0,01;Comment; ; ;;
#
# Arguments:
#  - Object reference
#  - MyTime Excel storage directory
# Returns:
#  0 : No MyTime Excel file created due to problems
#  1 : Results exported to file

sub _doExport($$) {
  my $self = shift;
  my ($directory) = @_;

  $self->{problem} = [];
  my $date      = $self->{erefs}{-week_win}->get('last_date'),
  my $confirm   = $self->{erefs}{-week_win}->get('confirm'),
  my $win_r     = $self->{win};
  my $calc      = $self->{erefs}{-calculate};
  my $event_cfg = $self->{erefs}{-event_cfg};

  # Calculate for all days in week
  my ($match_string, $condense) = $event_cfg -> matchString(-3, $date);
  my ($cfg_r, $str_r) = $self->{erefs}{-event_cfg}->getEventCfg($date);

  my $week_events_r = {};
  my ($weekdays_r) =
       $calc -> weekWorkTimes($date, -3, [$self => 'problem'], $week_events_r);

  # Problems detected during calculation
  if (@{$self->{problem}}) {
    $confirm
       -> popup(
                -title => 'MyTime : Problem',
                -text  => ['Problem under beräkningen av av arbetstid',
                           'Ingen fil sparades'],
                -data  => [join("\n", @{$self->{problem}})],
               );
    return 0;
  } # if #

  # Collect some data about the week
  return undef unless (-d $directory);
  $self->{first_date} = $weekdays_r->[0]{date};
  $self->{last_date}  = $weekdays_r->[6]{date};

  # Find out filename to create: MyTime_<first-date>_<last-date>.csv
  $self->{outfile} =
      File::Spec->catfile
        ($directory ,
         'MyTime_' . $self->{first_date} . '_' . $self->{last_date} . '.xls'
         );

  # Create Excel file in directory
  # TODO Catch file is locked "eval {}"
  my $workbook=Spreadsheet::WriteExcel->new($self->{outfile});

  unless (defined($workbook)) {
    $confirm
       -> popup(
                -title => 'avbröt MyTimeXls',
                -text  => ['Det gick inte att skapa MyTime Excel filen:',
                           $self->{outfile},
                           $!],
               );
    return undef;
  } # unless #

  # TODO We might need this
  # $workbook->compatibility_mode();

  my $username = getlogin || getpwuid($<) || "Tidbox";

  $workbook->set_properties(
      title    => 'Arbetstid för ' . $self->{first_date} . ' till ' . $self->{last_date},
# TODO: Användare, Tidbox version, etc.
      author   => $username,
      comments => 'Skapad av Tidbox ' . $self->{first_date} .
                  ' och Spreadsheet::WriteExcel',
  );

  # Add a worksheet
  # TODO Can we have any name we like. For example week number
  my $worksheet = $workbook->add_worksheet('OneEntry');

  # Add header rows
  my $r = 0;

  for my $hline (split("\n", XLS_HEADER_TEMPLATE)) {
    $self->_workSheetWriteRow($worksheet, [ split(';', $hline) ], \$r);
  } # for #

  #
  # Add data for the week
  #
  # Insert event times
  my $row;
  my $time;
  my $activity = "\n";
  # TODO Should we really create a row array?
  # TODO Why not just write directly to sheet?
  my $not_understood = 0;
  my $fractions = 0;
  my @doubtfull;

  for my $event (sort(keys(%{$week_events_r}))) {

    push @doubtfull , $event
        unless ($event =~
                  /^(?:\d+),(?:[-+\d\. a-zA-Z]+),(?:[A-Z][\w \.\/]+-[A-Z]{2}(?:-Overtime)?),/);
# TODO Task and Type might look different

    $row = undef;
    if ($event =~ /$match_string/) {
      next if($1 eq $activity);

      $activity = $1;

      # Split data
      my $split_activity = $activity;
      my $column = 0;
      for my $ev_r (@{$str_r}[0..2]) {

        if ($ev_r->{-type} ne '.') {
          if ($split_activity =~
                /^($self->{types_def}{$ev_r->{-type}}[0]*),?(.*)$/) {
            my $field = $1;
            $split_activity = $2;
            if ($column == 0) {
              # Project, Project name
              $row = [ $field, '' ];
              $column++;

            } elsif ($column == 1) {
              # Task number, Task name
              # push @$row, $field, '';
              # TODO Dirty fix
              if ($field =~ /^(\S+)\s+\-\s+(\S.*)$/) {
                # Task is given full string '1 - Vacation'
                push @$row, $1, $2;
              } else {
                push @$row, $field, ''; # Task name: Add a space character
              } # if #

              $column++;

            } else {
              # Type
              push @$row, $field;

            } # if #

          } else {
            # No match, add nothing and remove up to next ','
            if ($column == 0) {
              # Project, Project name
              $row = [ '', '' ];
              $column += 2;

            } elsif ($column == 2) {
              # Task number, Task name
              push @$row, '', '';
              $column += 2;

            } else {
              # Type
              push @$row, '';
              $column++;

            } # if #

            $split_activity =~ s/^[^,]*,//;

          } # if #

        } else {
          push @$row, $split_activity;
          $split_activity = '';

        } # if #

      } # for #


      for my $day_r (@$weekdays_r) {
        $time = $calc->formatTime(CSV_DECIMAL_KOMMA, $day_r->{activities}{$activity});
        # Weekday time, Comment, Time from, Time to
        push @$row, $time, '', '', '';
        $fractions++
            if ($time =~ m/^\d+\.\d[^0]$/);
      } # for #

    } else {

      $row = [ $1, '', '', '', '' ];

      for my $day_r (@$weekdays_r) {
        $time = $calc->formatTime(CSV_DECIMAL_KOMMA, $day_r->{events}{$event});
        # Weekday time, Comment, Time from, Time to
        push @$row, $time, '', '', '';
        $not_understood += $day_r->{events}{$event}
             if ($day_r->{events}{$event});
        $fractions++
            if ($time =~ m/^\d+\.\d[^0]$/);
      } # for #

    } # if #

    $self->_workSheetWriteRow($worksheet, $row, \$r);

  } # for #

  # Insert non event time
  my $other = 0;
  # Project, Project name, Task number, Task name, Type
  $row = [ 'Other', '', '', '', '' ];
  for my $day_r (@$weekdays_r) {
    if ($day_r->{not_event_time}) {
      $time = $calc->formatTime(CSV_DECIMAL_KOMMA, $day_r->{not_event_time});
      # Weekday time, Comment, Time from, Time to
      push @$row, $time, '', '', '';
      $other += $day_r->{not_event_time};
      $fractions++
          if ($time =~ m/^\d+\.\d[^0]$/);
    } else {
      # Weekday time, Comment, Time from, Time to
      push @$row, '', '', '', '';
    } # if #
  } # for #

  $self->_workSheetWriteRow($worksheet, $row, \$r)
      if ($other);

  #----------------------------------------------------------------------
  # Add flextime for the week
  # Removed 2018-11-29 due to changes in MyTime
  #my $week_work_minutes =
  #          60 * $self->{erefs}{-cfg}->get('ordinary_week_work_time');
  #
  #my $day_work_minutes = $week_work_minutes / 5;
  #
  #$row = [ '133756', '', '01 - Flex time in/out', 'Normal /flex -SE' ];
  #
  #for my $day_r (@$weekdays_r[0..4]) {
  #  $time = $day_r->{work_time} - $day_work_minutes;
  #  $time = $calc->formatTime(CSV_DECIMAL_KOMMA, $time);
  #  push @$row, $time, '';
  #} # for #
  #
  ## TODO Method to write row
  #$c = 0;
  #for my $v (@$row) {
  #  if ($c > 0 and $c < 4) {
  #    $worksheet->write_string($r, $c, $v );
  #  } else {
  #    $worksheet->write($r, $c, $v );
  #  } # if #
  #  $c++;
  #} # for #
  #----------------------------------------------------------------------

  # Close

  $workbook->close() or
     $confirm
       -> popup(
                -title => 'avbröt MyTime',
                -text  => ['FEL: Det gick inte att skriva till fil:',
                           $self->{outfile},
                           $!],
               );

  # Any problem detected?
  if (@doubtfull or $not_understood or $other or $fractions) {

    my $t = ['VARNING:', undef];
    my $d = [];

    if (@doubtfull) {
      push @$t, ('Ett antal händelser verkar inte vara för MyTime.'."\n".
                   'Kontrollera att följande registreringar är riktiga:',
                  undef,
                 );
      push @$d, (undef, undef, join("\n", @doubtfull));
    } # if #

    if ($not_understood) {
      push @$t, ('Tid för ej formaterbara händelser registrerade: '.
                  $calc->formatTime(CSV_DECIMAL_KOMMA, $not_understood) . ' timmar',
                 undef,
                 );
    } # if #

    if ($other) {
      push @$t, ('Arbetstid utan händelse: '.
                  $calc->formatTime(CSV_DECIMAL_KOMMA, $other) . ' timmar',
                 undef,
                );
    } # if #

    if ($fractions) {
      push @$t, ('Arbetstid med hundradelar detekterade '.
                  $fractions . '. Tips: "Justera vecka".',
                 undef,
                );
    } # if #

    push @$t, ('Skrev tveksam veckoarbetstid till:',
               $self->{outfile},
              );

    $confirm
       -> popup(
                -title => 'MyTime : VARNING',
                -text  => $t,
                -data  => $d,
               );
    return 1;
  } # if #


  # Check week work time and hint for flex
  my $total_time = 0;

  my $week_work_minutes = $self->{erefs}{-calculate}->getWeekScheduledTime($date);

  for my $day_r (@$weekdays_r) {
    $total_time += $day_r->{work_time}
        if ($day_r->{work_time});
  } # for #

  if ($total_time > $week_work_minutes) {
    $confirm ->
        popup(
              -title => 'MyTime : Tips',
              -text  => ['Tips:',
                         'Veckoarbetstiden blev ' .
                         $calc->formatTime(CSV_DECIMAL_KOMMA, $total_time) . ' timmar.',
                         'Det är ' .
                         $calc->formatTime(CSV_DECIMAL_KOMMA, $total_time - $week_work_minutes) .
                         ' timmar mer än normaltid ' .
                         $calc->formatTime(CSV_DECIMAL_KOMMA, $week_work_minutes),
                         'Skrev veckoarbetstid till:',
                         $self->{outfile},
                        ],
              -data  => [undef,
                         undef,
                         'Har du registrerat flextid eller övertid?',
                        ],
             );
    return 1;

  } elsif ($total_time < $week_work_minutes) {
    $confirm ->
        popup(
              -title => 'MyTimeXls : Tips',
              -text  => ['Tips:',
                         'Veckoarbetstiden blev ' .
                         $calc->formatTime(CSV_DECIMAL_KOMMA, $total_time) . ' timmar.',
                         'Det är ' .
                         $calc->formatTime(CSV_DECIMAL_KOMMA, $week_work_minutes - $total_time) .
                         ' timmar mindre än normaltid ' .
                         $calc->formatTime(CSV_DECIMAL_KOMMA, $week_work_minutes),
                         'Skrev veckoarbetstid till:',
                         $self->{outfile},
                        ],
              -data  => [undef,
                         undef,
                         'Har du registrerat uttag av flextid eller komptid?',
                        ],
             );
    return 1;
  } # if #

  # Nothing strange, success message
  $confirm
     -> popup(
              -title => 'MyTimeXls resultat',
              -text  => ['Skrev veckoarbetstid till:',
                         $self->{outfile}],
             );


  return 1;
} # Method _doExport

1;
__END__
