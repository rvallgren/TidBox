#
package FileBase;
#
#   Document: Base class for Tidbox Files
#   Version:  2.6   Created: 2016-01-18 13:56
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: FileBase.pmx
#

my $VERSION = '2.6';
my $DATEVER = '2016-01-18';

# History information:
#
# 1.0  2007-03-19  Roland Vallgren
#      First issue.
# 1.1  2008-06-18  Roland Vallgren
#      "loaded" should only be set when loaded, not dirty
# 2.0  2008-09-14  Roland Vallgren
#      Added support for general file handling
#      Use Exco %+ to use same source to register version
# 2.1  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
#      Added logging if log is defined
# 2.2  2012-09-25  Roland Vallgren
#      Added method remove to delete a file
# 2.3  2012-12-12  Roland Vallgren
#      Perl 5.16
# 2.4  2013-05-19  Roland Vallgren
#      If session is locked, do not write to disk
# 2.5  2015-08-04  Roland Vallgren
#      Append should generate log entry
#      Minor error corrections
#      Improved handling of backup
# 2.6  2015-12-09  Roland Vallgren
#      Load the newest of file and backup restored, lost in previous version
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use Carp;
use integer;

use FileHandle;
use File::Spec;
use File::Copy;
use Text::ParseWords;

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

use constant FORMAT         => 'F';
use constant FORMAT_PREPEND => '# Format:';
use constant FORMAT_STRING  => FORMAT_PREPEND . FORMAT;

use constant BACKUP_ENA => $^O . '_do_backup';

# Registration analysis constants
my $YEAR  = '\d{4}';
my $MONTH = '\d{2}';
my $DAY   = '\d{2}';
my $DATE = $YEAR . '-' . $MONTH . '-' . $DAY;

my $HOUR   = '\d{2}';
my $MINUTE = '\d{2}';
my $TIME   = $HOUR . ':' . $MINUTE;

my $TYPE = '[A-Z]+';

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      dirty
#
# Description: Set dirty bit, both directory and backup
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Clear dirty bit if true
#  2 - Type of dirty bit
# Returns:
#  -

sub dirty($;$$) {
  # parameters
  my $self = shift;
  my ($clear, $typ) = @_;


  return 1
      unless($self->{loaded});

  my $bit = $clear ? 0 : 1;

  if ($typ) {
    $self->{$typ.'_dirty'} = $bit;
  } else {
    $self->{dir_dirty} = $bit;
    $self->{bak_dirty} = $bit
        if($self->{-cfg} and $self->{-cfg}->get(BACKUP_ENA));
  } # if #

  return 0;
} # Method dirty

#----------------------------------------------------------------------------
#
# Method:      isLoaded
#
# Description: Return loaded
#
# Arguments:
#  0 - Object reference
# Returns:
#  True if loaded

sub isLoaded($) {
  # parameters
  my $self = shift;

  return $self->{loaded};
} # Method isLoaded

#----------------------------------------------------------------------------
#
# Method:      getFile
#
# Description: Return information
#
# Arguments:
#  0 - Object reference
#  1 - Key
# Returns:
#  -

sub getFile($$) {
  # parameters
  my $self = shift;
  my ($key) = @_;

  return $self->{$key};
} # Method getFile

#----------------------------------------------------------------------------
#
# Method:      init
#
# Description: Initiate the data structure
#
# Arguments:
#  0 - Object reference
#  1 - Filename for the concerned file
#  2 - Filekey for the concerned file
# Returns:
#  -

sub init($$$) {
  # parameters
  my $self = shift;
  my ($name, $fkey) = @_;


  if ($name) {
    $self->{loaded} = 0;
    $self->{-name} = $name;
    $self->{-filekey} = $fkey;
  } # if #

  return 0;
} # Method init

#----------------------------------------------------------------------------
#
# Method:      addSet
#
# Description: Add a set
#
# Arguments:
#  - Object reference
#  - Were to add
#  - Reference to set to add
# Optiona arguments:
#  - Date
# Returns:
#  -

sub addSet($$$;$) {
  # parameters
  my $self = shift;
  my ($cfg, $set, $date) = @_;


  unless ($date) {
    while (my ($key, $val) = each(%{$set})) {
      $self->{$cfg}{$key} = $val;
    } # while #
    return 0;
  } # unless #

  unless ($self->{date}) {
    $self->{$cfg} = $set;
    $self->{date} = $date;
    return 0;
  } # unless #

  if ($date lt $self->{date}) {
    $self->{earlier}{$date} = $set;
    return 0;
  } # if #

  $self->{earlier}{$self->{date}} = $self->{$cfg};
  $self->{$cfg} = $set;
  $self->{date} = $date;

  return 0;
} # Method addSet

#----------------------------------------------------------------------------
#
# Method:      loadDatedSets
#
# Description: Load dated sets of settings
#
# Arguments:
#  - Object reference
#  - Filehandle
#  - Key for settings
# Returns:
#  -

sub loadDatedSets($$$) {
  # parameters
  my $self = shift;
  my ($fh, $cfg) = @_;


  my $line;
  my $date;
  my $set;

  while (defined($line = $fh->getline())) {

    $line =~ s/\s+$//o;

    last
        unless $line;

    if ($line =~ m/^$DATE$/ox ) {
      $self->addSet($cfg, $set, $date)
          if ($set);

      $set = undef;
      $date = $line;

    } elsif ($line =~ /^(\w+)=(.*?)\s*$/) {
      $set->{$1} = $2
          if (length($2) > 0);

    } elsif ($line =~ /^[^:]+:.:/o) {
      push @{$set}, $line;

    } else {
      # Faulty format
      return 0;

    } # if #

  } # while #

  $self->addSet($cfg, $set, $date)
      if ($set);

  return 0;
} # Method loadDatedSets

#----------------------------------------------------------------------------
#
# Method:      saveSet
#
# Description: Save a set of dated data
#                Hash:    <key>=<value>
#                Array:   @<set>
#                Scalar:  <set>
#
# Arguments:
#  - Object reference
#  - Filehandle
#  - Key for settings in object or reference to hash to save
# Optiona arguments:
#  - Date
# Returns:
#  -

sub saveSet($$$;$) {
  # parameters
  my $self = shift;
  my ($fh, $set, $date) = @_;


  $fh->print($date, "\n")
      if ($date);

  if (ref($set) eq 'ARRAY') {
    for my $l (@$set) {
      $fh->print($l, "\n")
          if (defined($l));
    } # for #

  } elsif (ref($set) eq 'HASH') {
    for my $k (keys(%$set)) {
      $fh->print($k, '=', $set->{$k}, "\n")
          if (defined($set->{$k}) and length($set->{$k}) > 0);
    } # for #

  } elsif ($set) {
    $fh->print($set, "\n");

  } # if #

  return 0;
} # Method saveSet

#----------------------------------------------------------------------------
#
# Method:      saveDatedSets
#
# Description: Save dated sets of settings
#
# Arguments:
#  - Object reference
#  - Filehandle
#  - Key for settings
# Returns:
#  -

sub saveDatedSets($$$) {
  # parameters
  my $self = shift;
  my ($fh, $cfg) = @_;


  for my $date (sort(keys(%{$self->{earlier}}))) {
    $self->saveSet($fh, $self->{earlier}{$date}, $date);

  } # for #

  $self->saveSet($fh, $self->{$cfg}, $self->{date});

  return 0;
} # Method saveDatedSets

#----------------------------------------------------------------------------
#
# Method:      Exists
#
# Description: Return true if tidbox file exists
#
# Arguments:
#  0 - Object reference
# Returns:
#  True if file exists

sub Exists($) {
  # parameters
  my $self = shift;

  my $file = $self->{-cfg}->filename('dir', $self->{-name});

  return (-e $file);
} # Method Exists

#----------------------------------------------------------------------------
#
# Method:      load
#
# Description: Load file from disk, filename is fetched from one of:
#              - self,file  (Special case for the configuration file)
#              - cfg,dir and self,name  \ The newest of these
#              - cfg,bak and self,name  /
#
# Arguments:
#  0 - Object reference
# Returns:
#  True if data is loaded.

sub load($) {
  # parameters
  my $self = shift;


  $self->_clear();
  $self->{loaded} = 1;
  $self->dirty(1);

  my $file = $self->{-cfg}->filename('dir', $self->{-name});
  my $bak  = $self->{-cfg}->filename('bak', $self->{-name});

  if ($bak) {

    # Take the newest of file and backup
    my ($ft, $bt) = (0, 0);
    $ft = (stat(_))[9]
        if (-e $file);
    $bt = (stat(_))[9]
        if (-e $bak);

    $file = $bak
        if ($bt > $ft);
  } # if #

  my $fh = new FileHandle($file, '<');

  return 0
      unless ($fh);

  while (defined(my $line = $fh->getline())) {

    next
        if ($line =~ /^\s*$/ or
            $line =~ /^\s*#/);

    if ($line =~ /^\[([-.\w\s]+)\]\s*$/) {
      croak 'Not known section head: [', $1, "]\n"
          if ($1 ne $self->{-filekey});

      last;

    } # if #

  } # while #

  $self->_load($fh) or
      croak 'Failed to load data for [', $self->{-filekey}, ']';

  $self->{-log}->log('Loaded', $., 'lines from', $file)
      if ($self->{-log});

  $fh->close();

  return 1;
} # Method load

#----------------------------------------------------------------------------
#
# Method:      _statFile
#
# Description: Stat file to determine modify time and size
#
# Arguments:
#  - Object reference
#  - File
# Returns:
#  mtime, size

sub _statFile($$) {
  # parameters
  my $self = shift;
  my ($file) = @_;



  my ($mtime, $size) = (0, 0);

  if (-e $file) {
    my @f_st = stat(_);
    $size  = $f_st[7];
    $mtime = $f_st[9];
  }

  return ($mtime, $size);
} # Method _statFile

#----------------------------------------------------------------------------
#
# Method:      copyBackup
#
# Description: Make sure the backup is up to date
#              If not use File::Copy to copy
#              Check is only performed once an hour
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - Backup is OK
#  1 - Backup does not exist
#  2 - Session is locked

sub copyBackup($) {
  # parameters
  my $self = shift;


  return 2
      if ($self->{-cfg}->isSessionLocked());

  my $bak = $self->{-cfg}->filename('bak', $self->{-name});

  return 1
      unless ($bak);

  my $file = $self->{-cfg}->filename('dir', $self->{-name});

  # Stat both files to determine date, size
  my ($fmTime, $fSize) = $self->_statFile($file);
  my ($bmTime, $bSize) = $self->_statFile($bak);

  return 0
      if (($fSize == $bSize) and ($fmTime == $bmTime));

  if ($fmTime >= $bmTime) {
    copy($file, $bak);
    $self->{-log}->log('Copy:', $file, $bak);
  } else {
    copy($bak, $file);
    $self->{-log}->log('Copy:', $bak, $file);
  } # if #
  $self->{-log}->log(' File modify time', $fmTime, "\t Size", $fSize);
  $self->{-log}->log(' Bkup modify time', $bmTime, "\t Size", $bSize);

  return 0;
} # Method copyBackup

#----------------------------------------------------------------------------
#
# Method:      _saveFile
#
# Description: Save a file to disk
#
# Arguments:
#  - Object reference
#  - File name
# Returns:
#  0 - if success

sub _saveFile($$) {
  # parameters
  my $self = shift;
  my ($file) = @_;


  my $fh = new FileHandle($file, '>');

  unless ($fh) {
    $self->callback($self->{-error_popup}, 'Kan inte öppna: "' . $file . '"' , $! );
    return 1;
  } # unless #

  $fh->print(FORMAT_STRING . "\n" .
             "# This file is generated, do not edit\n" .
             "# Creator: Tidbox\n" .
             "\n" .
             '[' , $self->{-filekey} , ']' ."\n"
            );

  $self->_save($fh);

  $self->{-log}->log('Saved', $file)
      if ($self->{-log});

  unless ($fh->close()) {
    $self->callback($self->{-error_popup}, 'Kan inte skriva: "' . $file . '"' , $! );
    return 1;
  } # unless #

  return 1;
} # Method _saveFile

#----------------------------------------------------------------------------
#
# Method:      save
#
# Description: Save to disk if there is unchanged data
#              Use copyBackup to save to backup, if backup directory is defined
#              No save happens if data is already save
#
# Arguments:
#  0 - Object reference
# Optional Arguments:
#  1 - Force save
# Returns:
#  0 - if success

sub save($;$) {
  # parameters
  my $self = shift;
  my ($force) = @_;


  return undef
      if ($self->{-cfg}->isSessionLocked());

  unless ($self->{loaded}) {
    return 1;
  } # unless #

  $self->dirty()
      if $force;

  my $file = $self->{-cfg}->filename('dir', $self->{-name});

  if ($self->{'dir_dirty'}) {
    $self->_saveFile($file);
    $self->dirty(1, 'dir');
  } # if #


  if ($self->{'bak_dirty'}) {
    my $bak  = $self->{-cfg}->filename('bak', $self->{-name});
    if ($bak) {
      copy($file, $bak);
      $self->{-log}->log('Copy:', $file, $bak)
          if ($self->{-log});
      $self->dirty(1, 'bak');
    } # if #
  } # if #


  return 1;
} # Method save

#----------------------------------------------------------------------------
#
# Method:      append
#
# Description: Append data to file
#              Also append to backup, if backup directory is defined
#              Do not append if file does not exist
#
# Arguments:
#  0 - Object reference
#  1 - Data to append to the file
# Returns:
#  0 - if success

sub append($@) {
  # parameters
  my $self = shift;


  return undef
      if ($self->{-cfg}->isSessionLocked());

  for my $typ ('bak', 'dir') {

    # Do not append if dirty, could cause inconsistency in file
    next
        if ($self->{$typ.'_dirty'});

    my $file = $self->{-cfg}->filename($typ, $self->{-name});

    # If no filename or file does not exists, skip
    unless ($file and -e $file) {
      $self->dirty(undef, $typ);
      next;
    } # unless #

    my $fh = new FileHandle($file, '>>');

    unless ($fh) {
      $self->callback($self->{-error_popup}, 'Kan inte öppna: "' . $file . '"' , $! );
      next;
    } # unless #

    $self->_append($fh, @_);

    $self->{-log}->log('Appended', $file)
        if ($self->{-log} and $self ne $self->{-log});

    unless ($fh->close()) {
      $self->callback($self->{-error_popup}, 'Kan inte skriva: "' . $file . '"' , $! );
      next;
    } # unless #

  } # for #

  return 0;
} # Method append

#----------------------------------------------------------------------------
#
# Method:      remove
#
# Description: Remove a file, both real and backup
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - if success

sub remove($) {
  # parameters
  my $self = shift;


  for my $typ ('bak', 'dir') {

    my $file = $self->{-cfg}->filename($typ, $self->{-name});

    unlink($file)
        if ($file and -r $file);

  } # for #

  return 0;
} # Method remove

#----------------------------------------------------------------------------
#
# Method:      startAuto
#
# Description: Start autosave timer
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub startAuto($) {
  # parameters
  my $self = shift;


  $self->{-clock}->repeat(-minute => [$self => 'autosave']);

  return 1;
} # Method startAuto

#----------------------------------------------------------------------------
#
# Method:      autosave
#
# Description: If data is not saved for the threshold time, save
#
# Arguments:
#  0 - Object reference
# Returns:
#  0 - if success

sub autosave($) {
  # parameters
  my $self = shift;


  my $th = $self->{-cfg}->get('save_threshold');

  for my $typ ("bak_dirty", "dir_dirty") {
    next
        unless ($self->{$typ});

    next
        if ++($self->{$typ}) < $th;

    $self->save();
    return 1;
  } # for #

  return 0;
} # Method autosave

1;
__END__
