#
package MigrateVersion;
#
#   Document: Migrate data between tidbox versions
#   Version:  1.0   Created: 2017-09-26 11:05
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: MigrateVersion.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2017-09-26';

# History information:
#
# 1.0  2017-09-18  Roland Vallgren
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
use integer;

# Register version information
{
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
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
# Method:      Configuration
#
# Description: Migrate configuration data
#
# Arguments:
#  - Configuration data class
#  - Plugin 
#  - Log
# Returns:
#  Object reference

sub Configuration($$$) {
  my $self = shift;
  my ($cfg, $plugin, $log) = @_;

  # Setting terp_normal_worktime renamed to ordinary_week_work_time
  if ($cfg->Exists('terp_normal_worktime')) {
    my $tmp = $cfg->get('terp_normal_worktime');
    $cfg->set('ordinary_week_work_time', $tmp);
    $cfg->delete('terp_normal_worktime');
    $log->log('Renamed terp_normal_worktime to ordinary_week_work_time')
        if ($log);
  } # if #

  # Setting terp_template moved to Plugin
  # TODO How should it be moved to Plugin.dat for Tieto users / other users
  if ($cfg->Exists('terp_template')) {
    my $tmp = $cfg->get('terp_template');
    $cfg->delete('terp_template');

    $plugin->add('Plugin::MyTime', 'plugin/MyTime.pm');
    $log->log('Added plugin Plugin::MyTime, plugin/MyTime.pm')
        if ($log);
    $plugin->set('Plugin::MyTime', 'mytime_template', $tmp);
    $log->log('Moved terp_template to Plugin.dat mytime_template')
        if ($log);
    # TODO Inform user through popup (?) that this was done
  } # if #
  return 1;
} # Method Configuration

#----------------------------------------------------------------------------
#
# Method:      MigrateData
#
# Description: Handle changes in data between Tidbox versions
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub MigrateData($%) {
  my $class = shift;
  $class = ref($class) || $class;

  my (%args) = @_;

  my $self = {};
  bless($self, $class);

  
  return $self->Configuration($args{-cfg}, $args{-plugin}, $args{-log});
} # Method MigrateData

1;
__END__
