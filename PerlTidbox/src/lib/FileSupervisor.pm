#
package FileSupervisor;
#
#   Document: Handle all files
#   Version:  2.0   Created: 2013-05-18 20:00
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: FileSupervisor.pmx
#

my $VERSION = '2.0';

# History information:
#
# 1.0  2011-02-25  Roland Vallgren
#      First issue.
# 1.1  2012-06-04  Roland Vallgren
#      not_set_start => start_operation :  none, workday, event, end pause
# 2.0  2012-09-10  Roland Vallgren
#      Added session lock
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent TidBase;

use strict;
use warnings;
use integer;

use Version qw(register_starttime);

use Log;
use Lock;
use Configuration;
use Session;
use Times;
use EventCfg;
use Supervision;
use Archive;

# Register version information
{
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => '2013-05-18',
                  );
}

#############################################################################
#
# Method section
#
#############################################################################
#

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create object and create all file objects
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($args) = @_;

  my $order = [ qw(-lock -cfg -session -event_cfg -supervision -times) ];
  my $extra = [ qw(-archive) ];

  my $files = {
              -lock        => new Lock(),

              -log         => new Log(),

              -cfg         => new Configuration($args),

              -session     => new Session($args),

              -event_cfg   => new EventCfg(),

              -supervision => new Supervision(),

              -times       => new Times(),

              -archive     => new Archive(),

             };
  my $self = {
              order => $order,
              extra => $extra,
              files => $files,
             };
  bless($self, $class);
  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      configure
#
# Description: Setup needed references
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub configure($%) {
  # parameters
  my $self = shift;
  my (%args) = @_;


  $self->SUPER::configure(%args);

  my $files = $self->{files};

  $files->{-cfg} ->
      configure(
                -cfg         => $files->{-cfg},
                -lock        => $files->{-lock},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-event_cfg} ->
      configure(
                -cfg         => $files->{-cfg},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-log} ->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-lock} ->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-session} ->
      configure(
                -cfg         => $files->{-cfg},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-times} ->
      configure(
                -cfg         => $files->{-cfg},
                -session     => $files->{-session},
                -calculate   => $args{-calculate},
                -edit        => $args{-edit},
                -clock       => $args{-clock},
                -log         => $files->{-log},
                -error_popup => $args{-error_popup},
               );

  $files->{-supervision} ->
      configure(
                -cfg         => $files->{-cfg},
                -times       => $files->{-times},
                -log         => $files->{-log},
                -event_cfg   => $files->{-event_cfg},
                -clock       => $args{-clock},
                -calculate   => $args{-calculate},
                -earlier     => $args{-earlier},
                -error_popup => $args{-error_popup},
               );

  $files->{-archive} ->
      configure(
                -cfg         => $files->{-cfg},
                -times       => $files->{-times},
                -log         => $files->{-log},
                -event_cfg   => $files->{-event_cfg},
                -calculate   => $args{-calculate},
                -clock       => $args{-clock},
                -error_popup => $args{-error_popup},
               );

  return 0;
} # Method configure

#----------------------------------------------------------------------------
#
# Method:      load
#
# Description: Load files
#
# Arguments:
#  - Object reference
#  - Date
#  - Time
# Returns:
#  -

sub load($$$) {
  # parameters
  my $self = shift;
  my ($date, $time) = @_;

  my $files = $self->{files};

  # Import earlier version tidbox files if they exists
  my $imported;
  unless ($files->{-cfg}->Exists()) {
    eval {
           require Import_E;
         };
    unless ($@) {
      $imported =
        Import_E::import_query($files->{-cfg},
                               $files->{-event_cfg},
                               $files->{-supervision},
                               $files->{-times},
                               $self->{-calculate},
                               $files->{-archive},
                               $self->{-error_popup},
                              );
      exit 0
          unless (defined($imported));
    } # unless #

  } # unless #

  # Read old data for configuration and times, do not read archive
  unless ($imported) {
    for my $k (@{$self->{order}}) {
      $files->{$k}->load();
    } # for #
  } # unless #

  # Lock session
  $files->{-lock}->lock($date, $time);

  # Start auto saving for files and register impacted
  for my $k (@{$self->{order}}, @{$self->{extra}}) {
    $files->{$k}->startAuto();
    $files->{-cfg}->impacted($files->{$k});
  } # for #

  return 0;
} # Method load

#----------------------------------------------------------------------------
#
# Method:      getRef
#
# Description: Get reference to a file object
#
# Arguments:
#  - Object reference
#  - Name of file object
# Returns:
#  Reference to the object

sub getRef($$) {
  # parameters
  my $self = shift;
  my ($name) = @_;

  return $self->{files}{$name};
} # Method getRef

#----------------------------------------------------------------------------
#
# Method:      start
#
# Description: Set start time and date of this session
#
# Arguments:
#  - Object reference
#  - Date
#  - Time
#  - Call string of the program
# Returns:
#  -

sub start($$$$) {
  # parameters
  my $self = shift;
  my ($date, $time, $args) = @_;


  my $files = $self->{files};

  # Start logging
  $files->{-log}->start();
  $files->{-log}->log('------ Started tidbox', '------');
  $files->{-log}->log('Command', $args->{-call_string}, @{$args->{-argv}});

  # Set start time
  Version->register_starttime($date, $time);

  $files->{-session}->start($date, $time);

  $files->{-times}->startSession($date, $time, $files->{-event_cfg})
      unless ($files->{-cfg}->isLocked($date));

  Version->register_locked_session($files->{-lock}->get());


  # Setup supervision
  $files->{-supervision}->setup();


  return 0;
} # Method start

#----------------------------------------------------------------------------
#
# Method:      error_warning
#
# Description: Start loggin errors and warnings
#
# Arguments:
#  0 - Object reference
#  1 - Reference to error hash
#  2 - Reference to warning hash
# Returns:
#  -

sub error_warning($$$) {
  # parameters
  my $self = shift;

  my $log = $self->{files}{-log};
  for my $ref (@_) {
    $ref->{handler} = $log;
    push @{$self->{error_warning}}, $ref;
    for my $l (@{$ref->{list}}) {
      $log->log($ref->{prefix}, $l);
    } # for #

  } # for #
  
  return 0;
} # Method error_warning

#----------------------------------------------------------------------------
#
# Method:      end
#
# Description: Set end time and date of this session
#              Save all files
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Callback to display information about save
# Returns:
#  -

sub end($;$) {
  # parameters
  my $self = shift;
  my ($message) = @_;


  my $files = $self->{files};

  # Set end time
  $files->{-session}->end();

  # Save not saved data for configuration and times
  for my $r (values(%{$files})) {
    $self->callback($message);
    $r->save();
  } # for #

  # Turn of logging of errors and warnings
  for my $ref (@{$self->{error_warning}}) {
    $ref->{handler} = undef;
  } # for #


  $self->{files}{-log}->log('------ Ended tidbox ------');

  # Unlock session
  $files->{-lock}->unlock();
  


  return 0;
} # Method end

1;
__END__
