#
package EventCfg;
#
#   Document: Event Configuration Data
#   Version:  3.0   Created: 2016-04-22 17:41
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: EventCfg.pmx
#

my $VERSION = '3.0';
my $DATEVER = '2016-04-22';

# History information:

# PA1  2006-07-22  Roland Vallgren
#      First issue.
# PA2  2006-10-27  Roland Vallgren
#      Corrected error in add and remove event cfg
# PA3  2006-11-18  Roland Vallgren
#      Radiobutton change is treated as text entry
#      Allow settings window to be withdrawn
# PA4  2006-11-27  Roland Vallgren
#      Update event cfg area in settings window
# PA5  2007-02-11  Roland Vallgren
#      Matching date uses constant
# PA6  2007-03-09  Roland Vallgren
#      Event cfg now show edit settings below the list
# 1.7  2007-03-25  Roland Vallgren
#      Numerical versions, Local module information added
# 1.8  2007-06-17  Roland Vallgren
#      Date for event cfg is kept for event area
#      Allow radiobutton to be undef when cleared
# 1.9  2008-04-05  Roland Vallgren
#      Added archive handling
# 1.10  2008-07-01  Roland Vallgren
#       Added advanced radio button
# 2.0  2008-12-06  Roland Vallgren
#      Use Exco %+ to use same source to register version
#      Use FileBase functions to save and load
# 2.1  2009-07-08  Roland Vallgren
#      Precompile regexp match string
# 2.2  2010-01-04  Roland Vallgren
#      New entry gets label "Ny" to avoid empty label.
# 2.3  2011-02-12  Roland Vallgren
#      "\r" and "\n" not allowed in text entry
#      Added quit to disable area
# 2.4  2011-06-02  Roland Vallgren
#      Corrected modifyArea to update date even though are not is replaced.
# 2.5  2012-08-19  Roland Vallgren
#      New method getEmpty returns an emty event, like clearData
# 2.6  2012-09-10  Roland Vallgren
#      Not allowed to change event cfg for locked weeks
# 2.7  2015-11-04  Roland Vallgren
#      Configuration.pm should not have any Gui code
# 3.0  2015-12-07  Roland Vallgren
#      Event gui moved to own perl module
#      Do not add cfg if equal to previous
#      New method removeCfg
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base FileBase;

use strict;
use warnings;
use Carp;
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



# Event configuration: Default
use constant EVENT_START => '0000-00-00';

my %EVENT_CFG = (
    COPERNICUS => [ 'Proj:w:8',
                    'Typ:d:4',
                    'Art:r:-;+;Ö;KÖ;Res',
                    'Not:.:24',
                  ],
    ENKEL => [ 'Aktivitet:.:24',
             ],
    TERP => [ 'Project:d:6',
              'Task:D:6',
              'Type:R:' .
                'N'  . '=>'. 'Normal -SE'                          . ';' .
                'F+' . '=>'. 'Normal /flex -SE'                    . ';' .
                'Ö+' . '=>'. 'Overtime Single /saved -SE-Overtime' . ';' .
                'Res'. '=>'. 'Travelling I /paid -SE-Overtime'     . ';' .
                'F-' . '=>'. 'Normal /used flex timi -SE'          . ';' .
                'Ö-' . '=>'. 'Compensation for Overtime -SE'       . ';' .
                'Sem'. '=>'. 'Vacation -SE'                                ,
              'Details:.:24',
            ],
                );

# Event types definitions
#   Key:   Typ selection, stored in times.dat
#   Value: Reference to array with "Regexp", "Description", "Sort order"
my %types_def = (
                  A  => [ '[A-ZÅÄÖ]'        , 'Versaler (A-Ö)'           , 1 ],
                  a  => [ '[a-zåäöA-ZÅÄÖ]'  , 'Alfabetiska (a-öA-Ö)'     , 2 ],
                  w  => [ '\\w'             , 'Alfanumerisk (a-ö0-9_)'   , 3 ],
                  W  => [ '[^,\n\r]'        , 'Text (ej ,)'              , 4 ],
                  d  => [ '\\d'             , 'Siffror (0-9)'            , 5 ],
                  D  => [ '[\\d\\.\\+\\-]'  , 'Numeriska (0-9.+-)'       , 6 ],
                  r  => [ '[^,\n\r]'        , 'Radioknapp'               , 7 ],
                  R  => [ '[^,\n\r]'        , 'Radioknapp översätt'      , 8 ],
                 '.' => [ '[^\n\r]'         , 'Fritext'                  , 9 ],
                );

use constant FILENAME  => 'eventcfg.dat';
use constant FILEKEY   => 'EVENT CONFIGURATION';

#############################################################################
#
# Function section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Function:    _text_strings
#
# Description: Create the event text strings
#
# Arguments:
#  0 - Reference to event configuration array
# Returns:
# A reference to an array with one hash of settings per event configuration
#  0 - Label
#  1 - Type definition
#  2 - Size or radio button values
#  3 - Event cfg text key
#  4 - Event cfg data key
#  5 - Event cfg radio key

sub _text_strings($) {
  my ($cfg_r) = @_;

  my $list = [];
  my $num = 0;
  for my $ev_st (@$cfg_r) {
    my ($text, $type, $sz_values) = split(':', $ev_st);
    $sz_values = [split(';', $sz_values)] if ($type eq 'r');
    $sz_values = [split(';', $sz_values)] if ($type eq 'R');
    push  @$list, { -text        => $text,
                    -type        => $type,
                    -sz_values   => $sz_values,
                    -cfgev_text  => 'cfgevtx_' . $num,
                    -cfgev_data  => 'cfgevdt_' . $num,
                    -cfgev_radio => 'cfgevrd_' . $num,
                  };
    $num++;
  } # for #

  return $list
} # sub _text_strings

#############################################################################
#
# Method section
#
#############################################################################

#----------------------------------------------------------------------------
#
# Method:      new
#
# Description: Create new event configuration data
#              If used in an archive set slightly limitied
#              TODO: Subclass archive?
#
# Arguments:
#  0 - Object prototype
# Optional arguments hash:
#  -archive - Start date for archive set
# Returns:
#  Object reference

sub new($%) {
  my $class = shift;
  $class = ref($class) || $class;
  my %args = @_;
  my $self;

  unless ($args{-archive}) {

    $self = {
             -display => {},
            };

    bless($self, $class);

    $self->init(FILENAME, FILEKEY);

  } else {
    $self = {archive    => $args{-archive}  ,
            };

    bless($self, $class);

    $self->init(undef, FILEKEY);

  } # unless #

  return ($self);
} # Method new

#----------------------------------------------------------------------------
#
# Method:      strings
#
# Description: Add event configuration data strings
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub strings($) {
  # parameters
  my $self = shift;

  $self->{str} = _text_strings($self->{cfg});
  for my $key (%{$self->{earlier}}) {
    $self->{strings}{$key} = _text_strings($self->{earlier}{$key});
  } # for #

  return 0;
} # Method strings

#----------------------------------------------------------------------------
#
# Method:      _clear
#
# Description: Clear all event configuration data
#
# Arguments:
#  0 - Reference to object hash
# Returns:
#  -

sub _clear($) {
  # parameters
  my $self = shift;


  $self->{date} = EVENT_START;
  @{$self->{cfg}} = @{$EVENT_CFG{TERP}};
  %{$self->{earlier}} = ()
      if (exists($self->{earlier}));
  $self->strings();

  return 0;
} # sub _clear

#----------------------------------------------------------------------------
#
# Method:      _load
#
# Description: Load event configuration
#
# Arguments:
#  0 - Object reference
#  1 - Filhandle to load from
# Returns:
#  0 = Success

sub _load($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->loadDatedSets($fh, 'cfg');

  $self->strings();

  return 1;
} # Method _load

#----------------------------------------------------------------------------
#
# Method:      _save
#
# Description: Save event cfg data to file
#
# Arguments:
#  0 - Object reference
#  1 - Filehandle
# Returns:
#  -

sub _save($$) {
  # parameters
  my $self = shift;
  my ($fh) = @_;


  $self->saveDatedSets($fh, 'cfg');

  return 0;
} # Method _save

#----------------------------------------------------------------------------
#
# Method:      importData
#
# Description: Put imported event configuration data
#
# Arguments:
#  - Object reference
#  - Date
#  - Reference to event cfg data
# Returns:
#  -

sub importData($$$) {
  # parameters
  my $self = shift;
  my ($date, $cfg_r) = @_;


  $self->addSet('cfg', $cfg_r, $date);
  $self->dirty();

  return 0;
} # Method importData

#----------------------------------------------------------------------------
#
# Method:      move
#
# Description: Move event configuration to an event cfg object
#              If no last date is specified all data is moved
#
# Arguments:
#  0 - Object reference
#  1 - Reference to event configuration object to move to
# Optional Arguments:
#  2 - Last date of to move
# Returns:
#  -

sub move($$;$) {
  # parameters
  my $self = shift;
  my ($target, $last_date) = @_;


  if (not defined($last_date) or ($last_date ge $self->{date})) {

    # Move all data or up to date to move is later than actual
    # event configuration date

    #   Archive all earlier data and clear earlier
    for my $date (keys(%{$self->{earlier}})) {
      $target->addSet('cfg', $self->{earlier}{$date}, $date);
    } # for #

    #   Copy actual data to target set and update date
    $target->addSet('cfg', [ @{$self->{cfg}} ], $self->{date});

    # Clear earlier data
    %{$self->{earlier}} = ();

    # Do we really need to clear this?
    %{$self->{strings}} = ();

    if (defined($last_date)) {
      $self->{date} = $last_date;
      $self->{strings}{$last_date} = _text_strings($self->{cfg});

    } else {
      @{$self->{cfg}} = ();

    } # if #

  } else {

    # Archive and clear all data before last date
    my $cfg_r;
    for my $date (sort(keys(%{$self->{earlier}}))) {
      if ($last_date ge $date) {
        $cfg_r = $self->{earlier}{$date};
        $target->addSet('cfg', $cfg_r, $date);
        delete($self->{earlier}{$date});

        # Do we really need to clear this?
        delete($self->{strings}{$date});
      } # if #
    } # for #

    # Copy last data and set date to last date
    $self->{earlier}{$last_date} = [ @$cfg_r ];
    $self->{strings}{$last_date} = _text_strings($cfg_r);

  } # if #

  $self   -> dirty();
  $target -> dirty();

  return 0;
} # Method move

#----------------------------------------------------------------------------
#
# Method:      getEventCfg
#
# Description: Get event configuration for a date
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - Date
# Returns:
#  -

sub getEventCfg($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;

  unless ($date and
          ($date lt $self->{date}) and
           exists($self->{earlier})
         ) {
    return ($self->{cfg}, $self->{str}) if wantarray();
    return $self->{cfg};
  } # unless #

  my $found = EVENT_START;
  for my $d (sort(keys(%{$self->{earlier}}))) {
    last if $d gt $date;
    $found = $d;
  } # for #

  return ($self->{earlier}{$found}, $self->{strings}{$found})
     if wantarray();
  return $self->{earlier}{$found};
} # Method getEventCfg

#----------------------------------------------------------------------------
#
# Method:      getEarlierEventCfg
#
# Description: Get earlier event cfg
#
# Arguments:
#  - Object reference
# Returns:
#  - Referense to earlier hash

sub getEarlierEventCfg($) {
  # parameters
  my $self = shift;

  return $self->{earlier};
} # Method getEarlierEventCfg

#----------------------------------------------------------------------------
#
# Method:      getDateEventCfg
#
# Description: Get current event configuration and start date
#
# Arguments:
#  0 - Object reference
# Returns:
#  - Reference to array with date and event configuration

sub getDateEventCfg($) {
  # parameters
  my $self = shift;

  return ($self->{date}, $self->{cfg});
} # Method getDateEventCfg

#----------------------------------------------------------------------------
#
# Method:      getNum
#
# Description: Get number of configuration data
#              If a date is specified the configuration data for that day
#              is returned
#
# Arguments:
#  0 - Object reference
# Optional arguments:
#  1 - Date to get for
# Returns:
#  Length of array in scalar mode

sub getNum($;$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  my $cfg_r = $self->getEventCfg($date);

  return scalar(@{$cfg_r});
} # Method getNum

#----------------------------------------------------------------------------
#
# Method:      getDefinition
#
# Description: Get Event configuration definition
#                Default: return reference to %types_def
#
# Arguments:
#  - Object reference
# Optional Arguments:
#  - get reference to %EVENT_CFG
# Returns:
#  Reference to the required definition

sub getDefinition($;$) {
  # parameters
  my $self = shift;
  my ($event_cfg) = @_;


  return \%types_def
      unless (defined($event_cfg));
  return \%EVENT_CFG;
} # Method getDefinition

#----------------------------------------------------------------------------
#
# Method:      compareCfg
#
# Description: Compare two CFG
#              Compare with current cfg if only one provided
#
# Arguments:
#  - Object reference
#  - Reference to event cfg data
# Optional Arguments:
#  - Reference to event cfg data
# Returns:
#  1 if equal

sub compareCfg($$;$) {
  # parameters
  my $self = shift;
  my ($r1, $r2) = @_;

  return (join('', @$r1) eq join('', @$r2))
      if ($r2);
  return (join('', @$r1) eq join('', @{$self->{cfg}}));
} # Method compareCfg

#----------------------------------------------------------------------------
#
# Method:      addCfg
#
# Description: Add one event configuration setting
#
# Arguments:
#  - Object reference
#  - Date
#  - Reference to event cfg data
# Returns:
#  -

sub addCfg($$$) {
  # parameters
  my $self = shift;
  my ($date, $ref) = @_;


  if ($self->compareCfg($ref)) {
    return 0;
  } # if #

  if ($date gt $self->{date}) {
    $self->{earlier}{$self->{date}} = $self->{cfg};
    $self->{strings}{$self->{date}} = $self->{str};
    $self->{cfg} = [];
    $self->{date} = $date;
  } # if #
  @{$self->{cfg}} = @{$ref};
  $self->{str} = _text_strings($self->{cfg});

  return 1;
} # Method addCfg

#----------------------------------------------------------------------------
#
# Method:      removeCfg
#
# Description: Remove one event configuration setting
#
# Arguments:
#  - Object reference
#  - Date
# Returns:
#  -

sub removeCfg($$) {
  # parameters
  my $self = shift;
  my ($date) = @_;


  if ($date eq $self->{date}) {
    my @prev_dates = sort(keys(%{$self->{earlier}}));
    my $pdate = $prev_dates[0];
    $self->{date} = $pdate;
    $self->{cfg} = $self->{earlier}{$pdate};
    $self->{str} = $self->{strings}{$pdate};
    delete($self->{earlier}{$pdate});
    delete($self->{strings}{$pdate});
  } else {
    delete($self->{earlier}{$date});
    delete($self->{strings}{$date});
  } # if #

  $self->dirty();

  return 1;
} # Method removeCfg

#----------------------------------------------------------------------------
#
# Method:      matchString
#
# Description: Create a regexp string for matching event configuration
#
# Arguments:
#  0 - Object reference
#  1 - Condense setting
# Optional Arguments:
#  1 - Date to get string for
# Returns:
#  0 - Event match regexp
#  1 - Adjusted condense setting, if too big

sub matchString($$;$) {
  # parameters
  my $self = shift;
  my ($condense, $date) = @_;


  my ($cfg_r, $str_r) = $self->getEventCfg($date);

  my $event_no;
  if ($#{$cfg_r} > $condense) {
    $event_no = @{$cfg_r} - $condense;
  } else {
    $event_no = 1;
    $condense = $#{$cfg_r};
  } # if #

  my $match_string = '(';
  for my $ev_r (@{$str_r}) {
    my $type = $ev_r->{-type};
    $match_string .= $types_def{$type}[0] . '*';
    last if ($type eq '.');

    $event_no--;
    $match_string .= ($event_no ? ',' : '),(' );
  } # for #
  $match_string .= ')';
  # And finally compile regexp
  $match_string = qr/^$match_string$/;

  return ($match_string, $condense) if wantarray();
  return $match_string;
} # Method matchString

#----------------------------------------------------------------------------
#
# Method:      getEmpty
#
# Description: Get an empty data for today.
#              A comment may be provided.
#
# Arguments:
#  0 - Object reference
# Optional argument:
#  1 - Comment
# Returns scalar:
#  0 - Event data.

sub getEmpty($;$) {
  # parameters
  my $self = shift;
  my ($comment) = @_;


  my @values;
  my $r;
  for my $ev_r (@{$self->{str}}) {
    if (lc($ev_r->{-type}) ne 'r') {
      push @values, '';
    } elsif ($ev_r->{-type} eq 'R') {
      push @values, substr($ev_r->{-sz_values}[0], index($ev_r->{-sz_values}[0], '=>')+2);
    } else {
      push @values, $ev_r->{-sz_values}[0];
    } # if #
    $r = $ev_r;
  } # for #
  $values[$#values] = $comment
      if ($comment and lc($r->{-type}) ne 'r');

  return join(',', @values);
} # Method getEmpty

#----------------------------------------------------------------------------
#
# Method:      notifyClients
#
# Description: Notify clients of changes in event configuration
#
# Arguments:
#  0 - Object reference
# Returns:
#  -

sub notifyClients($@) {
  # parameters
  my $self = shift;

  $self->_doDisplay(@_);
  return 0;
} # Method notifyClients

1;
__END__
