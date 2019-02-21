#
package Plugin::MyTimeXlsX;
#
#   Document: Plugin MyTimeXlsX
#   Version:  0.3   Created: 2019-02-16 10:17
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: MyTimeXlsX.pmx
#

my $VERSION = '0.3';
my $DATEVER = '2019-02-16';

# History information:
#
# 1.0  2019-02-16  Roland Vallgren
#      First issue based on MyTimeXls.pm.
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

use Excel::Writer::XLSX;

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
 'Plugin för att exportera tid registrerad i Tidbox till Tieto MyTime Excel X.',

#  XLSX_HEADER_TEMPLATE =>
# Format used 2018 week 46 and 47
#       'Project;Project name;Task;Type;Monday;Comment1;Tuesday;Comment2;' .
#       'Wednesday;Comment3;Thursday;Comment4;Friday;Comment5;Saturday;Comment6;' .
#       'Sunday;Comment7' ,
#  Format introduced 2019-02-12, that is Wednesday week 7
  XLSX_HEADER_TEMPLATE =>
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


# MyTimeXlsX configuration settings
my $PLUGIN_CFG = {
                  mytimexlsx_directory => '',
#            mytimexlsx_calculate_flextime => 0,
#            mytimexlsx_flex_time_template =>
#              ['133756' ,'' ,'01 - Flex time in/out', 'Normal /flex -SE'],
                 };

# MyTimeXlsX event cfg example of event configurations
my $EVENT_CFG = {
    MyTimeXlsX => [ 'Project:d:6',
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
    MyTimeRadioXlsX => [ 'Project:R:' .
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
    MyTimeXlsXAllaTyper =>
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
                  'Father Leave -SE'               . ';' .
                  'Doctor Visit -SE'               . ';;' .
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
#----------------------------------------------------------------------------
#
# Function:    _formatTime
#
# Description: Format time for MyTime hour.tenth. Like '1.5'
#              Zero length string if time is 0 (zero)
#              Return time if not digits, it is probably not a time
#
# Arguments:
#  0 - Time to format in minutes
#  1 - Calculator
# Returns:
#  Formatted time

sub _formatTime($$) {
  # parameters
  my ($v, $calc) = @_;

  return '' unless $v;
  return $v unless ($v =~ /^\d+$/o);
  return $calc->hours($v, '.');
} # sub _formatTime


#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create Plugin::MyTimeXlsX object
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
#  - Reference to MyTimeXlsX Plugin Object

sub registerPlugin($) {
  # parameters
  my $self = shift;


  $self->{erefs}{-sett_win} ->addPlugin($self->{name},
                                 -area    => [$self => 'addMyTimeXlsXSettings'],
                                 -apply   => [$self => 'apply'],
                                 -restore => [$self => 'restore'],
                                );
  $self->{erefs}{-event_cfg}->addPlugin($self->{name},
                                 -template => [$self => 'addMyTimeXlsXTemplate']
                                );
  $self->{erefs}{-week_win} ->addPlugin($self->{name},
                                 -button => [$self => 'addMyTimeXlsXExport'  ]
                                );

  # Get event configuration information
  $self->_fetchEventCfgDefinition();

  return 0;
} # Method registerPlugin

#----------------------------------------------------------------------------
#
# Method:      addMyTimeXlsXSettings
#
# Description: Add MyTimeXlsX plugin settings gui in Settings
#              Expected to use a tab
#
# Arguments:
#  - Object reference
#  - Area to add into, exclusively used by MyTimeXlsX
# Returns:
#  -

sub addMyTimeXlsXSettings($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;


  return undef
      unless (Exists($area));

  my $win_r = $self->{win};
  $win_r->{area} = $area;

  # MyTime Excel X file save directory
  $win_r->{excelx_area} = $area
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{excelx_dir_label} = $win_r->{excelx_area}
      -> Label(-text => 'Katalog där MyTime ExcelX-filer sparas:' )
      -> pack(-side => 'left');

  $win_r->{dir_button} = $win_r->{excelx_area}
      -> Button(
                -command => [$self => '_chooseMyTimeXlsXDirectory'],
                -state => 'normal',
               )
      -> pack(-side => 'left');


  return 0;
} # Method addMyTimeXlsXSettings

#----------------------------------------------------------------------------
#
# Method:      addMyTimeXlsXTemplate
#
# Description: Add template for MyTime in Event Configuration
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub addMyTimeXlsXTemplate($) {
  # parameters
  my $self = shift;

  return $EVENT_CFG;
} # Method addMyTimeXlsXTemplate

#----------------------------------------------------------------------------
#
# Method:      addMyTimeXlsXExport
#
# Description: Return MyTimeXlsX export label and callback
#
# Arguments:
#  - Object reference
# Returns:
#  - Button label
#  - Callback to perform the export

sub addMyTimeXlsXExport($) {
  # parameters
  my $self = shift;

  return ('Skapa MyTime xlsx', [$self, 'exportSetup']);
} # Method addMyTimeXlsXExportButton

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
# Description: Set label on select Excel x directory button
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
                -text => $self->{cfg}{mytimexlsx_directory} || 
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
# Method:      _chooseMyTimeXlsXDirectory
#
# Description: Choose a directory to store MyTime Excel X files in
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _chooseMyTimeXlsXDirectory($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  my $startdir =
        $self->{erefs}{-plugin}->get($self->{name}, 'mytimexlsx_directory');

  my $dir = $win_r->{area}
        -> chooseDirectory(-initialdir => $startdir,
                           -parent => $win_r->{area},
                           -title => $self->{name} .
                                       ': Katalog för MyTime Excel X filer',
                          );

  # Normalize directory path from chooseDirectory()
  # Make sure '/' and '\' are for the actual filesystem, Windows or Unix
  my $cdir = File::Spec->canonpath($dir) ;

  $self->{cfg}{mytimexlsx_directory} = $cdir;
  $self->_modified();
  $self->selectDirButton();

  return 0;
} # Method _chooseMyTimeXlsXDirectory

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
# Description: Setup export time data to MyTimeXlsX template
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
        $self->{erefs}{-plugin}->get($self->{name}, 'mytimexlsx_directory');

  unless ($directory) {
    $confirm
       ->popup(
               -title => ': Fel',
               -text  => ['Ingen MyTime Excel X katalog angiven!',
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
            log('Created MyTime Excel X directory:', $directory);
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
# Description: Calculate work time for week and export to MyTime Excel X file
#              MyTime_<week start date>_<week end date>.xlsx
#
# Format for Excel X file
#  NOTE: The first four fields are String format,
#        even when the value is a number
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
#  - MyTime Excel X storage directory
# Returns:
#  0 : No MyTime Excel X file created due to problems
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
                -title => 'MyTimeXlsX : Problem',
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
  ($self->{year}, $self->{week}) = $calc->weekNumber($date);

  # Find out filename to create: MyTime_<first-date>_<last-date>.csv
  $self->{outfile} =
      File::Spec->catfile
        ($directory ,
         'MyTime_' . $self->{first_date} . '_' . $self->{last_date} . '.xlsx'
         );

  # Create Excel X file in directory
  # TODO Catch file is locked "eval {}"
  my $workbook= Excel::Writer::XLSX->new($self->{outfile});

  unless (defined($workbook)) {
    $confirm
       -> popup(
                -title => 'avbröt MyTimeXlsX',
                -text  => ['Det gick inte att skapa MyTime Excel X filen:',
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
                  ' med hjälp av Excel::Writer::XLSX',
  );

  # Add a worksheet
  # TODO Can we have any name we like. For example week number
  my $worksheet = $workbook->add_worksheet($self->{year} . 'V' . $self->{week});

  # Add header rows
  my $r = 0;

  for my $hline (split("\n", XLSX_HEADER_TEMPLATE)) {
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
        $time = _formatTime($day_r->{activities}{$activity}, $calc);
        # Weekday time, Comment, Time from, Time to
        push @$row, $time, '', '', '';
        $fractions++
            if ($time =~ m/^\d+\.\d[^0]$/);
      } # for #

    } else {

      $row = [ $1, '', '', '', '' ];

      for my $day_r (@$weekdays_r) {
        $time = _formatTime($day_r->{events}{$event}, $calc);
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
      $time = _formatTime($day_r->{not_event_time}, $calc);
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
  #  $time = _formatTime($time, $calc);
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
                -title => 'avbröt MyTimeXlsX',
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
                  _formatTime($not_understood, $calc) . ' timmar',
                 undef,
                 );
    } # if #

    if ($other) {
      push @$t, ('Arbetstid utan händelse: '.
                  _formatTime($other, $calc) . ' timmar',
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
                -title => 'MyTimeXlsX : VARNING',
                -text  => $t,
                -data  => $d,
               );
    return 1;
  } # if #


  # Check week work time and hint for flex
  my $total_time = 0;

  my $week_work_minutes =
            60 * $self->{erefs}{-cfg}->get('ordinary_week_work_time');

  for my $day_r (@$weekdays_r) {
    $total_time += $day_r->{work_time} 
        if ($day_r->{work_time});
  } # for #

  if ($total_time > $week_work_minutes) {
    $confirm ->
        popup(
              -title => 'MyTimeXlsX : Tips',
              -text  => ['Tips:',
                         'Veckoarbetstiden blev ' .
                         _formatTime($total_time, $calc) . ' timmar.',
                         'Det är ' .
                         _formatTime($total_time - $week_work_minutes, $calc) .
                         ' timmar mer än normaltid ' .
                         _formatTime($week_work_minutes, $calc),
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
              -title => 'MyTimeXlsX : Tips',
              -text  => ['Tips:',
                         'Veckoarbetstiden blev ' .
                         _formatTime($total_time, $calc) . ' timmar.',
                         'Det är ' .
                         _formatTime($week_work_minutes - $total_time, $calc) .
                         ' timmar mindre än normaltid ' .
                         _formatTime($week_work_minutes, $calc),
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
              -title => 'MyTimeXlsX resultat',
              -text  => ['Skrev veckoarbetstid till:',
                         $self->{outfile}],
             );


  return 1;
} # Method _doExport

1;
__END__
