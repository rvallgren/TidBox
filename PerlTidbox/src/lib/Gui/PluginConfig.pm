#
package Gui::PluginConfig;
#
#   Document: Plugin Configuration class
#   Version:  1.1   Created: 2019-04-04 13:16
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: PluginConfig.pmx
#

my $VERSION = '1.1';
my $DATEVER = '2019-04-04';

# History information:
#
# 1.1  2019-03-05  Roland Vallgren
#      "Insticksmoduler" changed to "Tillägg"
# 1.0  2017-09-19  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#

use v5.10;
use strict;
use warnings;
use Carp;
use integer;

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

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create Plug-in configuration Gui object
#
# Arguments:
#  - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;
  my %args = @_;

  my $edit_r = {
                -area      => $args{-area}    ,
                name       => 'PluginConfig'  ,
               };


  my $self = {
              edit     => $edit_r         ,
              erefs    => $args{erefs}    ,
              -notify  => $args{-modified},
              -invalid => $args{-invalid} ,
             };


  bless($self, $class);

  # Get all plugins in plugin directory
  my $plugins = $self->{erefs}{-plugin}->listPlugins();
  return $self
      unless(defined($plugins));
  $self->{plugins} = $plugins;

  # Set enable status on enabled plugins
  my $ref = $self->{erefs}{-plugin}->getCfg();
  for my $plugin (@{$ref}) {
    $plugins->{$plugin}{enable} = 1;
  } # for #


  ## Area ##
  $edit_r->{list_area} = $edit_r->{-area}
      -> Frame(-bd => '2', -relief => 'raised')
      -> pack(-side => 'top', -expand => '0', -fill => 'both');

  ### Label ###
  $edit_r->{data_lb} = $edit_r->{list_area}
      -> Label(-text => 'Välj tillägg:'
               . ' (OBS: Starta om Tidbox för att de skall aktiveras)')
      -> pack(-side => 'top');

  # Add plugin selection name, checkbox
  for my $p (sort(keys(%{$plugins}))) {
    my $p_a = $p . 'area';
    $edit_r->{$p_a} = $edit_r->{list_area}
        -> Frame(-bd => '2', -relief => 'sunken')
        -> pack(-side => 'top', -expand => '0', -fill => 'both');
    $edit_r->{$p . 'b'} = $edit_r->{$p_a}
      -> Checkbutton(-variable => \$plugins->{$p}{enable},
                     -command  => [ @{$self->{-notify}}, 'plugin_cfg' ],
                    )
      -> pack(-side => 'left');
    $edit_r->{$p . 'L'} = $edit_r->{$p_a}
      -> Label(-text => $p )
      -> pack(-side => 'left');
  } # for #

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _update
#
# Description: Update displayed plugins
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _update($) {
  # parameters
  my $self = shift;


  # TODO Why do we have this method?

  return 0;
} # Method _update

#----------------------------------------------------------------------------
#
# Method:      apply
#
# Description: Apply changes
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub apply($) {
  # parameters
  my $self = shift;


  # Save plugin activation status
  $self->{erefs}{-plugin}->setCfg($self->{plugins});

  return 1;
} # Method apply

#----------------------------------------------------------------------------
#
# Method:      showEdit
#
# Description: Insert values in plugin edit
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub showEdit($) {
  # parameters
  my $self = shift;


  # Copy plugin selection
  my $ref = $self->{erefs}{-plugin}->getCfg();
  my $plugins = {};
  for my $plugin (@{$ref}) {
    $plugins->{$plugin} = 1;
  } # for #
  for my $plugin (keys(%{$self->{plugins}})) {
    if ($plugins->{$plugin}) {
      $self->{plugins}{$plugin}{enable} = 1;
    } else {
      $self->{plugins}{$plugin}{enable} = 0;
    } # if #
  } # for #


  $self->_update();
  return 0;
} # Method showEdit

1;
__END__
