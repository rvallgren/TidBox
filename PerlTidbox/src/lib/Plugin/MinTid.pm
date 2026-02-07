#
package Plugin::MinTid;
#
#   Document: Plugin MinTid
#   Version:  1.0   Created: 2026-02-01 19:12
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: MinTid.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2026-02-01';

# History information:
#
# 1.0  2024-01-04  Roland Vallgren
#      First issue based on MyTime.pm.
#

#----------------------------------------------------------------------------
#
# Setup
#
use Modern::Perl '2019';

use base 'TidBase';
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
     'Plugin för att exportera tid registrerad i Tidbox till MinTid csv.' ,

  # Define CSV file properties
  EXPORT_CSV_FILENAME  => 'export.csv',
  CSV_COLUMN_SEPARATOR => ';',
  CSV_DECIMAL_KOMMA    => ',',
# TODO Does constant work here? Start tag (START_MINTID) and end tag (END_MINTID) in template should be defined here
  REGEX_START_TAG      => qr/^START_MINTID\s*$/,
  REGEX_END_TAG        => qr/^END_MINTID\s*$/,

# TODO Ordna möjlighet att redigera mallen
# TODO Start och sluttaggar skall kunna tas bort av pluginen
  CSV_TEMPLATE =>
'START_MINTID
Aktivitet;Måndag;Kommentar;Tisdag;Kommentar;Onsdag;Kommentar;Torsdag;Kommentar;Fredag;Kommentar;Lördag;Kommentar;Söndag;Kommentar
Aktivitet1;1;testtxt1;;;;;;;;;;;;;
Aktivitet2;;;2;testtxt2;;;;;;;;;;;
Aktivitet3;;;;;3;testtxt3;;;;;;;;;
Aktivitet4;;;;;;;4;testtxt4;;;;;;;
 ; ; ;;;;;;;;;;;;;;;
END_MINTID
End of file
' ,
};

# MinTid configuration settings
my $PLUGIN_CFG = {
                  mintid_template => '',
                 };

# MinTid event cfg example of event configurations
my $EVENT_CFG = {
       MinTid => [ 'Aktivitet:r:' .
                   join(';',
                        'Projekt'   ,
                        'Kompetens' ,
                        'Linje'     ,
                        'Friksvård'  ),
                'Kommentar:.:24',
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
# Description: Create Plugin::MinTid object
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
#  - Reference to MinTid Plugin Object

sub registerPlugin($) {
  # parameters
  my $self = shift;


  $self->{erefs}{-sett_win} ->addPlugin($self->{name},
                                 -area    => [$self => 'addMinTidSettings'],
                                 -apply   => [$self => 'apply'],
                                 -restore => [$self => 'restore'],
                                );
  $self->{erefs}{-event_cfg}->addPlugin($self->{name},
                                 -template => [$self => 'addMinTidTemplate']
                                );
  $self->{erefs}{-week_win} ->addPlugin($self->{name},
                                 -button => [$self => 'addMinTidExport'  ]
                                );
  return 0;
} # Method registerPlugin

#----------------------------------------------------------------------------
#
# Method:      addMinTidSettings
#
# Description: Add MinTid plugin settings gui in Settings
#              Expected to use a tab
#
# Arguments:
#  - Object reference
#  - Area to add into, exclusively used by MinTid
# Returns:
#  -

sub addMinTidSettings($$) {
  # parameters
  my $self = shift;
  my ($area) = @_;


  return undef
      unless (Exists($area));

  my $win_r = $self->{win};
  $win_r->{area} = $area;

  # MinTid template file
  $win_r->{template_area} = $area
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  $win_r->{template_label} = $win_r->{template_area}
      -> Label(-text => 'Fil med MinTid-mall:' )
      -> pack(-side => 'left');

  $win_r->{file_button} = $win_r->{template_area}
      -> Button(
                -command => [$self => '_chooseTemplateFile'],
                -state => 'normal',
               )
      -> pack(-side => 'left');

  $win_r->{create_file_button} = $win_r->{template_area}
      -> Button(
                -text => 'Skapa csv-fil',
                -command => [$self => '_createTemplateFile'],
                -state => 'normal',
               )
      -> pack(-side => 'left');

  $win_r->{template_note} = $win_r->{template_area}
      -> Label(-text => ' (Genererade MinTid-filer sparas i samma katalog)')
      -> pack(-side => 'left');


  return 0;
} # Method addMinTidSettings

#----------------------------------------------------------------------------
#
# Method:      addMinTidTemplate
#
# Description: Add template for MinTid in Event Configuration
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub addMinTidTemplate($) {
  # parameters
  my $self = shift;

  return $EVENT_CFG;
} # Method addMinTidTemplate

#----------------------------------------------------------------------------
#
# Method:      addMinTidExport
#
# Description: Return MinTid export label and callback
#
# Arguments:
#  - Object reference
# Returns:
#  - Button label
#  - Callback to perform the export

sub addMinTidExport($) {
  # parameters
  my $self = shift;

  return ('Till MinTid-mall', [$self, 'exportSetup']);
} # Method addMinTidExportButton

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
                -text => $self->{cfg}{mintid_template} ||
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
# Description: Choose MinTid template file
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _chooseTemplateFile($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  my $tpt = $self->{erefs}{-plugin}->get($self->{name}, 'mintid_template');

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
                       -title => $self->{name} . ': MinTid mall',
                      );

  return 0
      unless ($file and -r $file and (not $tpt or $tpt and ($file ne $tpt)));

  $self->{cfg}{mintid_template} = $file;
  $self->_modified();
  $self->selectFileButton();

  return $file;
} # Method _chooseTemplateFile

#----------------------------------------------------------------------------
#
# Method:      _createTemplateFile
#
# Description: Create MinTid template file
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _createTemplateFile($) {
  # parameters
  my $self = shift;

  my $win_r = $self->{win};

  my $tpt = $self->{erefs}{-plugin}->get($self->{name}, 'mintid_template');

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
        -> getSaveFile(-defaultextension => '.csv',
                       -filetypes => [
                           ['csv files' , '.csv'],
                           ['Text files', '.txt'],
                           ['All Files' , '*'   ],
                                     ],
                       -initialdir  => $initialdir ,
                       -initialfile => $initialfile,
                       -title => $self->{name} . ': MinTid mall',
                      );

  return 0
      unless ($file and (not $tpt or $tpt and ($file ne $tpt)));

  $self->{cfg}{mintid_template} = $file;
  $self->_saveTemplate($file);
  $self->_modified();
  $self->selectFileButton();

  return $file;
} # Method _createTemplateFile

#----------------------------------------------------------------------------
#
# Method:      problem
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
# Description: Setup export time data to MinTid template
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
  my $tpt = $self->{erefs}{-plugin}->get($self->{name}, 'mintid_template');

  unless ($tpt) {
    $confirm
       ->popup(
               -title => ': Fel',
               -text  => ['Ingen MinTid mall angiven!',
                          'Välj en mall i Inställningar'
                         ],
              );
    return 0;
  } # unless #

  unless (-f $tpt) {
    $confirm
       -> popup(
                -title => ': Fel',
                -text  => ['Kan inte hitta MinTid mall: '.
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
# Description: Calculate work time for week and export to MinTid template file
#              MinTid_<week start date>_<week end date>.csv
#
# Format for template file
#
# START_TEMPLATE
# Project,Task,Type,Mon,Comment,Tue,Comment,Wed,Comment,Thu,
#        Comment,Fri,Comment,Sat,Comment,Sun,Comment,END_COLUMN
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
#  undef : The MinTid-template was not possible to use
#  0 : No MinTid file created due to problems
#  1 : Results exported to file

sub _doExport($$) {
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
                -title => 'MinTid : Problem',
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

  # Find out filename to create: MinTid_<first-date>_<last-date>.csv
  my ($filename, $directories) = fileparse($template);
  $self->{outfile} =
      File::Spec->catfile
        ($directories ,
         'MinTid_' . $self->{first_date} . '_' . $self->{last_date} . '.csv'
         );

  # Open files and copy to area were to insert times

  my $tp = FileHandle->new($template, '<');
  unless (defined($tp)) {
    $confirm
       -> popup(
                -title => 'avbröt MinTid',
                -text  => ['Det gick inte att läsa MinTid-mallen:',
                           $template,
                           $!],
               );
    return undef;
  } # unless #

  my $fh = FileHandle->new($self->{outfile}, '>');
  unless (defined($fh)) {
    $confirm
       -> popup(
                -title => 'avbröt MinTid',
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
                -title => 'avbröt MinTid',
                -text  => ['Kunde inte hitta start märket i MinTid-mallen:',
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
        $time = $calc->formatTime(CSV_DECIMAL_KOMMA, $day_r->{activities}{$activity});
        $fh->print(',', $time, ',');
        $fractions++
            if ($time =~ m/^\d+\.\d[^0]$/);
      } # for #

    } else {

      $activity = "\n";
      $fh->print($event, ',,');

      for my $day_r (@$weekdays_r) {
        $time = $calc->formatTime(CSV_DECIMAL_KOMMA, $day_r->{events}{$event});
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
      $time = $calc->formatTime(CSV_DECIMAL_KOMMA, $day_r->{not_event_time});
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
                -title => 'avbröt MinTid',
                -text  => ['FEL: Det gick inte att skriva till fil:',
                           $self->{outfile},
                           $!],
               );

  # Any problem detected?
  if (@doubtfull or $not_understood or $other or $fractions) {

    my $t = ['VARNING:', undef];
    my $d = [];

    if (@doubtfull) {
      push @$t, ('Ett antal händelser verkar inte vara för MinTid.'."\n".
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
                -title => 'MinTid : VARNING',
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

  my $week_work_minutes = $self->{erefs}{-calculate}->getWeekScheduledTime($date);

  if ($total_time > $week_work_minutes) {
    $confirm ->
        popup(
              -title => 'MinTid : Tips',
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
              -title => 'MinTid : Tips',
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
              -title => 'MinTid resultat',
              -text  => ['Skrev veckoarbetstid till:',
                         $self->{outfile}],
             );


  return 1;
} # Method _doExport

#----------------------------------------------------------------------------
#
# Method:      _saveTemplate
#
# Description: Save CSV_TEMPLATE to file
#
# Arguments:
#  - Object reference
#  - Template file name
# Returns:
#  undef : The MinTid-template was not possible to create
#  0 : No template file created due to problems
#  1 : Template saved successfully to file

sub _saveTemplate($$) {
  my $self = shift;
  my ($template) = @_;

  my $confirm   = $self->{erefs}{-week_win}->get('confirm'),
  my $win_r     = $self->{win};

  my $fh = FileHandle->new($template, '>');
  unless (defined($fh)) {
    $confirm
       -> popup(
                -title => 'avbröt MinTid',
                -text  => ['Det gick inte att skapa fil:',
                           $template,
                           $!],
               );
    return undef;
  } # unless #

  $fh->print(CSV_TEMPLATE);

  $fh->close() or
     $confirm
       -> popup(
                -title => 'avbröt MinTid',
                -text  => ['FEL: Det gick inte att skriva till fil:',
                           $template,
                           $!],
               );

  $confirm
     -> popup(
              -title => 'MinTid resultat',
              -text  => ['Filen sparades:',
                         $template],
             );

  return 1;
} # Method _saveTemplate

1;
__END__
