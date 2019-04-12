#
package Plugin::MyTime;
#
#   Document: Plugin MyTime
#   Version:  1.3   Created: 2019-04-12 17:54
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: MyTime.pmx
#

my $VERSION = '1.3';
my $DATEVER = '2019-04-12';

# History information:
#
# 1.3  2019-04-12  Roland Vallgren
#      "Doctor visit -SE" is not a valid Type in MyTime
# 1.2  2019-01-25  Roland Vallgren
#      Code improvements
# 1.1  2017-10-16  Roland Vallgren
#      References to other objects in own hash
#      Allow events to have more or less than four fields
# 1.0  2017-04-04  Roland Vallgren
#      First issue based on Terp.pm.
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

use FileHandle;
use File::Spec;
use File::Basename;

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
     'Plugin för att exportera tid registrerad i Tidbox till Tieto MyTime.' ,

  EXPORT_CSV_FILENAME => 'export.csv',

  CSV_TEMPLATE =>
'START_HEADER
Overriding Approver,,,,,,,,,,,,,,,,,
Comments,,,,,,,,,,,,,,,,,
STOP_HEADER
,,,,,,,,,,,,,,,,,
START_TEMPLATE
Project,Task,Type,Mon,CommentText,Tue,CommentText,Wed,CommentText,Thu,\
CommentText,Fri,CommentText,Sat,CommentText,Sun,CommentText,END_COLUMN
74151,01,Normal,1,testtxt1,,,,,,,,,,,,,
74151,02,Normal,,,2,testtxt2,,,,,,,,,,,
74151,03,Normal,,,,,3,testtxt3,,,,,,,,,
74151,04,Normal,,,,,,,4,testtxt4,,,,,,,
 , , ,,,,,,,,,,,,,,,
STOP_TEMPLATE
ORACLE RESERVED SECTION
,,,,,,,,,,,,,,,,,
START_ORACLE
A|PROJECTS|Attribute1|A|PROJECTS|Attribute2|AE|PROJECTS|Attribute3|PROJECTS|\
Attribute5|D|DI|CommentText|D|DI|CommentText|D|DI|CommentText|D|DI|CommentText|\
D|DI|CommentText|D|DI|CommentText|D|DI|CommentText|,,,,,,,,,,,,,,,,,
2121472,,,,,,,,,,,,,,,,,
A|APPROVAL|Attribute10|DI|CommentText|,,,,,,,,,,,,,,,,,
STOP_ORACLE,END
' ,
};

# MyTime configuration settings
my $PLUGIN_CFG = {
                  mytime_template => '',
                 };

# MyTime event cfg example of event configurations
my $EVENT_CFG = {
    MyTime => [ 'Project:d:6',            
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
    MyTimeRadio => [ 'Project:R:' .
                  '?'        . '=>'. '?'                             . ';' .
                  'Projekt'  . '=>'. '12345'                         . ';' .
                  'Frånvaro' . '=>'. '172158'                                ,
                'Task:R:' .
                  'Projektarbete '. '=>'. '01.01'                    . ';' .
                  'Projektledning'. '=>'. '01.02'                    . ';' .
                  'Frånvaro-Sem  '. '=>'. '1'                        . ';' .
                  'Frånvaro-Sjuk '. '=>'. '2'                        . ';' .
                  'Frånvaro-Övrig'. '=>'. '3'                        . ';' .
                  'Ledig-Nordic  '. '=>'. '01.1'                            ,
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
    MyTimeAllaTyper =>
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
  return 0;
} # Method registerPlugin

#----------------------------------------------------------------------------
#
# Method:      addMyTimeSettings
#
# Description: Add MyTime plugin settings gui in Settings
#              Expected to use a tab
#
# Arguments:
#  - Object reference
#  - Area to add into, exclusively used by MyTime
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

  # MyTime template file
  $win_r->{template_area} = $area
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{template_label} = $win_r->{template_area}
      -> Label(-text => 'Fil med MyTime-mall:' )
      -> pack(-side => 'left');

  $win_r->{file_button} = $win_r->{template_area}
      -> Button(
                -command => [$self => '_chooseTemplateFile'],
                -state => 'normal',
               )
      -> pack(-side => 'left');

  $win_r->{template_note} = $win_r->{template_area}
      -> Label(-text => ' (Genererade MyTime-filer sparas i samma katalog)')
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

  return ('Till MyTime-mall', [$self, 'exportSetup']);
} # Method addMyTimeExportButton

#----------------------------------------------------------------------------
#
# Method:      selectFileButton
#
# Description: Set label on select file button
#              TODO Plugin base class could be created
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub selectFileButton($) {
  # parameters
  my $self = shift;

  $self->{win}->{file_button}->
      configure(
                -text => $self->{cfg}{mytime_template} || 
                         'Välj fil (export.csv)',
               )
      if (exists($self->{win}->{file_button}));
  return 0;
} # Method selectFileButton

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

  $self->selectFileButton();

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
# Method:      _chooseTemplateFile
#
# Description: Choose MyTime template file
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _chooseTemplateFile($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  my $tpt = $self->{erefs}{-plugin}->get($self->{name}, 'mytime_template');

  my $initialdir ;
  my $initialfile;

  if ($tpt    and
      -r $tpt and
      $tpt =~ /^(.*?)[\\\/]([^\\\/]+)$/)
  {
    $initialdir  = $1;
    $initialfile = $2;
  } else {
    $initialdir  = ($^O eq 'MSWin32') ? $ENV{HOMEDRIVE} : $ENV{HOME};
    $initialfile = EXPORT_CSV_FILENAME;
  } # if #


  my $file = $win_r->{area}
        -> getOpenFile(-defaultextension => '.csv',
                       -filetypes => [
                           ['csv files' , '.csv'],
                           ['Text files', '.txt'],
                           ['All Files' , '*'   ],
                                     ],
                       -initialdir  => $initialdir ,
                       -initialfile => $initialfile,
                       -title => $self->{name} . ': MyTime mall',
                      );

  return 0
      unless ($file and -r $file and (not $tpt or $tpt and ($file ne $tpt)));

  $self->{cfg}{mytime_template} = $file;
  $self->_modified();
  $self->selectFileButton();

  return $file;
} # Method _chooseTemplateFile

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
  my $tpt = $self->{erefs}{-plugin}->get($self->{name}, 'mytime_template');

  unless ($tpt) {
    $confirm
       ->popup(
               -title => ': Fel',
               -text  => ['Ingen MyTime mall angiven!',
                          'Välj en mall i Inställningar'
                         ],
              );
    return 0;
  } # unless #

  unless (-f $tpt) {
    $confirm
       -> popup(
                -title => ': Fel',
                -text  => ['Kan inte hitta MyTime mall: '.
                           $tpt,
                          'Välj en mall i Inställningar'
                          ],
               );
    return 0;
  } # unless #

  my $res =
    $self->_doExport(
                  $tpt,
                 );

  return $res;
} # Method exportSetup

#----------------------------------------------------------------------------
#
# Method:      _doExport
#
# Description: Calculate work time for week and export to MyTime template file
#              MyTime_<week start date>_<week end date>.csv
#
# Format for template file
#
# START_TEMPLATE
# Project,Task,Type,Mon,CommentText,Tue,CommentText,Wed,CommentText,Thu,
#        CommentText,Fri,CommentText,Sat,CommentText,Sun,CommentText,END_COLUMN
# 12345,67.89,Vanlig,1.0,,2.0,,3.0,,4.0,,5.0,,,,,
#        ,    ,    ,1.0,,2.0,,3.0,,4.0,,5.0,,6.0,,7.0,
#  , , ,,,,,,,,,,,,,,
#  , , ,,,,,,,,,,,,,,
# STOP_TEMPLATE
#
# Arguments:
#  - Object reference
#  - Template file name
# Returns:
#  undef : The MyTime-template was not possible to use
#  0 : No MyTime file created due to problems
#  1 : Results exported to file

sub _doExport($) {
  my $self = shift;
  my ($template) = @_;

  $self->{problem} = [];
  my $date      = $self->{erefs}{-week_win}->get('last_date'),
  my $confirm   = $self->{erefs}{-week_win}->get('confirm'),
  my $win_r     = $self->{win};
  my $calc      = $self->{erefs}{-calculate};
  my $event_cfg = $self->{erefs}{-event_cfg};

  # Calculate for all days in week
# TODO The condense setting -3 is not pretty
  my ($match_string, $condense) = $event_cfg -> matchString(-3, $date);

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
  return undef unless (-f $template);
  $self->{first_date} = $weekdays_r->[0]{date};
  $self->{last_date}  = $weekdays_r->[6]{date};

  # Find out filename to create: MyTime_<first-date>_<last-date>.csv
  my ($filename, $directories) = fileparse($template);
  $self->{outfile} =
      File::Spec->catfile
        ($directories ,
         'MyTime_' . $self->{first_date} . '_' . $self->{last_date} . '.csv'
         );

  # Open files and copy to area were to insert times

  my $tp = FileHandle->new($template, '<');
  unless (defined($tp)) {
    $confirm
       -> popup(
                -title => 'avbröt MyTime',
                -text  => ['Det gick inte att läsa MyTime-mallen:',
                           $template,
                           $!],
               );
    return undef;
  } # unless #

  my $fh = FileHandle->new($self->{outfile}, '>');
  unless (defined($fh)) {
    $confirm
       -> popup(
                -title => 'avbröt MyTime',
                -text  => ['Det gick inte att öppna fil:',
                           $self->{outfile},
                           $!],
               );
    return undef;
  } # unless #

  my $line;
  # Copy up to and including "START_TEMPLATE"
  while (defined($line = $tp->getline())) {
    $fh->print($line);
    last if ($line =~ /^START_TEMPLATE\s*$/);
  } # while #

  unless (defined($line)) {
    $confirm
       -> popup(
                -title => 'avbröt MyTime',
                -text  => ['Kunde inte hitta start märket i MyTime-mallen:',
                           $template],
               );
    return undef;
  } # unless #

  # Copy header line
  $line = $tp->getline();
  $fh->print($line) if defined($line);

  #
  # Add data for the week
  #
  # Insert event times
  my $time;
  my $activity = "\n";
  my $not_understood = 0;
  my $fractions = 0;
  my @doubtfull;

  for my $event (sort(keys(%{$week_events_r}))) {

    push @doubtfull , $event
        unless ($event =~ 
                  /^(?:\d+),(?:[\d\.]+),(?:[A-Z][\w \.\/]+-SE(?:-Overtime)?),/);

    if ($event =~ /$match_string/) {
      next if($1 eq $activity);

      $activity = $1;
      $fh->print($activity);

      for my $day_r (@$weekdays_r) {
        $time = _formatTime($day_r->{activities}{$activity}, $calc);
        $fh->print(',', $time, ',');
        $fractions++
            if ($time =~ m/^\d+\.\d[^0]$/);
      } # for #

    } else {

      $activity = "\n";
      $fh->print($event, ',,');

      for my $day_r (@$weekdays_r) {
        $time = _formatTime($day_r->{events}{$event}, $calc);
        $fh->print(',', $time, ',');
        $not_understood += $day_r->{events}{$event}
             if ($day_r->{events}{$event});
        $fractions++
            if ($time =~ m/^\d+\.\d[^0]$/);
      } # for #

    } # if #

    $fh->print("\n");

  } # for #

  # Insert non event time
  my $other = 0;
  $line = 'Other, , ';
  for my $day_r (@$weekdays_r) {
    if ($day_r->{not_event_time}) {
      $time = _formatTime($day_r->{not_event_time}, $calc);
      $line .= ','. $time. ',';
      $other += $day_r->{not_event_time};
      $fractions++
          if ($time =~ m/^\d+\.\d[^0]$/);
    } else {
      $line .= ',,';
    } # if #
  } # for #
  $fh->print($line, "\n") if ($other);

  # Copy remaining part of file and close
  
  # Skip until end of template
  while (defined($line = $tp->getline())) {
    last if ($line =~ /^STOP_TEMPLATE\s*$/);
  } # while #

  # Print end of template
  $fh->print($line) if defined($line);

  # Copy till end of file
  while (defined($line = $tp->getline())) {
    $fh->print($line);
  } # while #

  $tp->close();

  $fh->close() or
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
                -title => 'MyTime : VARNING',
                -text  => $t,
                -data  => $d,
               );
    return 1;
  } # if #


  # Check week work time and hint for flex
  my $total_time = 0;

  for my $day_r (@$weekdays_r) {
    $total_time += $day_r->{work_time} 
        if ($day_r->{work_time});
  } # for #

  my $week_work_minutes =
            60 * $self->{erefs}{-cfg}->get('ordinary_week_work_time');

  if ($total_time > $week_work_minutes) {
    $confirm ->
        popup(
              -title => 'MyTime : Tips',
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
              -title => 'MyTime : Tips',
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
              -title => 'MyTime resultat',
              -text  => ['Skrev veckoarbetstid till:',
                         $self->{outfile}],
             );


  return 1;
} # Method _doExport

1;
__END__
