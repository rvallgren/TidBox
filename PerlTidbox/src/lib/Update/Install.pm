#
package Update::Install;
#
#   Document: Install Tidbox from archive Zip-file
#   Version:  1.1   Created: 2019-02-27 12:47
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Install.pmx
#

my $VERSION = '1.1';
my $DATEVER = '2019-02-27';

# History information:
#
# 1.1  2019-02-26  Roland Vallgren
#      Added logging
# 1.0  2019-01-25  Roland Vallgren
#      First issue, Install part moved from Update.pm.
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;

use strict;
use warnings;
use integer;

use Archive::Extract;
use FindBin;
use File::Spec;
use File::Path qw();
use File::Temp qw/ tempfile /;

use FileHandle;
use TbFile::Util;
use Update::Github;

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

use constant {
  TMPFILE_SUFFIX => 'TidBoxDownload.zip',
  TIDBOX_PROGRAM => 'tidbox.pl',
  TIDBOX_LIB     => 'lib/',

  NEW_DIRECTORY_PREFIX => '_new_',
  OLD_DIRECTORY_PREFIX => '_old_',
};

my $NEW_FILES = [ TIDBOX_PROGRAM, TIDBOX_LIB ];


my $REPLACE_TIDBOX_PL =
'
### Settings ####
my $rootDir    = q=%rootDir%=;

my $newDir     = q=%newDir%=;
my @newFiles   = qw=%newFiles%=;

my $oldDir     = q=%oldDir%=;
my @oldFiles   = qw=%oldFiles%=;

my $perl_cmd   = q=%perl_exe%=;
my $tidbox_cmd = q=%tidbox_cmd%=;
my @tidbox_arg = %tidbox_arg%;
### End Settings ####

#--------------------------------------------------------
use strict;
use warnings;
use File::Spec;
use Tk;
use Tk::ROText;

local($SIG{__WARN__}) = \&warning_handler;
my @error = ();
my @warning = ();
my $win;

#--------------------------------------------------------

sub warning_handler {
  push(@warning, split("\n", join("\n", @_)));
  return 0;
} # sub warning_handler

#--------------------------------------------------------
sub install () {
  # Check if the required parts are available
  unless (-d $newDir) {
    push(@error, "Directory $newDir does not exist");
    return undef;
  } # unless #

  for my $f (@newFiles) {
    my $new    = File::Spec->catfile($newDir,  $f);
    unless (-e $new) {
      push(@error, "Missing $new: $!");
      return undef;
    } # unless #
  } # for #

  unless (-d $oldDir) {
    push(@error, "Directory $oldDir does not exist");
    return undef;
  } # unless #

  # Move active tidbox files to old
  for my $f (@oldFiles) {
    my $active = File::Spec->catfile($rootDir, $f);
    my $old    = File::Spec->catfile($oldDir,  $f);
    unless (rename($active, $old)) {
      push(@error, "Failed to move $active to $old: $!");
      return undef;
    } # unless #
  } # for #

  # Move new tidbox files to active
  for my $f (@newFiles) {
    my $active = File::Spec->catfile($rootDir, $f);
    my $new    = File::Spec->catfile($newDir,  $f);
    unless (rename($new, $active)) {
      push(@error, "Failed to move $new to $active: $!");
      return undef;
    } # unless #
  } # for #
  return 1;
} # end install #
sub destroy() {
  return $win->destroy();
} # sub destroy

#--------------------------------------------------------

my $res = install();

#--------------------------------------------------------
if (@error or @warning) {
  $win = MainWindow->new(-title => "Replace Tidbox Problem");
  my $fr = $win -> Frame()
       -> pack(-side => "top", -expand => "1", -fill => "both");
  my $s = scalar(@error) + scalar(@warning) + 8;
  my $txt = $fr -> Scrolled("ROText", -scrollbars => "e")
                -> pack(-side => "top", -expand => "1", -fill => "both");
  $txt -> configure(
                    -wrap => "word",
                    -height => $s
                   );
  if (@warning) {
    $txt -> Insert("=== Warnings detected ===\n");
    $txt -> Insert(join("\n", @warning));
    $txt -> Insert("\n\n");
  } # if #

  if (@error) {
    $txt -> Insert("=== Errors detected ===\n");
    $txt -> Insert(join("\n", @error));
    $txt -> Insert("\n\n");
  } # if #

  $win -> Frame()
       -> pack(-side => "top", -fill => "both")
       -> Button(-text => "Avsluta", -command => \&destroy)
       -> pack(-side => "top");
  MainLoop;
  exit 1;
} # if #

exit 1
    unless(defined($res));
#--------------------------------------------------------
# Start the new tidbox
if ($perl_cmd ne q/exit/) {
  exec($perl_cmd, $tidbox_cmd, @tidbox_arg);
} # if #
';


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
# Description: Create update install object
#
# Arguments:
#  - Object prototype
#  - Reference to call hash
#  - External references, for log and trace
# Returns:
#  Object reference

sub new($$$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($args, $erefs) = @_ ;
  my $self =
   {
    args =>        $args,   # Reference to arguments hash
    erefs =>      $erefs,   # Reference to others

    our_version => undef,   # Our version

    installed   => undef,   # Our installed version of Tidbox

    new_version => undef,   # Information for new version

    installdir  => undef,   # Handling of new version extraction

    extracted   => undef,   # Information for extracted archive

    handler     => Update::Github->new($erefs),
   };
  bless($self, $class);
  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      getRateLimit
#
# Description: Get rate limit, if available
#
# Arguments:
#  - Object reference
# Returns:
#  >0 Rate limiting is on. Value is reset time
#  0 It is OK to access now
#  undef if failed to get information

sub getRateLimit($) {
  # parameters
  my $self = shift;

  
  my $rate_limit = $self->{handler}->getRateLimit();

  return $rate_limit;
} # Method getRateLimit

#----------------------------------------------------------------------------
#
# Method:      byVersion
#
# Description: Compare Tidbox versions
#              For example:
#                4.11, 4.11.a, 4.12.01, 4.12, 4.12.1
#              NOTES: Letter and preliminary versions can are only
#                     allowed in third digit or later
#                     There are allways two digits
#
# Arguments:
#  - Object reference
#  - $a
#  - $b
# Returns:
#  -

sub byVersion($$$) {
  # parameters
  my $self = shift;
  my ($va, $vb) = @_;

  # Assume equal
  return 0
      if ($va eq $vb);

  # Oh no. We have to analyze version...
  my @aa = split('\.', $va);
  my @ab = split('\.', $vb);

  for (my $i=0 ; $i < 2; $i++) {
    return ($aa[$i] <=> $ab[$i])
        if ($aa[$i] ne $ab[$i]);
  } # for #

  for (my $i=2 ; $i < 7; $i++) {
    # All equal
    return 0
        if ($#aa < $i and $#ab < $i);

    # Add empty string when one is shorter
    $aa[$i] = ''
        if ($#aa < $i);
    $ab[$i] = ''
        if ($#ab < $i);

    # Equal, try next
    next
        if ($aa[$i] eq $ab[$i]);

    # Compare numerical versions
    if ($aa[$i] =~ /^\d+$/ and $ab[$i] =~ /^\d+$/) {

      # Release versions
      return ($aa[$i] <=> $ab[$i])
          if (($aa[$i] !~ /^0+[1-9]/ and $ab[$i] !~ /^0+[1-9]/) or
              ($aa[$i] =~ /^0+[1-9]/ and $ab[$i] =~ /^0+[1-9]/)
             );

      # Handle preliminary versions with release versions, that is 0- vs 0-9
      return -1
          if ($aa[$i] =~ /^0+[1-9]/);
      return  1
          if ($ab[$i] =~ /^0+[1-9]/);

      # Both are preliminary
      return ($aa[$i] <=> $ab[$i]);
    } # if #

    # Compare alphabetical versions, that is emergency correction
    return ($aa[$i] cmp $ab[$i])
        if ($aa[$i] =~ /^\D+$/ and $ab[$i] =~ /^\D+$/);

    # Handle 0-versions vs empty, that is preliminary versions
    return  1
        if ($aa[$i] eq ''         and $ab[$i] =~ /^0+[1-9]/);
    return -1
        if ($aa[$i] =~ /^0+[1-9]/ and $ab[$i] eq ''        );

    # Handle that one is alphabetical version, that is emergency correction
    return -1
        if ($ab[$i] =~ /^\D+$/);
    return  1
        if ($aa[$i] =~ /^\D+$/);

    # Handle that one is numerical version
    return -1
        if ($ab[$i] =~ /^\d+$/);
    return  1
        if ($aa[$i] =~ /^\d+$/);

  } # for #

  return undef;  # Failed comparison
} # Method byVersion

#----------------------------------------------------------------------------
#
# Method:      getReleases
#
# Description: Get a list of Tidbox releases from Github
#
# Arguments:
#  - Object reference
# Returns:
#  Number of found releases
#    TODO Skip older releases, then return will be available newer releases
#  undef if failed to get information

sub getReleases($) {
  # parameters
  my $self = shift;

  my $ref = $self->{handler}->getReleases();

  my $sorted = [ sort { $self->byVersion($a, $b) } @$ref ];

  $self->{releases}{sorted} = $sorted;

  $self->{erefs}{-log}->log('Update got releases:', @$sorted);

  return scalar(@$sorted);
} # Method getReleases

#----------------------------------------------------------------------------
#
# Method:      setOurVersion
#
# Description: Set our version
#
# Arguments:
#  - Object reference
#  - Our version
# Returns:
#  -

sub setOurVersion($$) {
  # parameters
  my $self = shift;
  my ($ourVersion) = @_;

  $self->{our_version} = $ourVersion;
  return 0;
} # Method setOurVersion

#----------------------------------------------------------------------------
#
# Method:      getOurInstallation
#
# Description: Get information about our installation
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Test only: root directory
# Returns:
#  -

sub getOurInstallation($;$) {
  # parameters
  my $self = shift;
  my ($dir) = @_;

  # TODO We need to set this different for test
  $dir = $FindBin::RealBin
      unless ($dir);

  $self->{installed} =
    { dir     => $dir,
      files   => $NEW_FILES,
    };

  return 0;
} # Method getOurInstallation

#----------------------------------------------------------------------------
#
# Method:      checkForNewVersion
#
# Description: Check for a new version of tidbox
#
# Arguments:
#  - Object reference
# Returns:
#  undef    No new version exists
#  Version  Version of new release

sub checkForNewVersion($) {
  # parameters
  my $self = shift;


  my $ourVersion = $self->{our_version};
  my $newVersion = ${$self->{releases}{sorted}}[-1];

  # Are we already on latest version or later?
  unless ($self->byVersion($newVersion, $ourVersion) eq '1') {
    return undef;
  } # unless #



  $self->{new_version} = {version => $newVersion}
      if (defined($newVersion));

  return $newVersion;
} # Method checkForNewVersion

#----------------------------------------------------------------------------
#
# Method:      downloadNewVersion
#
# Description: Download a new release from GitHub
#
# Arguments:
#  - Object reference
# Returns:
#  Filename for downloaded file
#  undef if failed to download

sub downloadNewVersion($) {
  # parameters
  my $self = shift;


  # Remove old download
  $self->removeDownloadedArchive();

  # Download to a temporary file
  my ($fh, $filename) = tempfile( SUFFIX => TMPFILE_SUFFIX);

  my $version = $self->{new_version}{version};
  my $success = $self->{handler}->download($version, $filename);

  unless ($success) {
    # TODO Better error handling
    warn "Failed to download $version";
    return undef;
  } # unless #

  # Download OK, file
  $self->{new_version}{downloaded} = $filename;

  return $filename;
} # Method downloadNewVersion

#----------------------------------------------------------------------------
#
# Method:      prepareDirectoryNames
#
# Description: Prepare names of directories to use
#              - Extract directory where archive is extracted to
#              - Old directory where old version is moved
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub prepareDirectoryNames($) {
  # parameters
  my $self = shift;

  # Calculate directory to store restult in
  my $rootDir = $self->{installed}{dir};

  my $extractDir = File::Spec->catfile($rootDir, NEW_DIRECTORY_PREFIX);

  my $oldDir     = File::Spec->catfile($rootDir, OLD_DIRECTORY_PREFIX);

  # Save information
  $self->{installdir} =
    { extractdir        => $extractDir,
      olddir            => $oldDir,
    };

  return 0;
} # Method prepareDirectoryNames

#----------------------------------------------------------------------------
#
# Method:      prepareInstallDirectory
#
# Description: Prepare install directory for replacement of Tidbox
#              - Check that new and old directories not exists
#              - Create new and old directories
#              {installdir} saves path and status
#
# Arguments:
#  - Object reference
# Returns:
#  0 OK
#  1 Extract directory exists, schedule cleaning
# -1 Failed to create extract directory
#  2 Old directory exists, schedule cleaning
# -2 Failed to create old directory

sub prepareInstallDirectory($) {
  # parameters
  my $self = shift;


  my $rootDir    = $self->{installed}{dir};
  my $extractDir = $self->{installdir}{extractdir};
  my $oldDir     = $self->{installdir}{olddir};

  # Prepare extract directory to be used to extract into

  if (-e $extractDir) {
    # TODO Better failure handling needed
    warn "Can not create directory, $extractDir exists";
    return 1;
  } # if #

  # Do we have write access, create root directory?
  unless (mkdir($extractDir)) {
    # TODO Better failure handling needed
    warn "Failed to create directory $extractDir, no write access to $rootDir? : $!";
    return -1;
  } # unless #

  # Prepare old directory were our Tidbox will be saved
  if (-d $oldDir) {
    # TODO Old dir already exists
    warn "Directory already exists $oldDir";
    return 2;
  } # if #

  # Create old directory, check write access
  unless (mkdir($oldDir)) {
    $self->{installdir}{olddir_status} = 'readonly';
    # TODO No write access?
    warn "Failed to create directory $oldDir No write access to $rootDir: $!";
    return -2;
  } # unless #


  return 0;
} # Method prepareInstallDirectory

#----------------------------------------------------------------------------
#
# Method:      extractArchive
#
# Description: Extract new version from archive
#              Store extracted in tmp directory in Tidbox installation
#
# Arguments:
#  - Object reference
# Returns:
#  True if OK

sub extractArchive($) {
  # parameters
  my $self = shift;

  # Calculate directory to store restult in
  my $rootDir = $self->{installed}{dir};

  my $version = $self->{new_version}{version};

  my $extractDir = $self->{installdir}{extractdir};

  # Build an Archive::Extract object
  my $ae =
       Archive::Extract -> new( archive => $self->{new_version}{downloaded} );

  # Extract into directory
  my $ok = $ae -> extract( to => $extractDir );

  unless ($ok) {
    # TODO Something went wrong???
    warn $ae->error(1);
    return $ok;
  } # unless #

  # OK we successfully extracted the archive, remove the archive
  $self->removeDownloadedArchive();

  # Save information
  $self->{extracted} =
    {
      files        => $ae->files(),
      extract_path => $ae->extract_path(),
      result       => $ae->error(),
      ok           => $ok,
    };

  return $ok;
} # Method extractArchive

#----------------------------------------------------------------------------
#
# Method:      findExtractedTidbox
#
# Description: Find were tidbox.pl and lib is in extracted files list
#
# Arguments:
#  - Object reference
# Returns:
#  Directory name were both tidbpx.pl and lib are
#  undef if no directory found

sub findExtractedTidbox($) {
  # parameters
  my $self = shift;


  return undef
      unless (defined($self->{extracted}) and
              exists($self->{extracted}{files}));

  # Get files
  my $extracted_files = $self->{extracted}{files};

  my $found;
  my $dir;
  my $cnt = scalar(@{$NEW_FILES});
  for my $path (@{$extracted_files}) {
    for my $file (@{$NEW_FILES}) {
      my $len = length($file);
      if (substr($path, -$len) eq $file) {
        if (exists($found->{$file})) {
          # TODO error
          warn "File $file already found in list";
          return undef;
        } # if #
        my $ndir = substr($path, 0, -$len);
        if (defined($dir)) {
          if ($ndir ne $dir) {
            # TODO ERROR not same directory
            warn "Files are not in same directory";
            return undef
          } # if #
        } else {
          $dir = $ndir;
        } # if #
        $found->{$file} = $dir;
        $cnt--;
      } # if #
    } # for #

    # All found
    last
        if ($cnt == 0);

  } # for #

  # All files should be found
  if ($cnt > 0) {
    # TODO not all found
    warn "Not all files found";
    return undef;
  } # if #

  $self->{extracted}{tidboxdir} = $dir;
  $self->{extracted}{tidboxfiles} = $found;

  return $dir;
} # Method findExtractedTidbox

#----------------------------------------------------------------------------
#
# Method:      replaceTidboxScriptFilename
#
# Description: Filname for replace Tidbox script
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub replaceTidboxScriptFilename($) {
  # parameters
  my $self = shift;


  my $rootDir = File::Spec->canonpath($self->{installed}{dir});

  my $fileReplaceTidboxScript =
        File::Spec->catfile($rootDir, 'replace_tidbox.pl');

  return $fileReplaceTidboxScript;
} # Method replaceTidboxScriptFilename

#----------------------------------------------------------------------------
#
# Method:      prepareReplaceTidboxScript
#
# Description: Replace tidbox with new version
#              A replace script is created in the install directory
#              -  Replaces Tidbox
#                -  Move old version to directory old/<version>
#                -  Move new version from extracted archive to bindir
#              Makes the new Tidbox start if requested.
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Restart
# Returns:
#  -

sub prepareReplaceTidboxScript($;$) {
  # parameters
  my $self = shift;
  my ($restart) = @_;

  # Check if a new version is available for install
  return undef
     unless ($self->{extracted}{tidboxdir});

  # Values for replace script
  my $version = $self->{our_version};

  my $rootDir = File::Spec->canonpath($self->{installed}{dir});

  my $newDir = File::Spec->catfile($self->{installdir}{extractdir},
                                   $self->{extracted}{tidboxdir});
  my $newFiles = join(' ', @{$NEW_FILES});
  $newFiles =~ s"/""g;

  my $oldDir = $self->{installdir}{olddir};
  my $oldFiles_r = $self->{installed}{files};
  my $oldFiles = join(' ', @{$oldFiles_r});
# TODO Do we need this? Will we save it for later?
#  $self->{olddir} =
#    {
#      oldFiles   => $oldFiles_r,
#      oldVersion => $version,
#    };

  my $perl_exe;
  if ($restart) {
    # $^X perl executable, TODO see perldoc for sequrity concern
    $perl_exe = $^X;

  } else {
    # Ugly signal to replace script to not restart
    $perl_exe = 'exit';
    
  } # if #

  my $tidbox_cmd = $self->{args}{-call_string};
  my $tidbox_arg;
  if (ref($self->{args}{-argv})) {
    $tidbox_arg = "('" . join("', '", @{$self->{args}{-argv}}) . "')";
  } else {
    $tidbox_arg = "''";
  } # if #

  # Prepare replace_tidbox.pl script
  my @script = split(/\r?\n/, $REPLACE_TIDBOX_PL);

### Settings ####
#%rootDir%
#
#%newDir%
#%newFiles%
#
#%oldDir%
#%oldFiles%
#
#%perl_exe%
#%tidbox_cmd%
#%tidbox_arg%
### End Settings ####

  for my $line (@script) {
    last
        if ($line eq '### End Settings ####');
    $line =~ s/"/'/g;
    next
        if ($line =~ s/%rootDir%/$rootDir/);
    next
        if ($line =~ s/%newDir%/$newDir/);
    next
        if ($line =~ s/%newFiles%/$newFiles/);
    next
        if ($line =~ s/%oldDir%/$oldDir/);
    next
        if ($line =~ s/%oldFiles%/$oldFiles/);
    next
        if ($line =~ s/%perl_exe%/$perl_exe/);
    next
        if ($line =~ s/%tidbox_cmd%/$tidbox_cmd/);
    next
        if ($line =~ s/%tidbox_arg%/$tidbox_arg/);
  } # for #



  my $fileReplaceTidboxScript = $self->replaceTidboxScriptFilename();

  my $fh = FileHandle->new($fileReplaceTidboxScript, '>');
  # TODO Improve error handling
  unless($fh) {
    warn "Couldn't open file: $fileReplaceTidboxScript $!\n";
    return undef;
  } # unless #

  for my $line (@script) {
    $fh->print($line, "\n");
  } # for #

  $self->{installdir}{replace_script} = $fileReplaceTidboxScript;

  return $fileReplaceTidboxScript
      if ($fh->close());

  warn "Failed to close $fileReplaceTidboxScript $!";
  return undef;

} # Method prepareReplaceTidboxScript

#----------------------------------------------------------------------------
#
# Method:      removeFile
#
# Description: Remove file name by reference
#
# Arguments:
#  - Object reference
#  - Reference to file name
# Returns:
#  Undef if failed to remove

sub removeFile($$) {
  # parameters
  my $self = shift;
  my ($ref) = @_;


  return 0
      unless (${$ref});

  # An earlier download exists, remove it
  my $filename = ${$ref};
  ${$ref} = undef;
  my $cnt = unlink $filename;
  unless ($cnt) {
    warn "Failed to remove $filename $!";
    return undef;
  } # unless #

  return $cnt;
} # Method removeFile

#----------------------------------------------------------------------------
#
# Method:      removeDownloadedArchive
#
# Description: Remove temporary file with downloaded archive
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub removeDownloadedArchive($) {
  # parameters
  my $self = shift;


  # TODO Could we take care of cleaning tmpdir of failed earlier downloads

  return $self->removeFile(\$self->{new_version}{downloaded});
} # Method removeDownloadedArchive

#----------------------------------------------------------------------------
#
# Method:      removeReplaceTidboxScript
#
# Description: Remove srcipt that replaces Tidbox
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub removeReplaceTidboxScript($) {
  # parameters
  my $self = shift;


  return $self->removeFile(\$self->{installdir}{replace_script})
      if ($self->{installdir}{replace_script});

  # Remove script even when we don't have it referred to
  my $fileReplaceTidboxScript = $self->replaceTidboxScriptFilename();
  return $self->removeFile(\$fileReplaceTidboxScript)
      if (-f $fileReplaceTidboxScript);

  return undef;
} # Method removeReplaceTidboxScript

#----------------------------------------------------------------------------
#
# Method:      removeDirectoryTree
#
# Description: Remove a directory tree
#
# Arguments:
#  - Object reference
#  - Name of directory to remove
# Returns:
#  Reference to result hash

sub removeDirectoryTree($$) {
  # parameters
  my $self = shift;
  my ($directory) = @_;


  my $files_r = TbFile::Util->readDir($directory);

  return undef
      unless ($files_r);

  my $removed_count = File::Path->remove_tree($directory);

  my $result =
    {
      directory => $directory,
      files     => $files_r,
      count     => $removed_count,
    };

  return $result;
} # Method removeDirectoryTree

#----------------------------------------------------------------------------
#
# Method:      removeOldVersion
#
# Description: Remove an old version
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub removeOldVersion($) {
  # parameters
  my $self = shift;


  my $ref = $self->removeDirectoryTree($self->{installdir}{olddir});

  return undef
      unless ($ref);

  return $ref->{count};
} # Method removeOldVersion

#----------------------------------------------------------------------------
#
# Method:      removeExtractedDirectory
#
# Description: Remove directory where zip-file was extracted into
#
# Arguments:
#  - Object reference
# Returns:
#  -

sub removeExtractedDirectory($) {
  # parameters
  my $self = shift;


  my $ref = $self->removeDirectoryTree($self->{installdir}{extractdir});

  # No extracted Tidbox is available
  $self->{extracted}{tidboxdir} = undef;

  return undef
      unless ($ref);

  return $ref->{count};
} # Method removeExtractedDirectory

#----------------------------------------------------------------------------
#
# Method:      initialize
#
# Description: Set our version and installation directory
#              Get GitHub handler
#
# Arguments:
#  - Object reference
#  - Our version
# Optional Arguments:
#  - Test only: root directory
# Returns:
#  -

sub initialize($$;$) {
  # parameters
  my $self = shift;
  my ($ourVersion, $dir) = @_;


  # Set our version
  $self->setOurVersion($ourVersion);

  # Get our installation directory
  $self->getOurInstallation($dir);

  # Prepare directory names
  $self->prepareDirectoryNames();

  # Initialize handler
  $self->{handler}->initialize();

  return 0;
} # Method initialize

1;
__END__
