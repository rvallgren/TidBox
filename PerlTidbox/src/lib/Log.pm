#
package Log;
#
#   Document: Log to file
#   Version:  1.3   Created: 2017-09-26 09:41
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Log.pmx
#

my $VERSION = '1.3';
my $DATEVER = '2017-09-26';

# History information:
#
# 1.3  2015-10-08  Roland Vallgren
#      Minor correction.
#      Log should not be rotated when locked
#      Improved handling of log in backup
# 1.2  2012-12-12  Roland Vallgren
#      Perl 5.16
# 1.1  2012-09-05  Roland Vallgren
#      Do not try to rotate backupfile if not used
# 1.0  2011-03-13  Roland Vallgren
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


#----------------------------------------------------------------------------
#
# Constants
#

use constant FILENAME  => 'log.txt';
use constant FILEKEY   => 'LOG';


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
# Description: Create object
#
# Arguments:
#  0 - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = {
              started => 0,
              log     => [],
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear log
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  @{$self->{log}} = ();

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load log, log is never loaded.
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


  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save log data, only used when file does not exist
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
# Returns:
#  -

sub _save($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $fh->print(join(' ', $self->{-clock}->getDate(),
                       $self->{-clock}->getTime(),
                       "Started logging\n"
                 )
            );

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      _append
#
# Description: Append text to file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
#  2 .. - Text to add
# Returns:
#  -

sub _append($$@) {
  # parameters
  my $self = shift;
  my $fh = shift;

  $fh->print(join(' ', @_) , "\n");

  return 0;
} # Method _append

#----------------------------------------------------------------------------
#
# Method:      _rotate
#
# Description: Rotate logs if to big
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub _rotate($) {
  # parameters
  my $self = shift;


  return undef
      if ($self->{-cfg}->isSessionLocked());

  my ($fs, $bs) = (0, 0);
  my ($file, $bak);

  $file = $self->{-cfg}->filename('dir', $self->{-name});
  $fs = (stat(_))[7]
      if (-e $file);
  $bak  = $self->{-cfg}->filename('bak', $self->{-name});
  if ($bak) {
    $bs = (stat(_))[7]
        if (-e $bak);
    $fs = $bs
        if ($bs > $fs);
  } # if #

  return $fs
      unless ($fs > 200000);

  rename $file, $file . '.rotate';
  rename $bak,  $bak  . '.rotate'
      if ($bs);

  unshift @{$self->{log}}, join(' ', $self->{-clock}->getDate(),
                                     $self->{-clock}->getTime(),
                                     'Log rotated'
                               );
  return 0;
} # Method _rotate

#----------------------------------------------------------------------------
#
# Method:      start
#
# Description: Start log creating files that doe not exists
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - if success

sub start($) {
  # parameters
  my $self = shift;


  return undef
      unless (defined($self->_rotate()));

  $self->{loaded} = 1;

  for my $typ ('bak', 'dir') {

    my $file = $self->{-cfg}->filename($typ, $self->{-name});

    next
        unless $file;

    next
        if -e $file;

    $self->dirty(0, $typ);

  } # for #

  $self->save();
  $self->{started} = 1;

  return 1;
} # Method start

#----------------------------------------------------------------------------
#
# Method:      checkBackup
#
# Description: Check that log on backup is OK
#
# Arguments:
#  - Object reference
# Returns:
#  0 - if log on backup is OK

sub checkBackup($) {
  # parameters
  my $self = shift;


  return 0
      unless ($self->{'bak_dirty'});

  my $bak  = $self->{-cfg}->filename('bak', $self->{-name});
  $self->_saveFile($bak)
      unless (-e $bak);
  $self->dirty(1, 'bak');
  $self->log('-----', 'Backup detected, log initialized', '-----');

  return 1;
} # Method checkBackup

#----------------------------------------------------------------------------
#
# Method:      log
#
# Description: Add text to log
#
# Arguments:
#  0 - Object reference
#  1 .. n - Data to add
# Returns:
#  -
#

sub log($@) {
  # parameters
  my $self = shift;


  if ($self->{started})
  {
    $self->append($self->{-clock}->getDate(),
                  $self->{-clock}->getTime(),
                  @_,
                 );

    while (my $v = shift(@{$self->{log}})) {
      $self->append($v);
    } # while #
  } else {
    push @{$self->{log}}, join(' ', $self->{-clock}->getDate(),
                                    $self->{-clock}->getTime(),
                                    @_
                              );
  } # if #

} # Method log

1;
__END__
