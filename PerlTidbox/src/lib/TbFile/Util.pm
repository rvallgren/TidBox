#
package TbFile::Util;
#
#   Document: File utilities
#   Version:  1.1   Created: 2019-08-13 16:05
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: FileUtil.pmx
#

my $VERSION = '1.1';
my $DATEVER = '2019-08-13';

# History information:
#
# 1.1  2019-08-03  Roland Vallgren
#      New method checkTidboxDirectory
# 1.0  2019-01-25  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#

use strict;
use warnings;
use Carp;
use integer;

use DirHandle;

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
# Method:      readDir
#
# Description: Read contents of a directory
#              Optional filter regexp to grep matching names
#
# Arguments:
#  - Class
#  - Name of directory to read
# Optional Arguments:
#  - Regexp to filter filenames
# Returns:
#  undef      Directory does not exist or can not be read
#  reference  List of names in directory, empty list means no names
#               '.' and '..' are not included in list

sub readDir($$;$) {
  # parameters
  my $class = shift;
  my ($dir, $regexp) = @_;


  return undef
      unless (-d $dir);

  my $dh = DirHandle->new($dir) or
    return undef;

  my $files = [];

  while(defined(my $name = $dh->read())) {
    next
        if ($name eq '.' or $name eq '..');
    next
        if ($regexp and not ($name =~ m/$regexp/));
    push @$files, $name;
  } # while #
  # Close
  undef($dh);
  return $files;
} # Method readDir

#----------------------------------------------------------------------------
#
# Method:      checkTidBoxDirectory
#
# Description: Check if the directory is a tidbox directory
#              - Is it empty?
#              - Does it contain Tidbox files?
#              - Does it contain not Tidbox files?
#
# Arguments:
#  - Class 
#  - Directory name
# Optional Arguments:
#  - Reference to log, when provided status is logged
# Returns:
#  - 'OK'                       A correct directory specified
#  - 'noArgumentProvided'       No directory name specified
#  - 'doesNotExist'             Directory does not exist
#  - 'notADirectory'            Name is not a directory
#  - 'notWriteAccess'           We do not have write access to the directory
#  - 'failedOpenDir'            Directory can not be opened for reading
#  - 'dirIsEmpty'               Directory is empty
#  
 
sub checkTidBoxDirectory($$;$) {
  # parameters
  my $class = shift;
  my ($d, $log) = @_;


  unless ($d) {
    $log->log('FileUtil::checkTidBoxDirectory: No argument provided')
        if ($log);
    return 'noArgumentProvided';
  } # unless #

  unless (-e $d) {
    # Does not exist
    $log->log('FileUtil::checkTidBoxDirectory:', $d, 'does not exist')
        if ($log);
    return 'doesNotExist';
  } # if #

  unless (-d $d) {
    # Arument is not a directory or name does not exist
    $log->log('FileUtil::checkTidBoxDirectory:', $d, 'is not a directory')
        if ($log);
    return 'notADirectory';
  } # unless #

  unless (-w $d) {
    # No write access to the directory
    # TODO Write protected does not work on Windows.
    #      We do not check result of write
    $log->log('FileUtil::checkTidBoxDirectory:', $d, 'is read only')
        if ($log);
    return 'notWriteAccess';
  } # unless #

  # Check if there are any files in the directory
  my $dirFiles = TbFile::Util->readDir($d);
  unless (defined($dirFiles)) {
    # Failed to open directory for reading
    $log->log('FileUtil::checkTidBoxDirectory: Failed to open',$d,'for reading')
        if ($log);
    return 'failedOpenDir';
  } # unless #

  # TODO These checks are not needed????
  my $fileCnt = 0;
  for my $f (@{$dirFiles}) {
    $fileCnt++;
  } # for #

  if ($fileCnt == 0) {
    # Directory is empty
    $log->log('FileUtil::checkTidBoxDirectory: Directory', $d, 'is empty')
        if ($log);
    return 'dirIsEmpty';
  } # if #


  return 'OK';
} # Method checkTidBoxDirectory

1;
__END__
