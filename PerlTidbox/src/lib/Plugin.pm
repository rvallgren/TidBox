#
package Plugin;
#
#   Document: Tidbox Plugin manager
#   Version:  1.0   Created: 2017-09-26 11:12
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Plugin.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2017-09-26';

# History information:
#
# 1.0  2017-08-25  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base FileBase;

use strict;
use warnings;
use Carp;
use integer;

use Scalar::Util qw(blessed weaken);

# Register version information
{
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}

#----------------------------------------------------------------------------
#
# Constants
#

use constant FILENAME  => 'plugin.dat';
use constant FILEKEY   => 'PLUGIN CONFIGURATION';

my @DEFAULT_ORDER = (
   );

#[PLUGIN INFORMATION]
#MyTime-plugin för att hantera tid registrerad i Tieto MyTime.
#
#[PLUGIN NAME]
#MyTime=Plugins/MyTime.pm
#
#[PLUGIN SETTINGS]
#export_template=C:/Users/vallgrol/Google Drive/MyTime/Export-2017.csv

use constant PLUGIN_INFO      => 'PLUGIN INFORMATION';
use constant PLUGIN_NAME_FILE => 'PLUGIN NAME FILE';
use constant PLUGIN_SETTINGS  => 'PLUGIN SETTINGS';




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
# Description: Create plugin manager object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
              plugins      => {},
              plugin_order => [],
              plugin_args  => {},
            # TODO Ugly trick to use saveDatedSets
              _tmp         => undef,
            # Plugins added in migration
              added        => {},
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  # Set default values
  $self->_clear();

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear plugin data, set default values
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  @{$self->{plugin_order}} = @DEFAULT_ORDER;

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Read plugin configuration data from file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
# Returns:
#  0 if success

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;

  my $p_r = $self->{plugins};
  my $p_o = $self->{plugin_order};
  my $plugin;

  while (defined(my $line = $fh->getline())) {

    $line =~ s/\s+$//;

    if ($line =~ /^\[([-.\w\s]+)\]\s*$/) {
      if ($1 eq PLUGIN_INFO) {

        # New plugin
        $plugin = {info => [],
                   cfg  => {}
                  };
        my $r = $plugin->{info};

        # Load plugin information
        while (defined($line = $fh->getline())) {
          last
              if ($line =~ /^\s+$/);
          $line =~ s/\s+$//;
          push @$r, $line;
        } # while #
        carp "No plugin information found"
            unless (@$r > 0);

      } elsif ($1 eq PLUGIN_NAME_FILE) {
        # Load plugin name and file
        while (defined($line = $fh->getline())) {
          if ($line =~ /^(\w+\:+\w+)=(.+?)\s*$/) {
            $plugin->{name} = $1;
            $plugin->{file} = $2;
            $p_r->{$1} = $plugin;
            push @{$p_o}, $1;
          } else {
            last;
          } # if #

        } # while #
        warn "Plugin name or file name missing $."
            unless (exists($plugin->{file}));
        
      } elsif ($1 eq PLUGIN_SETTINGS) {
        # Load PLUGIN SETTINGS
        $self->{_tmp} = $plugin->{cfg};
        $self->loadDatedSets($fh, '_tmp');
        $self->{_tmp} = undef;

      } else {
        carp "Unknown type in plugin configuration: $1";

      } # if #


    } # if #

  } # while #

  $self->{_tmp} = undef;

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _append
#
# Description: Add plugin information, name, file and settings to file
#
# Arguments:
#  - Object reference
#  - Filhandle
#  - Reference to plugin hash to add
# Returns:
#  -

sub _append($$$) {
  # parameters
  my $self = shift;
  my ($fh, $plugin) = @_;


  # Add plugin information
  $fh->print("\n" .
             '['. PLUGIN_INFO. ']' . "\n");
  for my $line (@{$plugin->{info}}) {
    $fh->print($line, "\n");
  } # for #

  # Add plugin name and filename
  $fh->print("\n" .
             '['. PLUGIN_NAME_FILE. ']' . "\n");
  $fh->print($plugin->{name} , '=', $plugin->{file}, "\n" );

  # Add times data
  $fh->print("\n" .
             '['. PLUGIN_SETTINGS. ']' . "\n");
  # TODO Ugly trick to use method saveDatedSets
  $self->{_tmp} = $plugin->{cfg};
  $self->saveDatedSets($fh, '_tmp');
  $self->{_tmp} = undef;

  return 0;
} # Method _append

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save plugin configuration
#
# Arguments:
#  - Object reference
#  - Filhandle
# Returns:
#  -

sub _save($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  for my $name (@{$self->{plugin_order}}) {
    $self->_append($fh, $self->{plugins}{$name});
  } # for #

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      get
#
# Description: Get a plugin setting or all if no key is given
#
# Arguments:
#  - Object reference
#  - Plugin name
# Optional Arguments:
#  List of settings
# Returns:
#  Value of setting or hash

sub get($$@) {
  # parameters
  my $self = shift;
  my $name = shift;


  carp "Plugin ", $name, " does not exist"
      unless (exists($self->{plugins}{$name}));

  return $self->{plugins}{$name}{cfg}{shift()}
      unless wantarray();

  return %{$self->{plugins}{$name}{cfg}}
      unless @_;

  my $cfg = $self->{plugins}{$name}{cfg};
  my %copy;
  for my $k (@_) {
    $copy{$k} = $cfg->{$k};
  } # for #
  return %copy;
} # Method get

#----------------------------------------------------------------------------
#
# Method:      put
#
# Description: Put a plugins configuration settings, that is replace
#
# Arguments:
#  - Object reference
#  - Plugin name
#  Hash with settings to put
# Returns:
#  -

sub put($$%) {
  # parameters
  my $self = shift;
  my ($name, %hash) = @_;


  carp "Plugin ", $name, " does not exist"
      unless (exists($self->{plugins}{$name}));

  my $ref = $self->{plugins}{$name}{cfg};
  %$ref = ();
  while (my ($key, $val) = each(%hash)) {
    $ref->{$key} = $val;
  } # while #
  $self->dirty();

  return 0;
} # Method put

#----------------------------------------------------------------------------
#
# Method:      set
#
# Description: Set a plugins configuration
#
# Arguments:
#  - Object reference
#  - Plugin name
#  Hash with settings to set
# Returns:
#  -

sub set($$%) {
  # parameters
  my $self = shift;
  my ($name, %hash) = @_;


  my $ref;
  if (exists($self->{plugins}{$name})) {
    $ref = $self->{plugins}{$name}{cfg}
  } elsif (exists($self->{added}{$name})) {
    $ref = $self->{added}{$name}{cfg}
  } else {
    carp "Plugin ", $name, " does not exist";
  } # if #

  while (my ($key, $val) = each(%hash)) {
    $ref->{$key} = $val;
  } # while #
  $self->dirty();

  return 0;
} # Method set

#----------------------------------------------------------------------------
#
# Method:      add
#
# Description: Add a plugin
#              TODO Make this generic so that the names can be detected or
#                   fetched from the plugin.
#
# Arguments:
#  - Object reference
#  - Plugin name
#  - Plugin filename
# Returns:
#  -

sub add($$$) {
  # parameters
  my $self = shift;
  my ($name, $filename) = @_;

  if ($self->{plugins}{$name}) {
    croak "Plugin ", $name, " already defined\n";
    return 1;
  } # if #

  $self->{added}{$name} = {
                           name => $name,
                           file => $filename,
                           cfg  => {},
                          };
  $self->dirty();
  
  return 0;
} # Method add

# TODO Remove a plugin
#----------------------------------------------------------------------------
#
# Method:      configure
#
# Description: Setup needed references and references needed by plugins
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

  while (my ($key, $val) = each(%args)) {
    $self->{plugin_args}{$key} = $val;
    # To improve performance when Tidbox is shut down,
    # weaken references to other objects
    weaken($self->{plugin_args}{$key})
        if (blessed($val));
  } # while #

  return 0;
} # Method configure

#----------------------------------------------------------------------------
#
# Method:      _loadPlugin
#
# Description: Load one plugin
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub _loadPlugin($$) {
  # parameters
  my $self = shift;
  my ($val) = @_;


  require "$val->{file}";
  my $ref = $val->{name}->new();
  $ref->configure(%{$self->{plugin_args}});
  $ref->configure(name => $val->{name});
  $val->{ref} = $ref;

  return $ref;
} # Method _loadPlugin

#----------------------------------------------------------------------------
#
# Method:      loadPlugins
#
# Description: Load plugins, create plugin instances and set needed references
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub loadPlugins($) {
  # parameters
  my $self = shift;


  my $p_r = $self->{plugins};
  my $p_o = $self->{plugin_order};
  my $p_a = $self->{added};

  for my $name (@{$p_o}) {
    my $val = $p_r->{$name};
    my $ref = $self->_loadPlugin($val);
  } # for #

  for my $name (keys(%{$self->{added}})) {
    my $val = $self->{added}{$name};
    my $ref = $self->_loadPlugin($val);
    $val->{info} = $ref->getPluginInformation();

    $p_r->{$name} = $val;
    push @{$p_o}, $name;
    $p_a->{$name} = undef;
  } # for #

  return 0;
} # Method loadPlugins

#----------------------------------------------------------------------------
#
# Method:      registerPlugins
#
# Description: Register plugins in available modules
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub registerPlugins($) {
  # parameters
  my $self = shift;
  my () = @_;

  for my $name (@{$self->{plugin_order}}) {
    $self->{plugins}{$name}{ref}->registerPlugin();
  } # for #
  return 0;
} # Method registerPlugins

1;
__END__
