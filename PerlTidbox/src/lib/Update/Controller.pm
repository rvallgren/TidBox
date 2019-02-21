#
package Update::Controller;
#
#   Document: Perform periodic check for new versions
#   Version:  1.0   Created: 2019-02-21 11:49
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Controller.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2019-02-21';

# History information:
#
# 1.0  2019-01-25  Roland Vallgren
#      First issue, Controll part moved from Update.pm.
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use integer;

use Update::Install;

# Register version information
{
  use TidVersion qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}

#----------------------------------------------------------------------------
#
# Constants
#

use constant {
  # States
  ST_CHECK_RATE_LIMIT             => 'CHECK_RATE_LIMIT',
  ST_CHECK_VERSION                => 'CHECK_VERSION',
  ST_CLEANUP_ALL                  => 'CLEANUP_ALL',
  ST_DOWNLOAD                     => 'DOWNLOAD',
  ST_EXTRACT_ARCHIVE              => 'EXTRACT_ARCHIVE',
  ST_GET_OUR_VERSION              => 'GET_OUR_VERSION',
  ST_GET_RELEASES                 => 'GET_RELEASES',
  ST_INIT                         => 'INIT',
  ST_PREPARE_INSTALL_DIRECTORY    => 'PREPARE_INSTALL_DIRECTORY',
  ST_FIND_TIDBOX_AND_LIB          => 'FIND_TIDBOX_AND_LIB',
  ST_WAIT_FOR_INSTALL             => 'WAIT_FOR_INSTALL',


  # Wait 5 minutes before first attempt to check is done
  TMR_FIRST_CHECK_DELAY =>      5,
  TMR_ONE_HOUR          =>     60,
  TMR_ONE_MINUTE        =>      1,
  TMR_UNTIL_TOMORROW    =>  24*60,
};


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
# Description: Create update object
#
# Arguments:
#  - Object prototype
#  - Reference to call hash
# Returns:
#  Object reference

sub new($$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($args, $erefs) = @_ ;
  my $self =
   {
    args       => $args,
    erefs      => $erefs,
    installer  => undef,      # Reference to Installer object
    minutes    => 0,          # When true the minute signal is requested
    restart    => -1,         # Default is to not install a new version

    # State machine handling
    state      => undef,      # Next operation to perform
    timer      => undef,      # Number of minutes until next step is executed
    queue      => undef,      # Queued operations and timers to be performed

   };
  bless($self, $class);
  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      queueSessionState
#
# Description: Add a state to the end of the queue
#
# Arguments:
#  - Object reference

# Returns:
#  -

sub queueSessionState($) {
  # parameters
  my $self = shift;
  my (@refs) = @_;

  for my $r (@refs) {
    unshift(@{$self->{queue}}, $r);
  } # for #
  return 0;
} # Method queueSessionState

#----------------------------------------------------------------------------
#
# Method:      pushSessionState
#
# Description: Push new entries to the session state queue
#
# Arguments:
#  - Object reference
#  Hash state to push
# Returns:
#  -

sub pushSessionState($%) {
  # parameters
  my $self = shift;
  my (%args) = @_;


  unshift(@{$self->{queue}},
       {
         state => $self->{state} ,
         timer => $self->{timer} ,
       }
      );

  $self->{state} = $args{state};
  $self->{timer} = $args{timer};

  return 0;
} # Method pushSessionState

#----------------------------------------------------------------------------
#
# Method:      popSessionState
#
# Description: Return top element of state queue
#
# Arguments:
#  - Object reference
# Returns:
#  Reference to state
#  undef if queue is empty
#  TODO Should it be get releases

sub popSessionState($) {
  # parameters
  my $self = shift;

  $self->setSessionState(shift(@{$self->{queue}}));
  
  return 0;
} # Method popSessionState

#----------------------------------------------------------------------------
#
# Method:      setSessionState
#
# Description: Set session state, get from head of queue
#              If no arguments provided, Start from get releases
#
# Arguments:
#  - Object reference
#  - Reference to state and timer to set
#  ... References to hashes for coming states
# Returns:
#  -

sub setSessionState($$@) {
  # parameters
  my $self = shift;
  my ($ref, @later_refs) = @_;

#  print __PACKAGE__, "::setSessionState: %A \"$%A\"\n" if $verbose;
#  print (caller(0))[3], ": %A \"$%A\"\n" if $verbose;

  if ($ref) {
    $self->{state} = $ref->{state};
    $self->{timer} = $ref->{timer};
    $self->queueSessionState(@later_refs)
        if (@later_refs);
  } else {
    # Always start over if next is not initialized
    $self->queueCheckVersionCycle();

  } # if #

  return 0;
} # Method setSessionState

#----------------------------------------------------------------------------
#
# Method:      queueCheckVersionCycle
#
# Description: Queue a complete check cycle in state queue
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  timer => Timeout for check rate limit, default is one minute
#  state => Prepend with a complete state
# Returns:
#  -

sub queueCheckVersionCycle($;%) {
  # parameters
  my $self = shift;
  my (%args) = @_;


  @{$self->{queue}} =
    (
      {
       state => ST_GET_RELEASES     ,
       timer => TMR_ONE_MINUTE      ,
      },
      {
       state => ST_CHECK_VERSION    ,
       timer => TMR_ONE_MINUTE      ,
      },
    );

  my $timer = $args{timer} || TMR_ONE_MINUTE;

  if ($args{state}) {
    unshift(@{$self->{queue}},
          {
           state => ST_CHECK_RATE_LIMIT ,
           timer => $timer              ,
          });

    $self->{state} = $args{state} ;
    $self->{timer} = TMR_ONE_MINUTE ;

  } else {
    $self->{state} = ST_CHECK_RATE_LIMIT ;
    $self->{timer} = $timer              ;

  } # if #

  return 0;
} # Method queueCheckVersionCycle

#----------------------------------------------------------------------------
#
# Method:      queueDownloadNewVersionCycle
#
# Description: Queue a complete check cycle in state queue
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  timer => Timeout for check rate limit, default is one minute
# Returns:
#  -

sub queueDownloadNewVersionCycle($;%) {
  # parameters
  my $self = shift;
  my (%args) = @_;


  $self->{state} = ST_CLEANUP_ALL                 ;
  $self->{timer} = $args{timer} || TMR_ONE_MINUTE ;

  @{$self->{queue}} =
    (
      {
       state => ST_PREPARE_INSTALL_DIRECTORY ,
       timer => TMR_ONE_MINUTE               ,
      },
      {
       state => ST_DOWNLOAD    ,
       timer => TMR_ONE_MINUTE ,
      },
      {
       state => ST_EXTRACT_ARCHIVE ,
       timer => TMR_ONE_MINUTE     ,
      },
      {
       state => ST_FIND_TIDBOX_AND_LIB ,
       timer => TMR_ONE_MINUTE         ,
      },
      {
       state => ST_WAIT_FOR_INSTALL ,
       timer => TMR_UNTIL_TOMORROW  ,
      },
    );

  return 0;
} # Method queueDownloadNewVersionCycle

#----------------------------------------------------------------------------
#
# Method:      queueCleanupAndStartAllOver
#
# Description: Remove zipfile and directories and
#              queue a complete check cycle in state queue
#              If a timer is specified, cleanup will be delayed until then
#              If a state is specified, this will be used instead
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  timer => Timeout before cleanup
#  state => Prepend with a complete state
# Returns:
#  -

sub queueCleanupAndStartAllOver($;%) {
  # parameters
  my $self = shift;
  my (%args) = @_;


  $self->queueCheckVersionCycle();

  my $state = $args{state} || ST_CLEANUP_ALL;
  my $timer = $args{timer} || TMR_ONE_MINUTE;

  $self->pushSessionState(
                          state => $state ,
                          timer => $timer ,
                         );

  return 0;
} # Method queueCleanupAndStartAllOver

#----------------------------------------------------------------------------
#
# Method:      queueCleanupAndReset
#
# Description: Queue cleanup all and then init
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub queueCleanupAndReset($) {
  # parameters
  my $self = shift;


  $self->{state} = ST_CLEANUP_ALL ;
  $self->{timer} = TMR_ONE_MINUTE ;

  @{$self->{queue}} =
    (
      {
       state => ST_INIT               ,
       timer => TMR_FIRST_CHECK_DELAY ,
      },
    );

  return 0;
} # Method queueCleanupAndReset

#----------------------------------------------------------------------------
#
# Method:      timeoutSignaled
#
# Description: If timeout perform pending actions
#              To be called once a minute by timer or clock
#              Dispatch qued update jobs
#
# Arguments:
#  - Object reference
# Returns:
#  State that was executed

sub timeoutSignaled($) {
  # parameters
  my $self = shift;


#  TODO Check configuration and change state if impacted

  my $state = $self->{state};

  if ($state eq ST_CHECK_RATE_LIMIT) {
    # Check rate limit, wait until we are allowed in
    my $systime_timeout = $self->{installer}->getRateLimit();

    if (not defined($systime_timeout)) {
      # We did not get a rate limit, wait a while and try again
      $self->{timer} = TMR_ONE_HOUR;

    } elsif ($systime_timeout > 0) {
      # Rate limit was in effect, wait until new period is ready for us
      # TODO Manual update: don't wait random minutes, try as fast as possible
      $self->{timer} = 
           int(($systime_timeout - $self->{erefs}{-clock}->getSystime()) / 60)
         + $self->{random_minute};

    } else {
      # Set state from head of queue
      $self->popSessionState();

    } # if #


  } elsif ($state eq ST_GET_RELEASES) {
    # Get available releases from Github
    my $cnt = $self->{installer}->getReleases();

    if (not defined($cnt)) {
      # We failed to get any releases, Restart check for releases
      $self->queueCheckVersionCycle();

    } elsif ($cnt > 0) {
      # Releases are available, check if a new is available
      $self->popSessionState();

    } else {
      # TODO This should not happen before getReleases filter older versions
      # We did not get any releases, restart check tomorrow
      $self->queueCleanupAndStartAllOver(timer => TMR_UNTIL_TOMORROW);

    } # if #


  } elsif ($state eq ST_CHECK_VERSION) {
    # Check if we have latest version, otherwise trigger an update
    my $newVersion = $self->{installer}->checkForNewVersion();
    if (not defined($newVersion)) {
      # We already have latest version, schedule next check tomorrow
      $self->queueCleanupAndStartAllOver(timer => TMR_UNTIL_TOMORROW);

    } else {
      # We got a new version, schedule download
      $self->{new_version} = $newVersion;
      $self->queueDownloadNewVersionCycle();

    } # if #



  } elsif ($state eq ST_PREPARE_INSTALL_DIRECTORY) {
    # Prepare installation directory, cleanup if not expected contents is found
    my $prepared = $self->{installer}->prepareInstallDirectory();
    if ($prepared < 0) {
      # Can not create one of the directories, cleanup start over tomorrow
      $self->queueCleanupAndStartAllOver(timer => TMR_UNTIL_TOMORROW);

    } elsif ($prepared > 0) {
      # Directories exists, initiate cleanup and start all over
      $self->queueCleanupAndStartAllOver();

    } else {
      # Directories are created, download archive
      $self->popSessionState();

    } # if #


  } elsif ($state eq ST_DOWNLOAD) {
    # Download released ZIP from GitHub to a temporary file
    my $filename = $self->{installer}->downloadNewVersion($self->{new_version});
    if (not defined($filename)) {
      # Download failed, cleanup and start all over
      $self->queueCleanupAndStartAllOver();

    } else {
      # Downloaded OK, schedule extraction
      $self->popSessionState();

    } # if #


  } elsif ($state eq ST_EXTRACT_ARCHIVE) {
    # Extract archive
    my $ok = $self->{installer}->extractArchive();
    if (not defined($ok)) {
      # Extract failed, cleanup and start from scratch
      $self->queueCleanupAndStartAllOver();

    } else {
      # Extraction OK, schedule prepare install file
      $self->popSessionState();

    } # if #


  } elsif ($state eq ST_FIND_TIDBOX_AND_LIB) {
    # Find Tidbox and lib in extracted directory
    my $tb = $self->{installer}->findExtractedTidbox();
    if (not $tb) {
      # Tidbox directory not found in extracted files, cleanup and restart
      $self->queueCleanupAndStartAllOver(timer => TMR_UNTIL_TOMORROW);

    } else {
      # TODO Ask user for a replace of Tidbox
      $self->callback($self->{newVersionCallback}, $self->{new_version});
      $self->popSessionState();

    } # if #


  } elsif ($state eq ST_CLEANUP_ALL) {
    # Remove all: archive, extracted and old
    $self->callback($self->{newVersionCallback}, undef);
    my $res = $self->{installer}->removeDownloadedArchive();
    $res    = $self->{installer}->removeExtractedDirectory();
    $res    = $self->{installer}->removeReplaceTidboxScript();
    $res    = $self->{installer}->removeOldVersion();
    $self->popSessionState();


  } elsif ($state eq ST_WAIT_FOR_INSTALL) {
    # Wait for install of new Tidbox
#    TODO Install not yet impelemented
    # What update handling should we do?
    if ($self->{erefs}{-cfg}->get('check_new_version')) {
      # Do not check for new versions, just wait until we should check
      # TODO When should we check check_new_version setting?
      $self->queueCleanupAndReset();
    } else {
      # Wait until tomorrow, then cleanup and start all over
      $self->queueCleanupAndStartAllOver(timer => TMR_UNTIL_TOMORROW);
    } # if #


  } elsif ($state eq ST_GET_OUR_VERSION) {
    # Initialize the installer and initialize our version
    my $ourVersion = $self->{erefs}{-session}->get('last_version');
    $self->{installer}-> initialize($ourVersion);

    # Initialize first version check cycle
    $self->queueCheckVersionCycle(state => ST_CLEANUP_ALL);


  } elsif ($state eq ST_INIT) {
    # Initialize data and create an Update::Installer

    # What update handling should we do?
    if ($self->{erefs}{-cfg}->get('check_new_version')) {
      # Do not check for new versions, just wait until we should check
      $self->{timer} = TMR_FIRST_CHECK_DELAY;

    } else {
      # Pseudo random to distribute load and at least one minute
      $self->{random_minute} =
            int($self->{erefs}{-clock}->getMinute() / 10) + 1;
      $self->{erefs}{-log}->
         log('Update initialized with random minute:', $self->{random_minute});

      # Create an installer instace
      $self->{installer} = Update::Install->new($self->{args}, $self->{erefs})
          unless ($self->{installer});

      # Next get our version
      $self->{state} = ST_GET_OUR_VERSION;
      $self->{timer} = TMR_ONE_MINUTE;

    } # if #


  } else {
    # Unknown state, this should not happen, restart check
    warn "State $state is invalid";
    # Start over to reset this
    $self->queueCheckVersionCycle(timer => TMR_ONE_HOUR);

    
  } # if #

  # Set timeout for next run

  # TODO Do we need a check of which timers are running?
  # TODO Do we need an hour signal to check that there is a timer running

  if (($self->{state} eq ST_CHECK_RATE_LIMIT) or
      ($self->{state} eq ST_GET_RELEASES    ) or
      ($self->{state} eq ST_DOWNLOAD        ) or
      ($self->{state} eq ST_EXTRACT_ARCHIVE )
     ) {
    # Do actions that takes several seconds 30 seconds after minute change
    my $seconds = $self->{erefs}{-clock}->getSecond;
    my $timeout = $self->{timer} * 60 + 30 - $seconds;
    $timeout += 60
        if ($timeout < 60);
    $self->{erefs}{-clock}->
                 timeout(-second => $timeout,
                         -callback => [$self => 'timeoutSignaled']);
  } else {
    $self->{erefs}{-clock}->
                 timeout(-minute => $self->{timer},
                         -callback => [$self => 'timeoutSignaled']);
  } # if #


  return $state;
} # Method timeoutSignaled

#----------------------------------------------------------------------------
#
# Method:      setNewVersionCallback
#
# Description: Show when a new version is ready to be installed
#
# Arguments:
#  - Object reference
#  - Callback
# Returns:
#  -

sub setNewVersionCallback($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  $self->{newVersionCallback} = $ref;
  return 0;
} # Method setNewVersionCallback

#----------------------------------------------------------------------------
#
# Method:      setRestart
#
# Description: Set how a new version should be handled
#                 -1  = skip change
#                  0  = Only install
#                  1  = Install and restart
#                Default is to skip
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - State: 
# Returns:
#  -

sub setRestart($;$) {
  # parameters
  my $self = shift;
  my ($state) = @_;

  $state = -1
      unless (defined($state));
  $self->{restart} = $state;

  return 0;
} # Method setRestart

#----------------------------------------------------------------------------
#
# Method:      getReplaceScript
#
# Description: Return replace tidbox script
#
# Arguments:
#  - Object reference
# Returns:
#  - Full path to script

sub getReplaceScript($) {
  # parameters
  my $self = shift;


  return undef
      unless ($self->{installer});

# TODO check_new_version  How to check for new versions of Tidbox
#   0:  Look for and download updates and install it on exit
#   1:  Restart Tidbox when a new version is installed
#   2:  Automatic install when new version is detected
#   3:  Automatic install while no work
#   4:  Automatic check in background, ask user for install
#   5:  Only search for and update on user request
#   6:  No search for updates
#     3:  Automatic download and prepare, ask user for install

  return undef
      if ($self->{erefs}{-cfg}->get('check_new_version') >= 6);

  return undef
      if ($self->{restart} < 0);

  return $self->{installer}->prepareReplaceTidboxScript($self->{restart});
} # Method getReplaceScript

#----------------------------------------------------------------------------
#
# Method:      setup
#
# Description: Get our version
#              Start timer for check of releases
#                First attempt in five minutes
#                Later attemps, once every 24 hours
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub setup($) {
  # parameters
  my $self = shift;


  # Start with initializations
  $self->{state} = ST_INIT;
  $self->{timer} = TMR_FIRST_CHECK_DELAY;

  # Do not request minute signal if already requested
  $self->{erefs}{-clock}->timeout(-minute => $self->{timer},
                                  -callback => [$self => 'timeoutSignaled']);
  return 0;
} # Method setup

1;
__END__
