#
package TbFile::Plugin;
#
#   Document: Tidbox Plugin manager
#   Version:  1.4   Created: 2019-10-04 13:18
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Plugin.pmx
#

my $VERSION = '1.4';
my $DATEVER = '2019-10-04';

# History information:
#
# 1.4  2019-01-25  Roland Vallgren
#      Use TbFile::Util to read directory
#      Removed log->trace
#      Do not fail if a plugin file is missing
# 1.3  2018-12-17  Roland Vallgren
#      Activate a new plugin immediately
# 1.2  2018-11-08  Roland Vallgren
#      Add support for plugin configuration
# 1.1  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
# 1.0  2017-08-25  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base TbFile::Base;

use strict;
use warnings;
use Carp;
use integer;

use FindBin;
use TbFile::Util;

use Scalar::Util qw(blessed weaken);

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

use constant FILENAME  => 'plugin.dat';
use constant FILEKEY   => 'PLUGIN CONFIGURATION';

use constant PLUGIN_DIRECTORY => 'Plugin';

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
        $plugin = {info   => [],
                   cfg    => {},
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
        $plugin->{enable} = 1;

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


  return undef
      unless ($plugin->{enable});

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

  # Add plugin data
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
    $self->_append($fh, $self->{plugins}{$name})
        if (defined($name));
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
# Method:      listPlugins
#
# Description: List plugins available in plugin directory
#
# Arguments:
#  - Object reference
# Returns:
#  - Reference to plugins hash

sub listPlugins($) {
  # parameters
  my $self = shift;

  my $log = $self->{erefs}{-log};

  my $d = File::Spec->catfile(
                              $FindBin::RealBin,
                              'lib'            ,
                              PLUGIN_DIRECTORY ,
                             );

  # Find out perl modules (.pm) files in plugin directory
  my $files = TbFile::Util->readDir($d, qr/\.pm$/);
  unless (defined($files)) {
    # Failed to open directory for reading
    $log->log('PluginConfig: Failed to open', $d, 'for reading');
    return undef;
  } # unless #

  my $plugins;
  for my $f (@{$files}) {
    my $name  = substr($f, 0, -3);
    my $pluginName = PLUGIN_DIRECTORY . '::' . $name;
    $plugins->{$pluginName} =
      {
       name => $name,
       file =>
           File::Spec->catfile(
                               PLUGIN_DIRECTORY ,
                               $f               ,
                              ),
      };
  } # for #

  return $plugins;
} # Method listPlugins

#----------------------------------------------------------------------------
#
# Method:      getCfg
#
# Description: Get Plugin configuration
#
# Arguments:
#  - Object reference
# Returns:
#  Reference to active Plugins

sub getCfg($) {
  # parameters
  my $self = shift;


  my $ref = [];
  for my $plugin (keys(%{$self->{plugins}})) {
    push @{$ref}, $plugin
        if ($self->{plugins}{$plugin}{enable});
  } # for #
  return $ref;
} # Method getCfg

#----------------------------------------------------------------------------
#
# Method:      setCfg
#
# Description: Set new plugin configuration
#
# Arguments:
#  - Object reference
#  - Reference to plugin configuration settings hash
# Returns:
#  -

sub setCfg($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;


  $self->_clear();

  # Enable plugins to be used
  while (my ($key, $val) = each(%{$ref})) {
    $self->add($key, $val)
        if ($val->{enable});
  } # while #

  # Disable not used plugins
  for my $plugin (keys(%{$self->{plugins}})) {
    $self->{plugins}{$plugin}{enable} = 0
        unless ($ref->{$plugin}{enable});
  } # for #

  $self->dirty();
  return 0;
} # Method setCfg

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
#  - Plugin hash reference
# Returns:
#  0 Plugin added and enabled
#  1 Plugin was alread enabled

sub add($$$) {
  # parameters
  my $self = shift;
  my ($name, $ref) = @_;


  push @{$self->{plugin_order}}, $name;

  if ($self->{plugins}{$name}) {
    $self->{plugins}{$name}{enable} = 1;
    return 1;
  } # if #

  my $val = {
             name   => $name,
             file   => $ref->{file},
             enable => 1,
            };
  $self->{plugins}{$name} = $val;

  my $tmp = $self->_loadPlugin($val);

  $self->{plugins}{$name}{ref}->registerPlugin()
      if (defined($tmp));

  
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


  my $ref;
  eval {
    require "$val->{file}";
  };
  if ($@) {
    $self->{erefs}{-log}->log('Failed to load "', $val->{file}, ": ", $@);
    $self->callback($self->{erefs}{-error_popup},
                    'Kan inte öppna plugin-filen: "' . $val->{file} . '"');
    return undef;
  } # if #


  $ref = $val->{name}->new();
  $ref->configure(%{$self->{plugin_args}});
# TODO This does not work with TidBase::configure when {erefs} is used
#  $ref->configure(name => $val->{name});
  $val->{info} = $ref->getPluginInformation();
  $val->{cfg} = $ref->getPluginCfg()
      unless ($val->{cfg});
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

  # Load plugins
  for my $name (@{$p_o}) {
    my $val = $p_r->{$name};
    my $ref = $self->_loadPlugin($val);
    $name = undef
        unless (defined($ref));
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

  for my $name (@{$self->{plugin_order}}) {
    $self->{plugins}{$name}{ref}->registerPlugin()
        if (defined($name));

  } # for #
  return 0;
} # Method registerPlugins

1;
__END__
