#
package Archive;
#
#   Document: Archive data
#   Version:  1.2   Created: 2011-03-13 07:21
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Archive.pmx
#

my $VERSION = '1.2';
my $DATEVER = '2011-03-13';

# History information:
#
# 1.0  2008-03-12  Roland Vallgren
#      First issue.
# 1.1  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
# 1.2  2011-03-12  Roland Vallgren
#      Use FileHandle for file handling
#

#----------------------------------------------------------------------------
#
# Setup
#
use parent TidBase;
use parent FileBase;

use strict;
use warnings;
use Carp;
use integer;

use EventCfg;
use Times;

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

use constant NO_DATE => '0000-00-00';

use constant FILENAME  => 'archive.dat';
use constant FILEKEY   => 'ARCHIVED TIME EVENTS';

use constant ARCHIVE_INFO      => 'ARCHIVE INFORMATION';
use constant INFO              => 1;
# date_time     : När arkiveringen gjordes
# start_date    : Första registrering i arkivet
# end_date      : Sista datum i arkivet

use constant ARCHIVE_EVENT_CFG => 'EVENT CONFIGURATION';
use constant EVNTC             => 2;
use constant ARCHIVE_TIMES     => 'REGISTERED TIME EVENTS';
use constant TIMES             => 3;
      

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create archive object
#
# Arguments:
#  0 - Object prototype
# Additional arguments as hash
#  -cfg        Reference to cfg data
# Returns:
#  Object reference

sub new($) {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = {
             };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

  return $self;
} # Method new

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all archive data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  %{$self->{sets}} = ();

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Read archive data from file
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

  my $a_r = $self->{sets};
  my $set;

  while (defined(my $line = $fh->getline())) {

    $line =~ s/\s+$//;

    if ($line =~ /^\[([-.\w\s]+)\]\s*$/) {
      if ($1 eq ARCHIVE_INFO) {

        # New archive set
        $set = {};

        while (defined($line = $fh->getline())) {
          # Load archive information
          if ($line =~ /^(\w+)=(.+?)\s*$/) {
            $set->{$1} = $2;
            if ($1 eq 'end_date') {
              unless (exists($self->{sets}{$2})) {
                $self->{sets}{$2} = $set;
              } else {
                carp "Duplicated archive set for date: $2";
              } # unless #

            } # if #
          } else {
            last;
          } # if #
        } # while #


      } elsif ($1 eq ARCHIVE_EVENT_CFG) {
        # Load EventCfg data
        $set->{event_cfg} = new EventCfg;
        $set->{event_cfg}->_load($fh);

      } elsif ($1 eq ARCHIVE_TIMES) {
        # Load times data
        $set->{times} = new Times;
        $set->{times}->_load($fh);

      } else {
        carp "Unknown type in archive: $1";

      } # if #


    } # if #

  } # while #

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _addSet
#
# Description: Add archive set to file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
#  2 - Set to add
# Returns:
#  -

sub _addSet($$$) {
  # parameters
  my $self = shift;
  my ($fh, $set) = @_;


  # Add set information
  $fh->print("\n" .
             '['. ARCHIVE_INFO. ']' . "\n" .
             'date_time='  , $set->{date_time}  , "\n" .
             'start_date=' , $set->{start_date} , "\n" .
             'end_date='   , $set->{end_date}   , "\n");

  # Add event configuration data
  $fh->print("\n" .
             '['. ARCHIVE_EVENT_CFG. ']' . "\n");
  $set->{event_cfg}->_save($fh);

  # Add times data
  $fh->print("\n" .
             '['. ARCHIVE_TIMES. ']' . "\n");
  $set->{times}->_save($fh);

  return 0;
} # Method _addSet

#----------------------------------------------------------------------------
#
# Method:      _append
#
# Description: Append archove set to file
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle
#  2 - Set to append
# Returns:
#  -

sub _append($$$) {
  # parameters
  my $self = shift;
  my ($fh, $set) = @_;


  $self->_addSet($fh, $set);

  return 0;
} # Method _append

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save archive data to file
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


  for my $key (sort(keys(%{$self->{sets}}))) {
    $self->_addSet($fh, $self->{sets}{$key});
  } # for #

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      getSets
#
# Description: Get dates of the archive sets
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Set to get date for
#  - Item to get from set
# Returns:
#  No date: A sorted array of archive set dates
#  Start date for set referred to by date

sub getSets($;$$) {
  # parameters
  my $self = shift;
  my ($date, $tag) = @_;

  return NO_DATE
      unless (exists($self->{sets}));
  return sort(keys(%{$self->{sets}}))
      unless $date;
  return NO_DATE
      unless (exists($self->{sets}{$date}));
  return $self->{sets}{$date}{$tag}
      if ($tag and exists($self->{sets}{$date}{$tag}));
  return $self->{sets}{$date}{start_date};
} # Method getSets

#----------------------------------------------------------------------------
#
# Method:      joinSets
#
# Description: Join selected set with previous
#
# Arguments:
#  0 - Object reference
#  1 - Date for set to join
# Returns:
#  -

sub joinSets($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  # Find previous set that should be joined
  my $p;
  for my $k (sort(keys(%{$self->{sets}}))) {
    last
        if ($date eq $k);
    $p = $k;
  } # for #

  return 0
      unless $p;

  my $set  = $self->{sets}{$date};
  my $prev = $self->{sets}{$p};

  # Move data to the target set
  $prev->{event_cfg} -> move($set->{event_cfg});
  $prev->{times}     -> move($set->{times});

  # Update information about the joined set
  $set->{date_time}  = $self->{-clock}->getDate() . ' ' .
                       $self->{-clock}->getTime();
  $set->{start_date} = $prev->{start_date};

  # And remove the moved set
  delete($self->{sets}{$p});

  $self->save(1);

  return 0;
} # Method joinSets

#----------------------------------------------------------------------------
#
# Method:      importSet
#
# Description: Import the selected set into the times and event cfg data
#
# Arguments:
#  0 - Object reference
#  1 - Date for set to import
# Returns:
#  -

sub importSet($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  return undef
      unless (exists($self->{sets}{$date}));

  # Set to import
  my $set = $self->{sets}{$date};

  # Move data to the active data
  $set->{event_cfg} -> move($self->{-event_cfg});
  $set->{times}     -> move($self->{-times});

  $self->{-event_cfg}->strings();

  $self->{-cfg} -> set('archive_date',
                       $self->{-calculate}->stepDate($set->{start_date}, -1)
                      );

  # And remove the imported set
  delete($self->{sets}{$date});

  $self->{-times}     -> save();
  $self->{-event_cfg} -> save();
  $self->{-cfg}       -> save();
  $self->save(1);

  return 0;
} # Method importSet

#----------------------------------------------------------------------------
#
# Method:      removeSet
#
# Description: Remove the selected archive set
#
# Arguments:
#  0 - Object reference
#  1 - Date for set to remove
# Returns:
#  -

sub removeSet($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  delete($self->{sets}{$date});
  $self -> finnish();

  return 0;
} # Method removeSet

#----------------------------------------------------------------------------
#
# Method:      archive
#
# Description: Add a period to the archive
#
# Arguments:
#  0 - Object reference
#  1 - End date of period to archive
# Returns:
#  -

sub archive($$) {
  # parameters
  my $self = shift;
  my ($end_date) = @_;


  # Create an archive set
  my $start_date = $self->{-cfg}->get('archive_date');
  $start_date = $self->{-calculate}->stepDate($start_date, 1)
      if ($start_date gt NO_DATE);

  # Create an archive set
  my $set = {
             date_time  => $self->{-clock}->getDate() . ' ' .
                           $self->{-clock}->getTime(),
             start_date => $start_date,
             end_date   => $end_date,
            };

  # Add event cfg data for archive set
  $set->{event_cfg} = new EventCfg(-archive => $end_date);
  $set->{event_cfg} ->
      configure(
                -cfg       => $self->{-cfg},
                -calculate => $self->{-calculate},
                -clock     => $self->{-clock},
               );

  $self->{-event_cfg} -> move($set->{event_cfg}, $end_date);

  # Add times data for archive set
  $set->{times} = new Times;
  $self->{-times}->move($set->{times}, $end_date);


  $self->{-cfg} -> set('archive_date', $end_date);

  if (exists($self->{sets}) or
      not $self->Exists()
     ) {
    # Creating the first set in memory, make the archive loaded
    $self->{sets}{$end_date} = $set;
    $self->{loaded} = 1;
    $self -> save(1);
  } else {
    $self -> append($set);
  } # if #

  # And finally save the active data
  $self->{-times}     -> save();
  $self->{-event_cfg} -> save();
  $self->{-cfg}       -> save();

  return 0;
} # Method archive

#----------------------------------------------------------------------------
#
# Method:      importData
#
# Description: Put imported archive data into a set
#
# Arguments:
#  - Object reference
#  - Reference archive set
# Returns:
#  -

sub importData($$) {
  # parameters
  my $self = shift;
  my ($set) = @_;


  $self->{sets}{$set->{end_date}} = $set;
  $self->dirty();

  return 0;
} # Method importData

1;
__END__
