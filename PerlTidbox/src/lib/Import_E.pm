#
package Import_E;
#
#   Document: Import tidbox format E and earlier
#   Version:  1.2   Created: 2011-03-13 07:21
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Import_E.pmx
#

my $VERSION = '1.2';
my $DATEVER = '2011-03-13';

# History information:
#
# 1.0  2007-10-07  Roland Vallgren
#      First issue.
# 1.1  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.2  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
#

#----------------------------------------------------------------------------
#
# Setup
#
use strict;
use warnings;
use integer;

use Version qw(register_import);

use Tk;

use Times;
use EventCfg;

# Register version information
{
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}

# Export
BEGIN {
       use Exporter ();
       our (@ISA, @EXPORT_OK);
       @ISA = qw(Exporter);
       # symbols to export on request
       @EXPORT_OK = qw(import_version_E_data);
      }
our (@EXPORT_OK);

#----------------------------------------------------------------------------
#
# Constants
#

# Tidbox file constants
my $HOME;
if (exists($ENV{HOME})) {
  $HOME = $ENV{HOME};
} else {
  $HOME = $ENV{HOMEDRIVE};
} # if #

my %DATA = (
             HOME     => $HOME,
             RC_FILE  => File::Spec->catfile($HOME , '.tidboxrc'),
           );
$DATA{ARCHIVE_FILE}  = $DATA{RC_FILE} . '.arkiv';
$DATA{RC_FIL_BACKUP} = $DATA{RC_FILE} . '%';
$DATA{OLD_IMPORT_A}  = $DATA{RC_FILE} . '.format_A';
$DATA{OLD_IMPORT_B}  = $DATA{RC_FILE} . '.format_B';
$DATA{OLD_IMPORT_C}  = $DATA{RC_FILE} . '.format_C';
$DATA{OLD_IMPORT_D}  = $DATA{RC_FILE} . '.format_D';
$DATA{OLD_IMPORT_E}  = $DATA{RC_FILE} . '.format_E';

use constant FORMAT_E => 'E';
use constant FORMAT_D => 'D';
use constant FORMAT_C => 'C';
use constant FORMAT_STRING_E => '# Format:' . FORMAT_E;
use constant FORMAT_STRING_D => '# Format:' . FORMAT_D;
use constant FORMAT_STRING_C => '# Format:' . FORMAT_C;

use constant PROGRAM_SETTINGS    => '[PROGRAM SETTINGS]';
use constant EVENT_CONFIGURATION => '[EVENT CONFIGURATION]';
use constant TIMES_DATA          => '[REGISTERED TIME EVENTS]';
use constant ARCHIVE_INFO        => '[ARCHIVE INFORMATION]';

use constant NO_DATE => '0000-00-00';

# Format C event configuration
my @EVENT_CFG_C = ( 'Proj:d:8',
                    'Not:.:24',
                  );

# Registration analysis constants
my $YEAR  = '\d{4}';
my $MONTH = '\d{2}';
my $DAY   = '\d{2}';
my $DATE = $YEAR . '-' . $MONTH . '-' . $DAY;

my $HOUR   = '\d{2}';
my $MINUTE = '\d{2}';
my $TIME   = $HOUR . ':' . $MINUTE;

my $TYPE = '[A-Z]+';

# Global variables
my $confirm;
my $do;
my $start = 0;

#############################################################################
#
# Function section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Function:    read_format_error
#
# Description: Format error, fail
#
# Arguments:
#  - Error popup
# Returns:
#  -

sub read_format_error($) {
  # parameters
  my ($error_popup) = @_;

  &$error_popup('Formatfel i filen: ' . $DATA{RC_FILE}, "Rad nummer : " . $. );
  return 0;
} # sub read_format_error

#----------------------------------------------------------------------------
#
# Function:    set_cfg_sup
#
# Description: Set configuration and supervision data
#
# Arguments:
#  - Configuration object
#  - Supervision object
#  - Imported configuration data hash
#  - Imported supervision data
# Returns:
#  -

sub set_cfg_sup($$$$) {
  # parameters
  my ($configuration, $supervision, $cfg_r, $super) = @_;

  $configuration->_clear();
  $configuration->set(%$cfg_r);

  $supervision->_clear();
  if ($super) {
    $supervision->importData(substr($super, 0, 1),
                             substr($super, 2, 10),
                             substr($super, 13)
                            );

  } else {
    $supervision->importData(0,
                             NO_DATE,
                             ''
                            );

  } # if #

  return 0;
} # sub set_cfg_sup

#----------------------------------------------------------------------------
#
# Function:    read_E_program_settings
#
# Description: Read program settings format E
#
# Arguments:
#  - Initial configuration record
#  - Configuration object
#  - Supervision object
#  - Filehandle
# Returns:
#  undef if failed to read

sub read_E_program_settings($$$$) {
  # parameters
  my ($cfg_r, $configuration, $supervision, $fh) = @_;


  my $super;
  my $line;

  while (defined($line = $fh->getline())) {

    $line =~ s/\s+$//o;

    last
        unless $line;

    if ($line =~ /^supervision=(\d.*)$/o) {
      $super = $1;

    } elsif ($line =~ /^([^=]+)=(\S+)$/o) {
      $cfg_r->{$1} = $2;

    } else {
      return undef;

    } # if #

  } # while #

  set_cfg_sup($configuration, $supervision, $cfg_r, $super);

  return 1;
} # sub read_E_program_settings

#----------------------------------------------------------------------------
#
# Function:    read_D_program_settings
#
# Description: Read program settings format D
#
# Arguments:
#  - Initial configuration record
#  - Configuration object
#  - Supervision object
#  - Filehandle
#  - Last line read, old format of program settings
# Returns:
#  Last line not matching configuration
#  undef if failed to read

sub read_D_program_settings($$$$$) {
  # parameters
  my ($cfg_r, $configuration, $supervision, $fh, $line) = @_;


  my $super;

  do {

    $line =~ s/\s+$//o;

    if ($line =~ /^supervision=(\d.*)$/o) {
      $super = $1;

    } elsif ($line =~ /^([^=]+)=(\S+)$/o) {
      $cfg_r->{$1} = $2;

    } else {
      set_cfg_sup($configuration, $supervision, $cfg_r, $super);
      return $line;

    } # if #

  } while (defined($line = $fh->getline()));

  return undef;
} # sub read_D_program_settings

#----------------------------------------------------------------------------
#
# Function:    read_E_eventcfg_settings
#
# Description: Read event configuration settings format E
#
# Arguments:
#  - Event cfg data
#  - Filehandle
# Returns:
#  undef if failed to read

sub read_E_eventcfg_settings($$) {
  # parameters
  my ($event_cfg, $fh) = @_;


  my ($line, $date, $cfg_r, $keep_cfg_r);

  while (defined($line = $fh->getline())) {

    $line =~ s/\s+$//o;

    last
        unless $line;

    if ($line =~ /^$DATE$/o) {
      if ($date) {
        if ($date gt NO_DATE) {
          $event_cfg->importData($date, $cfg_r);
        } else {
          $keep_cfg_r = $cfg_r;
        } # if #
      } # if #

      $cfg_r = [];
      $date = $line;

    } elsif ($line =~ /^[^:]+:.:/o) {
      push @{$cfg_r}, $line;

    } else {
      # Faulty format
      last;

    } # if #

  } # while #

  if ($date) {
    return $cfg_r
        unless ($date gt NO_DATE);

    $event_cfg->importData($date, $cfg_r);
  } # if #


  return $keep_cfg_r;
} # sub read_E_eventcfg_settings

#----------------------------------------------------------------------------
#
# Function:    read_D_eventcfg_settings
#
# Description: Read event configuration settings format D
#
# Arguments:
#  - Event configuration object
#  - Filehandle
#  - Last line read, old format of program settings
# Returns:
#  Last line not matching event configuration
#  undef if failed to read

sub read_D_eventcfg_settings($$$) {
  # parameters
  my ($event_cfg, $fh, $line) = @_;


  my ($date, $cfg_r, $keep_cfg_r);

  do {

    $line =~ s/\s+$//o;


    if ($line =~ /^($DATE)([^:]+:.:.*)$/o) {
      if ($date) {
        if ($date gt NO_DATE) {
          $event_cfg->importData($date, $cfg_r);
        } else {
          $keep_cfg_r = $cfg_r;
        } # if #
      } # if #

      $cfg_r = [$2];
      $date = $1;

    } elsif ($line =~ /^[^:]+:.:/o) {
      push @{$cfg_r}, $line;

    } elsif ($date) {
      return ($line, $cfg_r)
          if ($date eq NO_DATE);

      $event_cfg->importData($date, $cfg_r);
      return ($line, $keep_cfg_r);

    } else {
      return ($line, $cfg_r);

    } # if #

  } while (defined($line = $fh->getline()));

  if ($date) {
    return (undef, $cfg_r)
        if ($date eq NO_DATE);

    $event_cfg->importData($date, $cfg_r);
    return (undef, $keep_cfg_r);
  } # if #

  return (undef, $cfg_r);

} # sub read_D_eventcfg_settings

#----------------------------------------------------------------------------
#
# Function:    read_times_data
#
# Description: Read times data and keep date of first registration
#
# Arguments:
#  - File handle
#  - Times object
#  - Calculator
# Returns:
#  Last read line
#  Start date of the set
#  End date of the set

sub read_times_data($$$) {
  # parameters
  my ($fh, $times, $calc) = @_;


  my $line;
  my $t_r = [];
  my ($start_date, $end_date);

  while (defined($line = $fh->getline())) {

    $line =~ s/\s+$//;

    last
        unless $line;

    last
        unless ($line =~ /^($DATE),$TIME,$TYPE,.*$/o);

    $start_date = $1
        if (not $start_date or ($1 lt $start_date));

    $end_date   = $1
        if (not $end_date   or ($1 gt $end_date  ));

    push @$t_r, $line;

  } # while #

  $times->importData($t_r);

  # Fix start and end date of the set

  $start_date =
    $calc->dayInWeek(
                     $calc->weekNumber($start_date),
                     1
                    );
  $end_date =
    $calc->dayInWeek(
                     $calc->weekNumber($end_date),
                     7
                    );

  return ($line, $start_date, $end_date);
} # sub read_times_data

#----------------------------------------------------------------------------
#
# Function:    read_format_E_data
#
# Description: Read format E tidbox data from import
#
# Arguments:
#  - Filhandle
#  - Initial configuration record
#  - Configuration object
#  - Event configuration object
#  - Supervision object
#  - Times object
#  - Reference to error popup
# Returns:
#  True if import worked

sub read_format_E_data($$$$$$$) {
  # parameters
  my ($fh, $cfg_r, $configuration, $event_cfg, $supervision, $times, $error_popup) = @_;


  my $line;
  while (defined($line = $fh->getline())) {

    next
       if $line =~ s/^\s*(?:#|$)//o;

    $line =~ s/\s+$//o;

    if ($line eq PROGRAM_SETTINGS) {
      read_format_error($error_popup)
          unless (defined(read_E_program_settings(
                                                  $cfg_r,
                                                  $configuration,
                                                  $supervision,
                                                  $fh
                                                 )
                         )
                 );

    } elsif ($line eq EVENT_CONFIGURATION) {
      my $cfg_r = read_E_eventcfg_settings($event_cfg,
                                           $fh
                                          );

      $event_cfg->importData(NO_DATE, $cfg_r)
          if (ref($cfg_r));

      $event_cfg->strings();

    } elsif ($line eq TIMES_DATA) {
      read_format_error($error_popup)
          unless ($times->_load($fh));
      $times->dirty();

    } else {
      read_format_error($error_popup);

    } # if #

  } # while #

  return 0;
} # sub read_format_E_data

#----------------------------------------------------------------------------
#
# Function:    read_format_D_data
#
# Description: Read format D tidbox data from import or archive
#
# Arguments:
#  - Filhandle
#  - Initial configuration record
#  - Configuration object
#  - Event configuration object
#  - Supervision object
#  - Times object
#  - Reference to error popup
# Returns:
#  undef if end of file
#  0 if import failed
#  Line after impor

sub read_format_D_data($$$$$$$) {
  # parameters
  my ($fh, $cfg_r, $configuration, $event_cfg, $supervision, $times, $error_popup) = @_;


  my $line;
  while (defined($line = $fh->getline())) {

    $line =~ s/\s+$//o;

    if ($line =~ /^[^=]+=\S/o) {
      $line = read_D_program_settings(
                                      $cfg_r,
                                      $configuration,
                                      $supervision,
                                      $fh,
                                      $line
                                     );
      redo
          if $line;

    } elsif (($line =~ /^$DATE[^:]+:.:.*$/o) or
             ($line =~ /^[^:]+:.:.*$/o)) {
      my $cfg_r;
      ($line, $cfg_r) = read_D_eventcfg_settings($event_cfg,
                                                 $fh,
                                                 $line
                                                );
      $event_cfg->importData(NO_DATE, $cfg_r)
          if (ref($cfg_r));
      $event_cfg->strings();
      redo
          if $line;

    } elsif ($line eq '# End of configuration data') {
      read_format_error($error_popup)
          unless ($times->_load($fh));
      $times->dirty();

    } else {
      read_format_error($error_popup);

    } # if #

  } # while #

  return 0;
} # sub read_format_D_data

#----------------------------------------------------------------------------
#
# Function:    read_format_E_archive
#
# Description: Read format E tidbox data from archive
#
# Arguments:
#  - Filhandle
#  - Archive
#  - Reference to error popup
# Returns:
#  True if import worked

sub read_format_E_archive($$$) {
  # parameters
  my ($fh, $archive, $error_popup) = @_;


  my ($line, $date, $start_date, $end_date, $cfg_r);
  my $set = {};

  while (defined($line = $fh->getline())) {

    next
        if $line =~ s/^\s*(?:#|$)//o;

    $line =~ s/\s+$//o;

    if ($line eq ARCHIVE_INFO) {

      # Read archive information
      while (defined($line = $fh->getline())) {
        last
            if ($line =~ /^\s*(?:#|$)/o);
        $set->{$1} = $2
            if ($line =~ /^([^=]+)=(.*?)\s*$/o);
      } # while #

    } elsif ($line eq EVENT_CONFIGURATION) {

      $set->{event_cfg} =
        new EventCfg(-archive   => $set->{date_time}     ,
                     -cfg       => $archive->{-cfg}      ,
                     -calculate => $archive->{-calculate},
                     -clock     => $archive->{-clock}    ,
                    );
      $cfg_r = read_E_eventcfg_settings($set->{event_cfg},
                                        $fh
                                       );

    } elsif ($line eq TIMES_DATA) {

      $set->{times} = new Times;
      ($line, $start_date, $end_date) =
          read_times_data($fh, $set->{times}, $archive->{-calculate});
      $set->{start_date} = $start_date;
      $set->{end_date}   = $end_date
          unless ($set->{end_date} or ($set->{end_date} lt $end_date));
      last;

    } elsif ($line =~ /^# Format:/) {
      last;

    } else {
      read_format_error($error_popup);

    } # if #

  } # while #


  $set->{event_cfg}->importData($start_date, $cfg_r)
      if (ref($cfg_r));

  # Add the set to the archive
  $archive->importData($set);

  return $line;
} # sub read_format_E_archive

#----------------------------------------------------------------------------
#
# Function:    read_format_D_archive
#
# Description: Read format D tidbox data from archive
#
# Arguments:
#  - Filhandle
#  - Archive
#  - Reference to error popup
# Returns:
#  undef if end of file
#  0 if import failed
#  Line after import

sub read_format_D_archive($$$) {
  # parameters
  my ($fh, $archive, $error_popup) = @_;


  my $cfg_r;
  my $set;
  my ($line, $start_date, $end_date);

  while (defined($line = $fh->getline())) {

    $line =~ s/\s+$//o;

    last
        unless $line;

    if ($line =~ /^# Date of archive:\s+($DATE)\s+/) {
      $set = {date_time => $1};

    } elsif (($line =~ /^$DATE[^:]+:.:.*$/o) or
             ($line =~ /^[^:]+:.:.*$/o))
    {
      $set->{event_cfg} =
        new EventCfg(-archive   => $set->{date_time}     ,
                     -cfg       => $archive->{-cfg}      ,
                     -calculate => $archive->{-calculate},
                     -clock     => $archive->{-clock}    ,
                    );
      ($line, $cfg_r) =
          read_D_eventcfg_settings($set->{event_cfg},
                                   $fh,
                                   $line
                                  );
      redo
          if $line;

    } elsif ($line =~ /^# End of configuration data/) {
      $set->{times} = new Times;
      ($line, $start_date, $end_date) =
          read_times_data($fh, $set->{times}, $archive->{-calculate});
      $set->{start_date} = $start_date;
      $set->{end_date}   = $end_date;

      redo
          if $line;

    } elsif ($line =~ /^# Format:/) {
      last;

    } elsif ($line =~ /^#/) {
      # Just ignore other comments

    } else {
      read_format_error($error_popup);
      return undef;

    } # if #

  } # while #

  $set->{event_cfg}->importData($start_date, $cfg_r)
      if (ref($cfg_r));

  # Add the set to the archive
  $archive->importData($set);

  return $line;
} # sub read_format_D_archive

#----------------------------------------------------------------------------
#
# Function:    read_format_C_archive
#
# Description: Read format C tidbox data from archive
#
# Arguments:
#  - Filhandle
#  - Archive
#  - Reference to error popup
# Returns:
#  undef if end of file
#  Line after import

sub read_format_C_archive($$$) {
  # parameters
  my ($fh, $archive, $error_popup) = @_;


  my $cfg_r = [ @EVENT_CFG_C ];
  my $t_r = [];
  my $set = {};

  my ($line, $start_date, $end_date);

  while (defined($line = $fh->getline())) {

    $line =~ s/\s+$//o;

    if ($line =~ /^($DATE),($TIME,$TYPE,)(.*)$/o) {

      my ($date, $time_type, $event) = ($1, $2, $3);

      $start_date = $date
          if (not $start_date or ($date lt $start_date));

      $end_date = $date
          if (not $end_date   or ($date gt $end_date  ));

      if ($event =~ /^(\d{4})\s(.*)$/o) {
        push @$t_r, $date . ',' . $time_type . $1 . ',' . $2;

      } elsif ($event =~ /^\d{4}$/o) {
        push @$t_r, $line . ',';

      } else {
        push @$t_r, $date . ',' . $time_type . ',' . $event;

      } # if #

    } elsif ($line =~ /^#\sArchived\speriod\s$DATE\s/o) {
      # Just read over archive period

    } elsif ($line =~ /^#\sDate\sof\sarchive:\s($DATE\s$TIME)/o) {
      $set->{date_time} = $1;

    } else {
      last;

    } # if #

  } # while #

  # Fix start and end date of the set

  my $calc = $archive->{-calculate};

  $start_date =
      $calc -> dayInWeek(
                         $calc->weekNumber($start_date),
                         1
                        );
  $end_date =
      $calc -> dayInWeek(
                         $calc->weekNumber($end_date),
                         7
                        );

  $set->{start_date} = $start_date;
  $set->{end_date}   = $end_date;


  $set->{event_cfg} =
    new EventCfg(-archive   => $set->{date_time}     ,
                 -cfg       => $archive->{-cfg}      ,
                 -calculate => $archive->{-calculate},
                 -clock     => $archive->{-clock}    ,
                );
  $set->{event_cfg}->importData($start_date, $cfg_r);

  $set->{times} = new Times;
  $set->{times}->importData($t_r);

  # Add the set to the archive
  $archive->importData($set);

  return $line;
} # sub read_format_C_archive

#----------------------------------------------------------------------------
#
# Function:    import_data
#
# Description: Try to import tidbox data from version E or older
#
# Arguments:
#  - Configuration object
#  - Event configuration object
#  - Supervision object
#  - Times object
#  - Reference to error popup
# Returns:
#  True if import succeded

sub import_data($$$$$) {
  # parameters
  my ($configuration, $event_cfg, $supervision, $times, $error_popup) = @_;


  # Default import is use H: for windows backup
  my $cfg_r = {'MSWin32_do_backup' => 1,
               'MSWin32_backup_directory' => 'H:\.tidbox',
              };

  my $fh = new FileHandle($DATA{RC_FILE}, '<');

  return 0
      unless(defined($fh));

  my $line = $fh->getline();
  $line =~ s/\s+$//o;
  my $format;

  if ($line eq FORMAT_STRING_E) {
    # Read format E tidboxrc file
    $format = FORMAT_E;
    read_format_E_data(
                       $fh,
                       $cfg_r,
                       $configuration,
                       $event_cfg,
                       $supervision,
                       $times,
                       $error_popup
                      );

  } elsif ($line eq FORMAT_STRING_D) {
    # Read format D tidboxrc file
    $format = FORMAT_D;
    read_format_D_data(
                       $fh,
                       $cfg_r,
                       $configuration,
                       $event_cfg,
                       $supervision,
                       $times,
                       $error_popup
                      );

  } else {
    &$error_popup('Ej supportat format på tidboxdata', 'Fil: ' . $DATA{RC_FILE});
    $fh->close();
    return 0;

  } # if #

  $fh->close();

  register_import($configuration->get('last_version'), $format);

  return 1;
} # sub import_data

#----------------------------------------------------------------------------
#
# Function:    import_archive
#
# Description: Import tidbox data from archive
#
# Arguments:
#  - Archive
#  - Reference to error popup
# Returns:
#  True if import succeded

sub import_archive($$) {
  # parameters
  my ($archive, $error_popup) = @_;


  my $fh = new FileHandle($DATA{ARCHIVE_FILE}, '<');

  return 0
      unless(defined($fh));

  my $line;
  my %format;
  while (defined($line = $fh->getline())) {
    $line =~ s/\s+$//o;

    if ($line eq FORMAT_STRING_E) {
      # Read format E tidboxrc archive
      $format{FORMAT_E()} = 1;
      $line = read_format_E_archive($fh,
                                    $archive,
                                    $error_popup,
                                   );


    } elsif ($line eq FORMAT_STRING_D) {
      # Read format D tidboxrc file
      $format{FORMAT_D()} = 1;
      $line = read_format_D_archive($fh,
                                    $archive,
                                    $error_popup,
                                   );


    } elsif ($line eq FORMAT_STRING_C) {
      # Read format C tidboxrc file
      $format{FORMAT_C()} = 1;
      $line = read_format_C_archive($fh,
                                    $archive,
                                    $error_popup,
                                   );


    } else {
      &$error_popup('Ej supportat format på tidboxdata', 'Fil: ' . $DATA{ARCHIVE_FILE});
      return 0;

    } # if #

    redo
        if $line;

  } # while #

  register_import(join(', ', sort(keys(%format))), 'Arkiv');

  return 1;
} # sub import_archive

#----------------------------------------------------------------------------
#
# Function:    import_query
#
# Description: Check what data to import that exists and ask user what
#              to import
#
# Arguments:
#  - Configuration object
#  - Event configuration object
#  - Supervision object
#  - Times object
#  - Calculator object
#  - Archive object
#  - Reference to error popup
# Returns:
#  -

sub import_query($$$$$$$) {
  # parameters
  my ($configuration, $event_cfg, $supervision, $times,
      $calculate, $archive, $error_popup) = @_;

  # Check what importable data exists

  return 0
      unless (-f $DATA{RC_FILE});

  my %old;
  $old{RC_FILE}       = 1;
  $old{ARCHIVE_FILE}  = -f $DATA{ARCHIVE_FILE};
  $old{RC_FIL_BACKUP} = -f $DATA{RC_FIL_BACKUP};
  $old{OLD_IMPORT_E}  = -f $DATA{OLD_IMPORT_E};
  $old{OLD_IMPORT_D}  = -f $DATA{OLD_IMPORT_D};
  $old{OLD_IMPORT_C}  = -f $DATA{OLD_IMPORT_C};

  # Use Confirm popup to ask
  $confirm =
       new Gui::Confirm(
                        win     => {name => 'impt'},
                        -title  => 'Tidbox Importer',
                       );

  # Defaul: Do not import anything
  $do->{-import} = 0;

  my $tmp = [
    "\nData från en tidigare version av Tidbox upptäckt.\n\n".
    "Välj vad du vill göra:",
    [ "Importera data:",
      \$do->{-import},
      [0, 'Ignorera',  {-side => 'right'} ],
      [1, 'Importera data', {-side => 'right'} ],
    ],
  ];

  push @{$tmp->[1]},
      [2, 'Importera både data och arkiv', {-side => 'right'} ]
    if ($old{ARCHIVE_FILE});

  push @$tmp,
      "\nFöljande gamla Tidbox filer har detekterats:";

  for my $k (qw(RC_FILE ARCHIVE_FILE
                RC_FIL_BACKUP OLD_IMPORT_E OLD_IMPORT_D OLD_IMPORT_C)
            )
  {
    push @$tmp, "\t" . $DATA{$k}
        if $old{$k};
    $do->{$k} = 0;
  } # for #

  push @$tmp,
      "(Ingen fil tas bort)";

  $confirm
    -> display(-fulltitle => 'Ny version av Tidbox',
               -radio => $tmp,
               -buttons => [
                            'Avbryt',    [ \&quit, -1 ],
                            'Verkställ', [ \&quit,  1 ],
                           ]
              );
  MainLoop;

  return undef
      if ($start == -1);
  return 0
      if ($start == 0);

  # Import data as requested

  if ($do->{-import} == 2) {
    $start = import_archive($archive,
                            $error_popup,
                           );
    return undef
        unless $start;
  } # if #

  if ($do->{-import}) {
    $start = import_data($configuration,
                         $event_cfg,
                         $supervision,
                         $times,
                         $error_popup
                        );
    return undef
        unless $start;
  } # if #

  # Remove archive date if archive not is imported
  $configuration->set(archive_date => NO_DATE)
      unless ($do->{-import} == 2);

  # Save all data before starting the tool
  for my $r ($times, $event_cfg, $supervision, $archive, $configuration) {
    $r->save();
  } # for #


  return $start;
} # sub import_query

#----------------------------------------------------------------------------
#
# Function:    quit
#
# Description: Quit, do not start tidbox
#
# Arguments:
#  -
# Returns:
#  -

sub quit($) {

  $confirm->{win}{win}->destroy();
  delete($confirm->{win}{win});

  $start = shift();
  return 0;
} # sub quit

1;
__END__
