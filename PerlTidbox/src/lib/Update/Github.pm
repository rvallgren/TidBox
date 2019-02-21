#
package Update::Github;
#
#   Document: Get Tidbox from GitHub
#   Version:  1.0   Created: 2019-02-21 11:50
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Github.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2019-02-21';

# History information:
#
# 1.0  2019-01-25  Roland Vallgren
#      First issue, Github part moved from Update.pm.
#

#----------------------------------------------------------------------------
#
# Setup
#

use strict;
use warnings;
use integer;

use HTTP::Request;
use LWP::UserAgent;
use JSON ();

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
  GITHUB_USER    => 'rvallgren',
  GITHUB_REPO    => 'TidBox',

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
#  - External references
# Returns:
#  Object reference

sub new($$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($erefs) = @_;
  my $self =
   {
    erefs    => $erefs,     # External, log is used

    utils    => {},         # Perl utility objects to be reused in Update

#    rate_limit             # From Github rate_limit

    releases => {},        # Information about available releases
    order    => [],        # Ordered list of releases
   };
  bless($self, $class);
  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      initialize
#
# Description: Initialize
#              - Create LWP user agent
#              - Create JSON instance
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub initialize($) {
  # parameters
  my $self = shift;


  if ($^O eq 'MSWin32') {
    # Add {PERL root}/c/bin to path, Strawberry Perl and Windows
    # Perl can not find SSLeay.dll if not, this error message is returned
    # from LWP::UserAgent
    #     Can't load
    #     'C:/StrawberryPerl5.28.1.1Tk/perl/vendor/lib/auto/Net/SSLeay/SSLeay.xs.dll'
    #     for module Net::SSLeay: load_file:
    #     The specified module could not be found
    #     (LWP::Protocol::https not installed)
    # $^X ==> 'C:\StrawberryPerl5.28.1.1Tk\perl\bin\perl.exe'
    my $perl_exe = $^X;
    if ($perl_exe =~ s/perl\\bin\\w?perl\.exe.*$/c\\bin/) {
      $ENV{PATH} .= ';' . $perl_exe;
    } # if #
  } # if #

  # Create an LWP user agent
  my $ua = LWP::UserAgent->new;
  $ua->agent("Tidbox/0.1 " . $ua->agent);

  $self->{utils} =
     {
      LWPuserAgent  => $ua,
                                # Create a JSON instance
      json          => JSON->new->allow_nonref,
     };


  return $ua;
} # Method initialize

#----------------------------------------------------------------------------
#
# Method:      __getFromGitHub
#
# Description: Get data from GitHub
#
# Arguments:
#  - Object reference
#  - Request URL
# Returns:
#  Reference to decoded JSON data
#  undef if failed

sub _getFromGitHub($$) {
  # parameters
  my $self = shift;
  my ($url) = @_;


  # Setup request
  my $req = HTTP::Request->new(GET => $url);
  $req->header('Accept' => 'application/vnd.github-issue.html+json');

  # Send request
  my $res = $self->{utils}{LWPuserAgent}->request($req);

  # Check the outcome
  unless ( $res->is_success ) {
    # TODO: Improve error handling
    warn "Error from Github: ", $res->decoded_content, "\n", $res->{_msg}, "\n";
    return undef;
  }

  # Decode JSON content
  my $refResult = $self->{utils}{json}->decode( $res->decoded_content );

  unless (ref($refResult)) {
    # TODO: Improve error handling
    warn "ERROR: Failed to decode JSON text\n";
    return undef;
  } # unless #

  return $refResult;
} # Method _getFromGitHub

#----------------------------------------------------------------------------
#
# Method:      getRateLimit
#
# Description: Get GitHub rate limit information
#
#              {
#                "resources": {
#                  "core": {
#                    "limit": 60,
#                    "remaining": 60,
#                    "reset": 1548169811
#                  },
#                  "search": {
#                    "limit": 10,
#                    "remaining": 10,
#                    "reset": 1548166712
#                  },
#                  "graphql": {
#                    "limit": 0,
#                    "remaining": 0,
#                    "reset": 1548170252
#                  }
#                },
#                "rate": {
#                  "limit": 60,
#                  "remaining": 60,
#                  "reset": 1548169811
#                }
#              }
#
# Arguments:
#  - Object reference
# Returns:
#  >0 Rate limiting is on. Value is reset time
#  0 It is OK to access now
#  undef if failed to get information

sub getRateLimit($) {
  # parameters
  my $self = shift;


  # Set up github rate limit URL
  my $rateLimitUrl = 'https://api.github.com/rate_limit';

  my $refResult = $self->_getFromGitHub($rateLimitUrl);

  # check the outcome
  unless ( defined($refResult) ) {
    # TODO: Improve error handling
    warn "Failed to get from github\n";
    return undef;
  }

  unless (ref($refResult) eq 'HASH') {
    # TODO: Improve error handling
    warn "Something is fishy: Data is not an array reference\n";
    return undef;
  } # unless #

   # Save rate_limit not neeeded
   # $self->{rate_limit} = $refResult->{resources}{core};

  # Resources are available
  return 0
      if ($refResult->{resources}{core}{remaining} > 0);
  # Out of resources, return systime when resources are available
  return
    $refResult->{resources}{core}{reset};
} # Method getRateLimit

#----------------------------------------------------------------------------
#
# Method:      getReleases
#
# Description: Get a list of Tidbox releases from Github
#
# Arguments:
#  - Object reference
# Returns:
#  Reference to an array with releases
#  Number of found releases
#    TODO Skip older releases, then return will be available newer releases
#  undef if failed to get information

sub getReleases($) {
  # parameters
  my $self = shift;


  # Set up URL for request
  my $repoReleaseUrl = 'https://api.github.com/repos/' .
                       GITHUB_USER . '/' .
                       GITHUB_REPO . '/releases';

  my $refResult = $self->_getFromGitHub($repoReleaseUrl);

  # check the outcome
  unless ( defined($refResult) ) {
    # TODO: Improve error handling
    warn "Failed to get from github\n";
    return undef;
  }

  unless (ref($refResult) eq 'ARRAY') {
    # TODO: Improve error handling
    warn "ERROR: Data is not an array reference\n";
    return undef;
  } # unless #

  for my $row (@{$refResult}) {
    my $tag_name = $row->{tag_name};
    next
        if (exists($self->{releases}{$tag_name}));

    # TODO Skip releases older than our version

    $self->{releases}{$tag_name} =
     {
      name        => $row->{name},
      created     => $row->{created_at},
      published   => $row->{published_at},
      zipball_url => $row->{zipball_url},
     };
    push @{$self->{order}}, $tag_name;
  } # for #
  return ( [ @{$self->{order}} ] );
} # Method getReleases

#----------------------------------------------------------------------------
#
# Method:      download
#
# Description: Download a new release from GitHub
#
# Arguments:
#  - Object reference
#  - Tag name to download
#  - Filname to store downloaded file in
# Returns:
#  undef if failed to download
#  1 if OK

sub download($$$) {
  # parameters
  my $self = shift;
  my ($tagName, $filename) = @_;


  # Create the request to fetch the released ZIP file
  my $req = HTTP::Request->new(GET => $self->{releases}{$tagName}{zipball_url});
  
  my $res = $self->{utils}{LWPuserAgent}->request($req, $filename);

  return 1
    if ($res->is_success());

  # TODO Better error handling
  warn "Failed to download " . $tagName . ": " . $res->status_line;
  return undef;

} # Method download

#----------------------------------------------------------------------------
#
# Method:      checkVersion
#
# Description: Check if a newer version of Tidox is released
#              TODO Assumed that our version exists
#
# Arguments:
#  - Object reference
#  - Our version
# Returns:
#   0  Our version is latest version
#   New version tag to upgrade to

sub checkVersion($$) {
  # parameters
  my $self = shift;
  my ($ourVersion) = @_;


  # Are we already on latest version?
  return undef
      if (${$self->{order}}[-1] eq $ourVersion);

  # If our version exists and we do not have latest, suggest an upgrade
  return ${$self->{order}}[-1];
  return ${$self->{order}}[-1]
      if (exists($self->{releases}{$ourVersion}));
# TODO How do we handle if our version not exists?
#      Development: Newer than latest
#      Deprecated or removed: Older than latest
#  return 1
#
#  # Our version does not exist
#  return 'Unknown version';
#
  return undef
} # Method checkVersion

1;
__END__
