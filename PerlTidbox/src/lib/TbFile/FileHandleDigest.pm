#
package TbFile::FileHandleDigest;
#
#   Document: File handle with Digest
#   Version:  1.0   Created: 2018-02-01 21:40
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: FileHandleDigest.pmx
#

my $VERSION = '1.0';
my $DATEVER = '2018-02-01';

# History information:
#
# 1.0  2015-01-15  Roland Vallgren
#      First issue.
#

#----------------------------------------------------------------------------
#
# Setup
#
use FileHandle;
use Digest;

use strict;
use warnings;
use integer;

use Version qw(register_starttime);

# Register version information
{
  use Version qw(register_version);
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => '2018-02-01',
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
# Method:      new
#
# Description: Create a FileHandle object and add a Digest
#
# Arguments:
#  - Object prototype
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;
  my $sha1 = Digest->new("SHA-1");
  my $self = { fh   => undef,
               sha1 => $sha1,
               files => {},
             };
  bless($self, $class);
  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      open
#
# Description: Open a file for reading with digest
#
# Arguments:
#  - Object reference
#  - File name
# Returns:
#  True if OK

sub open($$) {
  # parameters
  my $self = shift;
  my ($file) = @_;


  my $fh = new FileHandle($file, '<');
  return 0
      unless ($fh);
  $self->{fh} = $fh;
  $self->{files}{$file} = 1;
  return $fh;
} # Method open

#----------------------------------------------------------------------------
#
# Method:      getline
#
# Description: Get a line from file, add to digest
#
# Arguments:
#  - Object reference
# Returns:
#  - Line

sub getline($) {
  # parameters
  my $self = shift;


  my $l = $self->{fh}->getline;
  $self->{sha1}->add($l)
      if (defined($l));

  return $l;
} # Method getline

#----------------------------------------------------------------------------
#
# Method:      input_line_number
#
# Description: Return input line number from filehandle
#
# Arguments:
#  - Object reference
# Returns:
#  - Number

sub input_line_number($) {
  # parameters
  my $self = shift;

  return $self->{fh}->input_line_number();
} # Method input_line_number

#----------------------------------------------------------------------------
#
# Method:      add
#
# Description: Add data to digest
#
# Arguments:
#  - Object reference
#  - Data
# Returns:
#  -

sub add($@) {
  # parameters
  my $self = shift;

  $self->{sha1}->add(@_);

  return 0;
} # Method add

#----------------------------------------------------------------------------
#
# Method:      addfile
#
# Description: Add a file to the digest
#
# Arguments:
#  - Object reference
#  - File object reference
# Returns:
#  -

sub addfile($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  # TODO Do not read a file again
  my $fh = $ref->openRead();
  return undef
      unless ($fh);
  $self->{sha1}->addfile($fh);
  $fh->close;
  $self->{files}{$ref->getFile('-readOpened')} = 1;
  return 0;
} # Method addfile

#----------------------------------------------------------------------------
#
# Method:      conditionalAddfile
#
# Description: Add a file to the digest, unless its added before
#
# Arguments:
#  - Object reference
#  - File object reference
# Returns:
#  -

sub conditionalAddfile($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;

  # TODO Do not read a file again
  my $file = $ref->readFileName();
  return 0
      if (exists($self->{files}{$file}));
  my $fh = $self->open();
  return undef
      unless ($fh);
  $self->{sha1}->addfile($fh);
  $fh->close();
  return 0;
} # Method conditionalAddfile

#----------------------------------------------------------------------------
#
# Method:      close
#
# Description: Close filehandle
#
# Arguments:
#  - Object reference
# Returns:
#  True if OK

sub close($) {
  # parameters
  my $self = shift;

  my $r = $self->{fh}->close();
  $self->{fh} = undef;
  return $r;
} # Method close

#----------------------------------------------------------------------------
#
# Method:      hexdigest
#
# Description: Get sha1 digest in hexadecimal
#              The filhandle is closed
#
# Arguments:
#  - Object reference
# Returns:
#  - Hex vaule of sha1

sub hexdigest($) {
  # parameters
  my $self = shift;

  %{$self->{files}} = ();
  return $self->{sha1}->hexdigest();
} # Method hexdigest

1;
__END__
