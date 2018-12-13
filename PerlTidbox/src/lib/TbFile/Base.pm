#
package TbFile::Base;
#
#   Document: Base class for Tidbox Files
#   Version:  2.8   Created: 2018-12-07 17:45
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: FileBase.pmx
#

my $VERSION = '2.8';
my $DATEVER = '2018-12-07';

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
# 2.7  2017-09-08  Roland Vallgren
#      Stop load if filekey not found
# 2.8  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      References to other objects in own hash
#      Added methods clone and merge
#      Added merge with new backup data
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
        if($self->{erefs}{-cfg} and $self->{erefs}{-cfg}->get(BACKUP_ENA));
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
# Method:      getFileName
#
# Description: Return file name
#
# Arguments:
#  - Object reference
# Returns:
#  File name

sub getFileName($) {
  # parameters
  my $self = shift;

  return $self->{-name};
} # Method getFileName

#----------------------------------------------------------------------------
#
# Method:      getFileSize
#
# Description: Get size of file on disk
#
# Arguments:
#  - Object reference
#  - File to stat
# Returns:
#  Size as returned by stat

sub getFileSize($$) {
  # parameters
  my $self = shift;
  my ($file) = @_;

  my $filename = $self->readFileName($file);
  my ($fmTime, $fSize) = $self->_statFile($filename);
  return $fSize;
} # Method getFileSize

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
# Method:      clear
#
# Description: Clear data before load
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub clear($) {
  # parameters
  my $self = shift;

  $self->dirty(1);
  $self->_clear();
  $self->{loaded} = 0;
  return 0;
} # Method clear

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
# Optional arguments:
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
# Optional arguments:
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
    while (my ($k, $v) = each(%$set)) {
      $fh->print($k, '=', $v, "\n")
          if (defined($v) and length($v) > 0);
    } # while #

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
# Method:      clone
#
# Description: Create a new instance, copy erefs
#
# Arguments:
#  - Object reference
# Returns:
#  - Reference to clone object

sub clone($) {
  # parameters
  my $self = shift;

  my $clone = $self->new();
  $clone->configure(%{$self->{erefs}});

  return $clone;
} # Method clone

#----------------------------------------------------------------------------
#
# Method:      fileExists
#
# Description: Return true if tidbox file exists
#
# Arguments:
#  0 - Object reference
# Returns:
#  True if file exists

sub fileExists($) {
  # parameters
  my $self = shift;

  my $file = $self->{erefs}{-cfg}->filename('dir', $self->{-name});

  return (-e $file);
} # Method fileExists

#----------------------------------------------------------------------------
#
# Method:      readFileName
#
# Description: Determine filename for reading
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - File to open
#       'bak', 'dir' or <filename>
# Returns:
#  - Full path to file to use

sub readFileName($;$) {
  # parameters
  my $self = shift;
  my ($file) = @_;

  $self->{erefs}{-log}->trace('File:', $file, ':')
      if ($self->{erefs}{-log});

  if (not defined($file)) {
    # No argument specified, use default
    $file = $self->{erefs}{-cfg}->filename('dir', $self->{-name});
    my $bak  = $self->{erefs}{-cfg}->filename('bak', $self->{-name});

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
    return $file;
  } # if #

  if ($file eq 'bak' or $file eq 'dir') {
    # dir or bak, use specified
    $file = $self->{erefs}{-cfg}->filename($file, $self->{-name});
    $self->{erefs}{-log}->trace('dir or bak, use specified, got:', $file, ':')
        if ($self->{erefs}{-log});
    return $file;
  } # if #

  if (-f $file) {
    # Full path to file as argument
    $self->{erefs}{-log}->
           trace('Full path to file as argument, got:', $file, ':')
        if ($self->{erefs}{-log});
    return $file;
  } # if #

  if (-d $file) {
    # Full path to directory as argument
    $file = File::Spec->catfile($file, $self->{-name});
    $self->{erefs}{-log}->
              trace('Full path to directory as argument, got:', $file, ':')
        if ($self->{erefs}{-log});
    return $file;
  } # if #

  # Default? Assume directory
  $file = File::Spec->catfile($file, $self->{-name});
  $self->{erefs}{-log}->trace('Default? Assume directory, got:', $file, ':')
      if ($self->{erefs}{-log});
  return $file;

} # Method readFileName

#----------------------------------------------------------------------------
#
# Method:      openRead
#
# Description: Open a Tidbox file for reading
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - File to open
#       'bak', 'dir' or <filename>
#  - Handle to use
# Returns:
#  - Filehandle on success

sub openRead($;$$) {
  # parameters
  my $self = shift;
  my ($file, $handle) = @_;

  $self->{erefs}{-log}->trace('File:', $file, ':')
      if ($self->{erefs}{-log});

  my $filename = $self->readFileName($file);
  $self->{erefs}{-log}->trace('Got filename:', $filename, ':')
      if ($self->{erefs}{-log});

  # TODO Allow this to be undef
  $self->{-readOpened} = $filename || '<noname>';

  return new FileHandle($filename, '<')
      unless ($handle);

  return undef
      unless ($handle->open($filename));

  return $handle;
} # Method openRead

#----------------------------------------------------------------------------
#
# Method:      input_line_number
#
# Description: Return input line number when file was loaded
#
# Arguments:
#  - Object reference
# Returns:
#  - Number

sub input_line_number($) {
  # parameters
  my $self = shift;

  return $self->{input_line_number} || 0;
} # Method input_line_number

#----------------------------------------------------------------------------
#
# Method:      load
#
# Description: Load file from disk, filename is fetched from one of:
#              - cfg,dir and self,name  \ The newest of these
#              - cfg,bak and self,name  /
#              Specified file dir, bak or filename as argument
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Directory to load from
#       'bak', 'dir' or <filename>
#  - Handle to use
# Returns:
#  True if data is loaded.

sub load($;$$) {
  # parameters
  my $self = shift;
  my ($dir, $handle) = @_;

  $self->{erefs}{-log}->trace('Dir:', $dir, ':')
      if ($self->{erefs}{-log});

  $self->clear();
  $self->{loaded} = 1;

  my $fh = $self->openRead($dir, $handle);

  return 0
      unless ($fh);

  $self->{erefs}{-log}->trace('Loading')
      if ($self->{erefs}{-log});

  my $found = 0;

  if (my $line = $fh->getline()) {
    # TODO How should we handle faulty file format?
    if (substr($line, 0, length(FORMAT_STRING)) ne FORMAT_STRING) {
      croak "Faulty Tidbox file format: \"", $line, "\"\n";
      $fh->close();
      return 0;
    } # if #

  } # if #

  while (defined(my $line = $fh->getline())) {

    next
        if ($line =~ /^\s*$/ or
            $line =~ /^\s*#/);

    if ($line =~ /^\[([-.\w\s]+)\]\s*$/) {
      # TODO How should we handle faulty file format?
      croak 'Not known section head: [', $1, "]\n"
          if ($1 ne $self->{-filekey});

      $found = 1;
      last;

    } # if #

  } # while #

  if ($found) {

    $self->_load($fh) or
        croak 'Failed to load data for [', $self->{-filekey}, ']';

    $self->{input_line_number} = $fh->input_line_number();

    $self->{erefs}{-log}->log('Loaded', $self->{input_line_number},
                              'lines from', $self->{-readOpened})
        if ($self->{erefs}{-log});

  } else {

    croak 'No data for [', $self->{-filekey}, '] found in file ',
           $self->{-readOpened};

  } # if #

  $fh->close();

  return 1;
} # Method load

#----------------------------------------------------------------------------
#
# Method:      loadOther
#
# Description: Load file from specified directory
#
# Arguments:
#  - Object reference
#  - Dir
# Returns:
#  - File instance

sub loadOther($$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;

  $self->{erefs}{-log}->trace('Dir:', $dir, ':')
      if ($self->{erefs}{-log});

  my $other = $self->clone();

  # Try to load file, Can not load other session, no such file, ...
  unless ($other->load($dir)) {
    $self->{erefs}{-log}->
            log('Failed to load', $other->getFile('-readOpened'))
        if ($self->{erefs}{-log});
    return undef;
  } # if #

  return $other;
} # Method loadOther

#----------------------------------------------------------------------------
#
# Method:      copyBackup
#
# Description: Make sure the backup is up to date
#              If not use File::Copy to copy
#              Check is only performed once an hour
# TODO Only file date and file size is checked. Is compare needed?
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
      if ($self->{erefs}{-cfg}->isSessionLocked());

  my $bak = $self->{erefs}{-cfg}->filename('bak', $self->{-name});

  return 1
      unless ($bak);

  my $file = $self->{erefs}{-cfg}->filename('dir', $self->{-name});

  # Stat both files to determine date, size
  my ($fmTime, $fSize) = $self->_statFile($file);
  my ($bmTime, $bSize) = $self->_statFile($bak);

  return 0
      if (($fSize == $bSize) and ($fmTime == $bmTime));

  if ($fmTime >= $bmTime) {
    copy($file, $bak);
    $self->{erefs}{-log}->log('Copy:', $file, $bak)
        if ($self->{erefs}{-log});
  } else {
    copy($bak, $file);
    $self->{erefs}{-log}->log('Copy:', $bak, $file)
        if ($self->{erefs}{-log});
  } # if #

  if ($self->{erefs}{-log}) {
    $self->{erefs}{-log}->
            log(' File modify time', $fmTime, "\t Size", $fSize);
    $self->{erefs}{-log}->
            log(' Bkup modify time', $bmTime, "\t Size", $bSize);
  } # if #

  return 0;
} # Method copyBackup

#----------------------------------------------------------------------------
#
# Method:      forcedCopy
#
# Description: Copy data, overwrite target
#              Use File::Copy to copy
#
# Arguments:
#  - Object reference
#  - Source
#  - Target
# Returns:
#  0 - OK
#  1 - Session is locked
#  2 - Source does not exist
#  3 - Target does not exist

sub forcedCopy($$$) {
  # parameters
  my $self = shift;
  my ($src, $trg) = @_;


  $self->{erefs}{-log}->trace('Do copy:', $src, '->', $trg)
      if ($self->{erefs}{-log});
  my $cfg = $self->{erefs}{-cfg};
  return 1
      if ($cfg->isSessionLocked());

  # TODO Check if src or trg is not 'dir' or 'bak'

  my $source = $cfg->filename($src, $self->{-name});
  $self->{erefs}{-log}->trace(' Real source:', $source)
      if ($self->{erefs}{-log});
  return 2
      unless ($source);

  my $target = $cfg->filename($trg, $self->{-name});
  $self->{erefs}{-log}->trace(' Real target:', $target)
      if ($self->{erefs}{-log});
  return 3
      unless ($target);

  copy($source, $target);
  $self->{erefs}{-log}->log('Copy:', $source, $target)
      if ($self->{erefs}{-log});

  return 0;
} # Method forcedCopy

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

  $self->{erefs}{-log}->log('Saved', $file)
      if ($self->{erefs}{-log});

  unless ($fh->close()) {
    $self->callback($self->{-error_popup},
                    'Kan inte skriva: "' . $file . '"' , $! );
    return 1;
  } # unless #

  return 1;
} # Method _saveFile

#----------------------------------------------------------------------------
#
# Method:      save
#
# Description: Save to disk if there is unchanged data
#              Use copy to save to backup, if backup directory is defined
#              No save happens if data is already save
#  TODO Dirty should not change if save did not succeed
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
      if ($self->{erefs}{-cfg}->isSessionLocked());

  unless ($self->isLoaded()) {
    return 1;
  } # unless #

  $self->dirty()
      if $force;

  my $file = $self->{erefs}{-cfg}->filename('dir', $self->{-name});

  if ($self->{'dir_dirty'}) {
    $self->_saveFile($file);
    $self->dirty(1, 'dir');
  } # if #


  if ($self->{'bak_dirty'}) {
    my $bak  = $self->{erefs}{-cfg}->filename('bak', $self->{-name});
    if ($bak) {
      copy($file, $bak);
      $self->{erefs}{-log}->log('Copy:', $file, $bak)
          if ($self->{erefs}{-log});
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
      if ($self->{erefs}{-cfg}->isSessionLocked());

  for my $typ ('bak', 'dir') {

    # Do not append if dirty, could cause inconsistency in file
    next
        if ($self->{$typ.'_dirty'});

    my $file = $self->{erefs}{-cfg}->filename($typ, $self->{-name});

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

    $self->{erefs}{-log}->log('Appended', $file)
        if ($self->{erefs}{-log} and $self ne $self->{erefs}{-log});

    unless ($fh->close()) {
      $self->callback($self->{-error_popup}, 
                      'Kan inte skriva: "' . $file . '"' , $! );
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

    my $file = $self->{erefs}{-cfg}->filename($typ, $self->{-name});

    unlink($file)
        if ($file and -r $file);

  } # for #

  return 0;
} # Method remove

#----------------------------------------------------------------------------
#
# Method:      merge
#
# Description: Merge file data, load other, check arguments
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  -fromInst  => Reference to object to merge from
#  -fromDir   => Name of directory to merge from
#  -startDate => Start date
#  -endDate   => End date
#  -noLoad    => Evaluates to true: Do not load from file
# Returns:
#  -

sub merge($%) {
  # parameters
  my $self = shift;
  my (%args) = @_;

  $self->{erefs}{-log}->trace()
      if ($self->{erefs}{-log});

  my $source;
  if (ref($args{-fromInst})) {
    $self->{erefs}{-log}->trace('-fromInst')
        if ($self->{erefs}{-log});
    $source = $args{-fromInst};
  } elsif ($args{-fromDir}) {
    # Get source times
    $self->{erefs}{-log}->trace('-fromDir', $args{-fromDir})
        if ($self->{erefs}{-log});
    $source = $self->loadOther($args{-fromDir});
    return undef
        unless ($source);
  } else {
    # Nothing to merge from provided
    $self->{erefs}{-log}->trace('Nothing to merge from provided')
        if ($self->{erefs}{-log});
    return undef;
  } # if #

  my $startDate = $args{-startDate} || '0000-00-00';
  my $endDate   = $args{-endDate}   || '9999-12-31';
  my $progress_ref = $args{-progress_h};

  unless ($args{-noLoad}) {
    $self->load('dir')
        unless ($self->isLoaded());
  } # unless #
  $self->{erefs}{-log}->
       trace('_mergeData($source, $startDate, $endDate)', $startDate, $endDate)
      if ($self->{erefs}{-log});
  $self->_mergeData($source, $startDate, $endDate, $progress_ref);

  return 0;
} # Method merge

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


  $self->{erefs}{-clock}->repeat(-minute => [$self => 'autosave']);

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


  my $th = $self->{erefs}{-cfg}->get('save_threshold');

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
