#----------------------------------------------------------------------------
#
#   Arbetstid verktyg
#
#   Version:  4.9   Created: 2018-12-12
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: tidbox.plx
#

my $VERSION = '4.9';
my $DATEVER = '2018-12-12';

#----------------------------------------------------------------------------
#
# Revision History
# 4.0  2007-10-07  Roland Vallgren
#      New fileformat, import from earlier format
#      Numerical versions, Collect version information about classes
#      Use NoteBook layout of confirm window for About window
# 4.1  2008-07-28  Roland Vallgren
#      Added reference to error handler in Gui::Main
# 4.2  2008-09-06  Roland Vallgren
#      Warning and Error contents copiable
# 4.3  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 4.4  2011-03-13  Roland Vallgren
#      Added FileSupervisor to handle files
#      Errors and warnings are logged
# 4.5  2013-05-21  Roland Vallgren
#      Added call of session lock dialog in Main
# 4.6  2015-08-10  Roland Vallgren
#      Perl Tk installation directory for Solaris/Linux not predefined
#      Show version information in log
# 4.7  2017-06-12  Roland Vallgren
#      Week window need edit
#      Added handling of plugins
# 4.8  2017-10-05  Roland Vallgren
#      Move files to TbFile::
#      References to other objects in own hash
# 4.9  2018-12-05  Roland Vallgren
#      Updated pod
#

#----------------------------------------------------------------------------
#
# Setup
#

# Use Pragma
use strict;
use warnings;
use bytes;
use locale;

# Use standard modules
use FindBin;
use Getopt::Long;
use Pod::Usage;
use Tk;

# Tidbox modules
use lib "$FindBin::RealBin/lib";

use Version qw(%tool_info);
use TitleClock;
use Calculate;
use TbFile;
use Gui::Time;
use Gui::Edit;
use Gui::Week;
use Gui::Year;
use Gui::Main;
use Gui::Confirm;
use Gui::Earlier;
use Gui::Settings;



# Register version information
{
  use Version qw(register_version register_external);
  register_version(
                   -name    => 'TidBox',
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
  register_external(
                     'Perl VERSION: ' . sprintf('v%vd', $^V),
                     'Tk::VERSION: ' . $Tk::VERSION,
                   );
}

our %tool_info;
#----------------------------------------------------------------------------
#
# Global variable declaration section
#

my $warning = {         # Warning popup
                name    => 'warn',
                prefix  => 'VARNING:',
                list    => [],
              };

my $error   = {         # Error popup
                name    => 'erro',
                prefix  => 'FEL:',
                list    => [],
              };

my $main_win;          # Main window

#----------------------------------------------------------------------------
#
# Function section
#
#----------------------------------------------------------------------------
#

#----------------------------------------------------------------------------
#
# Function:    add_err_warn
#
# Description: Add error or warning to list, and log if possible
#
# Arguments:
#  - Reference to hash
#  ... Array to add
# Returns:
#  -

sub add_err_warn($$) {
  # parameters
  my ($ref, $msg) = @_;

  # Add to list
  push @{$ref->{list}}, @{$msg};

  # Log
  if (ref($ref->{handler})) {
    my $log = $ref->{handler};
    for my $l (@{$msg}) {
      $log->log($ref->{prefix}, $l)
    } # for #
  } # if #

  return 0;
} # sub add_err_warn

#----------------------------------------------------------------------------
#
# Function:    warning_done
#
# Description: Remove warning popup
#
# Arguments:
#  -
# Optional Arguments:
#  0 - An argument to keep the collected warning list
# Returns:
#  -

sub warning_done(;$) {
  # parameters
  my ($keep) = @_;

  @{$warning->{list}} = () unless $keep;
  return 0;
} # sub warning_done

#----------------------------------------------------------------------------
#
# Function:    warning_popup
#
# Description: Add warning to warning popup and display
#
# Optional Arguments:
#  0 - String to add
# Returns:
#  -

sub warning_popup(@) {

  # Add to list and log
  add_err_warn($warning, \@_);

  # Start warnings are handled
  $warning->{start}=0;

  # Do not try if there are no warnings
  return 0
      unless (@{$warning->{list}});

  # Use confirm popup
  return
     $main_win->showWarn(
                         -title => 'programvarningar',
                         -text   => ['VARNINGAR:'],
                         -data   => [$warning->{list}],
                         -done   => \&warning_done,
                        )
      if ($main_win);


  return 0;
} # sub warning_popup

#----------------------------------------------------------------------------
#
# Function:    warning_handler
#
# Description: Catch warnings
#
# Arguments:
#  0 - Warning string from PERL
# Returns:
#  -

sub warning_handler {
  # parameters
  my ($s) = @_;


  return 0
      unless defined($s);

  warning_popup(split("\n", join("\n", @_)));

  return 0;
} # sub warning_handler

#----------------------------------------------------------------------------
#
# Function:    error_done
#
# Description: Remove error popup
#
# Arguments:
#  -
# Optional Arguments:
#  0 - An argument to keep the collected error list
# Returns:
#  -

sub error_done(;$) {
  # parameters
  my ($keep) = @_;

  $error->{list} = []
      unless $keep;
  if (Exists($error->{win})) {
    $error->{geometry} = $1
        if ($error->{win}->geometry() =~ /(\+\d+\+\d+$)/o);
    $error->{win}->destroy();
  } # if #
  $error->{win}=undef;

  return 0;
} # sub error_done

#----------------------------------------------------------------------------
#
# Function:    error_popup
#
# Description: Add error to error popup and display
#
# Arguments:
#  0 .. n - Strings to add
# Returns:
#  -

sub error_popup(@) {

  # Add to list and log
  add_err_warn($error, \@_);

  # Remove error popup
  error_done('keep');

  # Setup error popup
  my $win_r;
  $win_r = $main_win->getWin()
      if ref($main_win);
  if (exists($win_r->{win})) {
    $error->{win} = $win_r->{win}
        -> Toplevel(-title => $tool_info{icontitle});
    $error->{text} = $error->{win}
        -> Label(-text => 'FEL:');
  } else {
    $error->{win} = new MainWindow(-title => $tool_info{version});
    $error->{text} = $error->{win}
        -> Label(-text => $tool_info{icontitle} . ' : Kan inte starta');
  } # if #

  $error->{win} -> geometry($error->{geometry})
      if ($error->{geometry});
  $error->{win} -> protocol('WM_DELETE_WINDOW', \&error_done);

  # Add all error texts
  $error->{text}
      -> pack(-side => 'top');

  my $w = 10;
  for my $s (@{$error->{list}}) {
    $w = length($s)
        if ($w < length($s));
    $s =~ s/\s+$//;
  } # for #
  $error->{item} = $error->{win}
      -> Frame()
      -> pack(-side => 'top', -expand => '1', -fill => 'both')
      -> ROText(
                -wrap => 'no',
                -height => @{$error->{list}} + 1,
                -width => $w,
               )
      -> pack(-side => 'left')
      -> Insert(join("\n", @{$error->{list}}));

  ### Button area ###
  $error->{button_area} = $error->{win}
      -> Frame()
      -> pack(-side => 'top', -fill => 'both');

  # Done button
  $error->{button_done} = $error->{button_area}
      -> Button(-text => 'St�ng', -command => \&error_done)
      -> pack(-side => 'top');

  # If no mainwindow, let Tk show this
  unless (exists($win_r->{win})) {
    MainLoop;
    exit 0;
  } # unless #

  return 0;
} # sub error_popup

#----------------------------------------------------------------------------
#
# Function:    about_popup
#
# Description: Show about information
#
# Arguments:
#  0 - Reference to window hash
# Returns:
#  -

sub about_popup($) {
  # parameters
  my ($win_r) = @_;


  $win_r->{confirm}
      -> popup(-fulltitle => 'Om TidBox',
               -text   => $tool_info{about_head},
               -data   => $tool_info{about},
               -layout => 'NoteBook'
              );

  return 0;
} # sub about_popup

#----------------------------------------------------------------------------
#
# Function:    parse_commandline
#
# Description: Parse command line command line options
#
# Arguments:
#  -
# Returns:
#  Reference to arguments hash

sub parse_commandline($) {
  # parameters
  my ($call_string) = @_;

  # Function Body

  # local variables
  my $args = {};
  my $argv = [ @ARGV ];

  # Get options through Getopts::Long
  GetOptions($args,
             'help|?',
             'man',
             'directory=s',
            )
      or pod2usage(2);
  pod2usage(2)
      if $args->{help};
  pod2usage('-exitstatus' => 0, '-verbose' => 2)
      if $args->{man};

  # Get arguments
  pod2usage(2)
      if @ARGV;

  $args->{-argv} = $argv;
  $args->{-call_string} = $call_string;
  return $args;
} # sub parse_commandline

#----------------------------------------------------------------------------
#
# Main program
#

# Parse command line
my $args = parse_commandline($0);

# Create Calculator
my $calculate = new Calculate();

# Create TbFile
my $tbFile = new TbFile($args);

# Create TitleClock
my $clock = new TitleClock();

# Create Earlier
my $earlier = new Gui::Earlier();

# Create Main
$main_win =
      new Gui::Main(
                    -title => $tool_info{version},
                   );

# Create Edit
my $edit_win =
    new Gui::Edit(
                  -title => $tool_info{icontitle},
                 );

# Create Week
my $week_win =
     new Gui::Week(
                   -title => $tool_info{icontitle},
                  );

# Create 
my $year_win =
    new Gui::Year(
                  -title => $tool_info{icontitle},
                 );

# Create Settings
my $settings =
    new Gui::Settings(
                      -title => $tool_info{icontitle},
                     );

# Add needed references to other objects

$calculate ->
    configure(
              -clock       => $clock,
              -event_cfg   => $tbFile->getRef('-event_cfg'),
              -times       => $tbFile->getRef('-times'),
             );

$clock ->
    configure(
              -calculate => $calculate,
             );


$tbFile ->
    configure(
              -calculate   => $calculate,
              -clock       => $clock,
              -error_popup => \&error_popup,
             );


$earlier ->
    configure(
              -cfg => $tbFile->getRef('-cfg'),
             );


$main_win ->
    configure(
              -clock         => $clock,
              -calculate     => $calculate,
              -tbfile        => $tbFile,
              -cfg           => $tbFile->getRef('-cfg'),
              -lock          => $tbFile->getRef('-lock'),
              -session       => $tbFile->getRef('-session'),
              -times         => $tbFile->getRef('-times'),
              -event_cfg     => $tbFile->getRef('-event_cfg'),
              -supervision   => $tbFile->getRef('-supervision'),
              -start_warning => \&warning_popup,
              -earlier       => $earlier,
              -week_win      => $week_win,
              -edit_win      => $edit_win,
              -year_win      => $year_win,
              -sett_win      => $settings,
              -error_popup   => \&error_popup,
             );

$edit_win ->
    configure(
              -clock       => $clock,
              -calculate   => $calculate,
              -cfg         => $tbFile->getRef('-cfg'),
              -times       => $tbFile->getRef('-times'),
              -session     => $tbFile->getRef('-session'),
              -event_cfg   => $tbFile->getRef('-event_cfg'),
              -earlier     => $earlier,
              -parent_win  => $main_win->getWin(),
              -week_win    => $week_win,
             );

$week_win ->
    configure(
              -clock       => $clock,
              -calculate   => $calculate,
              -cfg         => $tbFile->getRef('-cfg'),
              -session     => $tbFile->getRef('-session'),
              -times       => $tbFile->getRef('-times'),
              -event_cfg   => $tbFile->getRef('-event_cfg'),
              -parent_win  => $main_win->getWin(),
              -year_win    => $year_win,
              -edit_win    => $edit_win,
             );

$year_win ->
    configure(
              -clock       => $clock,
              -calculate   => $calculate,
              -cfg         => $tbFile->getRef('-cfg'),
              -session     => $tbFile->getRef('-session'),
              -times       => $tbFile->getRef('-times'),
              -archive     => $tbFile->getRef('-archive'),
              -parent_win  => $main_win->getWin(),
              -week_win    => $week_win,
              -edit_win    => $edit_win,
             );

$settings ->
    configure(
              -clock       => $clock,
              -calculate   => $calculate,
              -cfg         => $tbFile->getRef('-cfg'),
              -session     => $tbFile->getRef('-session'),
              -times       => $tbFile->getRef('-times'),
              -event_cfg   => $tbFile->getRef('-event_cfg'),
              -supervision => $tbFile->getRef('-supervision'),
              -log         => $tbFile->getRef('-log'),
              -plugin      => $tbFile->getRef('-plugin'),
              -tbfile      => $tbFile,
              -earlier     => $earlier,
              -parent_win  => $main_win->getWin(),
              -week_win    => $week_win,
# TODO Temporary. Main and Edit should subscribe on Cfg status
              -edit_update => [$edit_win => 'update'],
              -main_status => [$main_win => '_status'],
              -week_update => [$week_win => 'update'],
              -about_popup => \&about_popup,
             );


$tbFile->getRef('-plugin') ->
    configure(
              -earlier       => $earlier,
              -main_win      => $main_win,
              -week_win      => $week_win,
              -edit_win      => $edit_win,
              -year_win      => $year_win,
              -sett_win      => $settings,
             );

# Tick clock once to initialize values and let things show up
$clock -> tick();

# Get start time and date
my $time = $clock->getTime();
my $date = $clock->getDate();

# Load files and initiate session
$tbFile->load();
$tbFile->init($date, $time, $tool_info{VERSION});

# Set starttime
$tbFile->start($date, $time, $args, $tool_info{version});

# Setup main GUI
$main_win->display();

# Initiate plugins
$tbFile->getRef('-plugin')->loadPlugins();
$tbFile->getRef('-plugin')->registerPlugins();

#----------------------------------------------------------------------------
#
# main loop
#

$earlier->build($tbFile->getRef('-times'));

# Show about if new version is used
my $session = $tbFile->getRef('-session');
if ($session->get('last_version') ne $tool_info{VERSION}) {
  about_popup($main_win->getWin());
  $session->set('last_version', $tool_info{VERSION});
} # if #

# Show session lock popup if session is locked
$tbFile->checkSessionLock([$main_win, 'showLocked']);


{
  local($SIG{__WARN__}) = \&warning_handler;
  # Send errors and warnings to log
  $tbFile->error_warning($error, $warning);

  MainLoop;
}

__END__
#############################################################################
#
# Manual page section
#
#############################################################################

=pod

=head1 NAME

tidbox.pl - Tidbox, time registering tool

=head1 SYNOPSIS

C<tidbox.pl [ -help | -man ] [ -directory NAME ]>

    Options:
      -directory NAME  Name of tidbox directory
      -help            Brief help message
      -man             Full manual page

=head1 DESCRIPTION

B<Tidbox> is a tool for work time registration.
Files are stored differently depending of platform.

For computers where a backed up storage not is available at all times,
such as a laptop computer, a backup directory is used.

=over 4

=item B<Unix>

On B<Unix> and Unix like platforms the default directory is named B<.tidbox>
and located in your home directory. That is B<$HOME/.tidbox>.

=item B<Windows>

On B<Windows> the default directory is named B<Tidbox>
and located in your B<Application data> directory as defined by Windows.
There is no default backup directory.
Select a backup directory in settings.
Suggestion is to use a cloud storage directory managed by Google Drive,
OneDrive, Dropbox, etcetera.

=back

Backup directory is defined and enabled in settings.

=head1 OPTIONS

=over 4

=item B<-directory> NAME

Full path to B<NAME> of the directory were to store all Tidbox files in.
Use this if you need to override the default directory.

=item B<-help>

Brief help message.

=item B<-man>

Manual page.

=back

=head1 EXAMPLES

Start Tidbox:

  tidbox.pl

=head1 KNOWN ERRORS

The tool is in Swedish.

On Windows the environment variable B<APPDATA> is used to find out
the B<Application data> directory.
This might not work in future Windows versions.

=head1 SEE ALSO

About dialog for homepage.

=head1 AUTHOR

Roland Vallgren

=head1 COPYRIGHT

This program is copyrighted by Roland Vallgren
All Rights Reserved.

    Copyright (c) 2018-12-12 Roland Vallgren All rights reserved
    This program is free software. It may be used, redistributed
    and/or modified under the same terms as Perl itself


=cut

