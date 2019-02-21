#
package TbFile::Util;
#
#   Document: File utilities
#   Version:  1.0   Created: 2019-01-29 14:09
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: FileUtil.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2019-01-29';

# History information:
#
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
#  - Object reference
#  - Name of directory to read
# Optional Arguments:
#  - Regexp to filter filenames
# Returns:
#  undef      Directory does not exist or can not be read
#  reference  to list of files

sub readDir($$;$) {
  # parameters
  my $self = shift;
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

1;
__END__
