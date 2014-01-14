#
package Terp;
#
#   Document: Terp export
#   Version:  1.8   Created: 2011-03-13 07:21
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Terp.pmx
#

my $VERSION = '1.8';
my $DATEVER = '2011-03-13';

# History information:
#
# PA1  2006-11-06  Roland Vallgren
#      First issue.
# PA2  2006-11-30  Roland Vallgren
#      Try to check for Terp format and hint about flex if worktime
#      isn't 40 hours
# PA3  2007-02-09  Roland Vallgren
#      Show all problems encountered. Better check of allowed Terp data
# PA4  2007-03-13  Roland Vallgren
#      Handle problems detected during calculation of worktime
#      Relaxed check to allow more time types
# 1.5  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
#      Default week is 40 hours
# 1.6  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Week worktime is fetched from settings
# 1.7  2009-07-08  Roland Vallgren
#      Event match expr is already compiled
#      Warn for fractions of tenths of hours
# 1.8  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent TidBase;

use strict;
use warnings;
use Carp;
use integer;

use FileHandle;
use File::Spec;
use File::Basename;

# Register version information
{
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}

# Constants
use constant EXPORT_CSV => 'export.csv';

# Subroutines
#----------------------------------------------------------------------------
#
# Function:    _formatTime
#
# Description: Format time for Terp hour.tenth. Like '1.5'
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
# Method:      exportTo
#
# Description: Export week to Terp template file
#
# START_TEMPLATE
# Project,Task,Type,Mon,CommentText,Tue,CommentText,Wed,CommentText,Thu,CommentText,Fri,CommentText,Sat,CommentText,Sun,CommentText,END_COLUMN
# 12345,67.89,Vanlig,1.0,,2.0,,3.0,,4.0,,5.0,,,,,
#        ,    ,    ,1.0,,2.0,,3.0,,4.0,,5.0,,6.0,,7.0,
#  , , ,,,,,,,,,,,,,,
#  , , ,,,,,,,,,,,,,,
# STOP_TEMPLATE
#
# Arguments:
#  0 - Object prototype
#  1 - A date in the week to export
#  2 - Event configuration
#  3 - Calculator
#  4 - Configurations
#  5 - Window that asked
# Optional Arguments:
#  5 - Filename to export to
# Returns:
#  undef : The Terp-template was not possible to use
#  0 : No terp file created due to problems
#  1 : Results exported to file

sub exportTo($$$$;$) {
  my ($proto, $date, $event_cfg, $calc, $cfg, $win, $template) = @_;
  my $class = ref($proto) || $proto;
  my $self = {problem => []};


  bless($self, $class);

  # Calculate for all days in week
  my $match_string;
  ($match_string) = $event_cfg -> matchString(1, $date);

  my %week_events;
  my ($weekdays_r) =
       $calc -> weekWorkTimes($date, 1, [$self => 'problem'], \%week_events);

  # Problems detected during calculation
  if (@{$self->{problem}}) {
    $win->{confirm}
       -> popup(
                -title => 'Terp : Problem',
                -text  => ['Problem under beräkningen av av arbetstid',
                           'Ingen fil sparades'],
                -data  => [join("\n", @{$self->{problem}})],
               );
    return 0;
  } # if #

  # Collect some data about the week
  $template = EXPORT_CSV unless $template;
  return undef unless (-f $template);
  $self->{template}   = $template;
  $self->{first_date} = $weekdays_r->[0]{date};
  $self->{last_date}  = $weekdays_r->[6]{date};

  # Find out filename to create: terp_<first-date>_<last-date>.csv
  my ($filename, $directories) = fileparse($template);
  $self->{outfile} =
      File::Spec->catfile($directories ,
            'Terp_' . $self->{first_date} . '_' . $self->{last_date} . '.csv');

  # Open files and copy to area were to insert times

  my $tp = new FileHandle($template, '<');
  unless (defined($tp)) {
    $win->{confirm}
       -> popup(
                -title => 'avbröt Terp',
                -text  => ['Det gick inte att läsa Terp-mallen:',
                           $template,
                           $!],
               );
    return undef;
  } # unless #

  my $fh = new FileHandle($self->{outfile}, '>');
  unless (defined($fh)) {
    $win->{confirm}
       -> popup(
                -title => 'avbröt Terp',
                -text  => ['Det gick inte att öppna fil:',
                           $self->{outfile},
                           $!],
               );
    return undef;
  } # unless #

  my $line;
  # Copy till "START_TEMPLATE"
  while (defined($line = $tp->getline())) {
    $fh->print($line);
    last if ($line =~ /^START_TEMPLATE\s*$/);
  } # while #

  unless (defined($line)) {
    $win->{confirm}
       -> popup(
                -title => 'avbröt Terp',
                -text  => ['Kunde inte hitta start märket Terp-mallen:',
                           $template],
               );
    return undef;
  } # unless #

  # Copy header
  $line = $tp->getline();
  $fh->print($line) if defined($line);

  my $time;
  my $activity = "\n";
  my $not_understood = 0;
  my $fractions = 0;
  my @doubtfull;

  for my $event (sort(keys(%week_events))) {

    push @doubtfull , $event
        unless ($event =~ /^(?:\d+),(?:[\d\.]+),(?:[A-Z][\w \.\/]+ -SE(?:-Overtime)?),/);

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
     $win->{confirm}
       -> popup(
                -title => 'avbröt Terp',
                -text  => ['FEL: Det gick inte att skriva till fil:',
                           $self->{outfile},
                           $!],
               );

  # Any problem detected?
  if (@doubtfull or $not_understood or $other or $fractions) {

    my $t = ['VARNING:', undef];
    my $d = [];

    if (@doubtfull) {
      push @$t, ('Ett antal händelser verkar inte vara för Terp.'."\n".
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

    $win->{confirm}
       -> popup(
                -title => 'Terp : VARNING',
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

  my $week_work_minutes = 60 * $cfg->get('terp_normal_worktime');

  if ($total_time > $week_work_minutes) {
    $win->{confirm}
       -> popup(
                -title => 'Terp : Tips',
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
    $win->{confirm}
       -> popup(
                -title => 'Terp : Tips',
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
  $win->{confirm}
     -> popup(
              -title => 'Terp resultat',
              -text  => ['Skrev veckoarbetstid till:',
                         $self->{outfile}],
             );


  return 1;
} # Method exportTo

1;
__END__
