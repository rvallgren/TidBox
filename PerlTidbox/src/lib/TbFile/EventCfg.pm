#
package TbFile::EventCfg;
#
#   Document: Event Configuration Data
#   Version:  3.2   Created: 2018-12-07 17:49
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: EventCfg.pmx
#

my $VERSION = '3.2';
my $DATEVER = '2018-12-07';

# History information:

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
# 3.1  2017-09-14  Roland Vallgren
#      Added handling of plugin to define templates for EVENT_CFG
#      Removed Terp, handling moved to MyTime plugin
#      Removed support for import of earlier Tidbox data
# 3.2  2017-10-05  Roland Vallgren
#      Move files to TbFile::<file>
#      Added merge to add unique event cfg data into another EventCfg
#      Handle fixed condense setting in matchString
#

#----------------------------------------------------------------------------
#
# Setup
#
use base TidBase;
use base TbFile::Base;

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
    Enkel => [ 'Aktivitet:.:24',
             ],
    Avancerad => [ 'Proj:w:8',
                   'Typ:d:4',
                   'Art:r:-;+;Ö;KÖ;Res',
                   'Not:.:24',
                 ],
                );

# Event types definitions
#   Key:   Typ selection, stored in times.dat
#   Value: Reference to array with "Regexp", "Description", "Sort order"
my %types_def = (
                  A  => [ '[A-ZÅÄÖ]'       , 'Versaler (A-Ö)'           , 1 ],
                  a  => [ '[a-zåäöA-ZÅÄÖ]' , 'Alfabetiska (a-öA-Ö)'     , 2 ],
                  w  => [ '\\w'            , 'Alfanumerisk (a-ö0-9_)'   , 3 ],
                  W  => [ '[^,\n\r]'       , 'Text (ej ,)'              , 4 ],
                  d  => [ '\\d'            , 'Siffror (0-9)'            , 5 ],
                  D  => [ '[\\d\\.\\+\\-]' , 'Numeriska (0-9.+-)'       , 6 ],
                  r  => [ '[^,\n\r]'       , 'Radioknapp'               , 7 ],
                  R  => [ '[^,\n\r]'       , 'Radioknapp översätt'      , 8 ],
                 '.' => [ '[^\n\r]'        , 'Fritext'                  , 9 ],
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
# Returns:
#  Object reference

sub new($) {
  my $class = shift;
  $class = ref($class) || $class;
  my $self;

  $self = {
           -display => {},
           plugin_can   => {-template => undef},
          };

  bless($self, $class);

  $self->init(FILENAME, FILEKEY);

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
  @{$self->{cfg}} = @{$EVENT_CFG{Enkel}};
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
# Method:      move
#
# Description: Move event configuration to an event cfg object
#              If no last date or first is specified all data is moved
#
# Arguments:
#  - Object reference
#  - Reference to event configuration object to move to
# Optional Arguments:
#  - Last date of to move
#  - First date of to move
# Returns:
#  -

sub move($$;$$) {
  # parameters
  my $self = shift;
  my ($target, $last_date, $first_date) = @_;


  # Move all data after first date and before last date
  my $cfg_r;
  my $before;
  for my $date (sort(keys(%{$self->{earlier}}))) {
    if (defined($first_date) and $date lt $first_date) {
      $before = $date;
      next;
    } # if #
    $cfg_r = $self->{earlier}{$date};
    if (defined($last_date) and $date gt $last_date) {
      # Copy last data and set date to last date
      $self->{earlier}{$last_date} = [ @$cfg_r ];
      $self->{strings}{$last_date} = _text_strings($cfg_r);
      last;
    } # if #

    $target->addSet('cfg', $cfg_r, $date);
    delete($self->{earlier}{$date});

    # Do we really need to clear this?
    delete($self->{strings}{$date});

  } # for #

  if (defined($before) and not exists($self->{earlier}{$first_date})) {
    # Add data for first data
    $target->addSet('cfg',  [ @{$self->{earlier}{$before}} ], $first_date);
  } # if #

  if (defined($last_date) and $self->{date} le $last_date) {
    $target->addSet('cfg', [ @{$self->{cfg}} ], $self->{date});
    $self->{date} = $last_date;
  } # if #

  $self   -> dirty();
  $target -> dirty();

  return 0;
} # Method move

#----------------------------------------------------------------------------
#
# Method:      _mergeData
#
# Description: Merge event configuration from an event cfg, skip event cfg
#              on the same date
#
# Arguments:
#  - Object reference
#  - Source object to merge from
#  - Start Date
#  - End Date
# Optional Arguments:
#  - Reference to progress handling hash
# Returns:
#  -

sub _mergeData($$$$;$) {
  # parameters
  my $self = shift;
  my ($source, $startDate, $endDate, $progress_ref) = @_;

  $self->{erefs}{-log}->trace('Start date and end date:',
                              $startDate, $endDate)
      if ($self->{erefs}{-log});

  # Merge all data or up to date to merge is later than actual
  # event configuration date

  my ($tdate, $tcfg) = $self->getDateEventCfg();
  my $earlier = $source->getEarlierEventCfg();

  # Progress bar handling
  my $sProgressSteps;
  my $sProgressCnt;
  my $si = 0;
  my $tProgressSteps;
  my $tProgressCnt;
  my $ti = 0;
  if ($progress_ref) {
    $sProgressSteps =
      ( (scalar(keys(%{$earlier})) + 1) / $progress_ref->{-percent_part} ) || 1;
    $sProgressCnt = 0;
    $tProgressSteps =
      ( (scalar(keys(%{$self->{earlier}})) + 1) /
                   $progress_ref->{-percent_part} ) || 1;
    $tProgressCnt = 0;
  } # if #

  # Add all earlier data and clear earlier
  for my $date (keys(%{$earlier})) {
    $self->{erefs}{-log}->trace('Check earlier date:', $date)
        if ($self->{erefs}{-log});

    $si++;
    if ($progress_ref) {
      $self->{erefs}{-log}->trace('Progress EventCfg S:', $si, 'T:', $ti)
          if ($self->{erefs}{-log});
#      if ($sProgressSteps > $tProgressSteps) {
        if ($si > $sProgressCnt) {
          $self->callback(@{$progress_ref->{-callback}});
          $sProgressCnt += $sProgressSteps;
        } # if #
#      } else {
#        if ($ti > $tProgressCnt) {
#          $self->callback(@{$progress_ref->{-callback}});
#          $tProgressCnt += $tProgressSteps;
#        } # if #
#      } # if #
    } # if #


    next
        if ($date lt $startDate);
    next
        if ($date gt $endDate);
    next
        if ($date eq $tdate);
    unless (exists($self->{earlier}{$date})) {
      $self->{erefs}{-log}->trace('==> Add earlier')
          if ($self->{erefs}{-log});
      $self->addSet('cfg', [ @{$earlier->{$date}} ], $date);
      $source->removeCfg($date);
    } # unless #
  } # for #

  #   Copy actual data to target set and update date
  my ($date, $cfg) = $source->getDateEventCfg();
  $self->{erefs}{-log}->trace('Check actual date:', $date)
      if ($self->{erefs}{-log});
  return 0
      if ($date lt $startDate);
  return 0
      if ($date gt $endDate);
  return 0
      if ($date eq $tdate);
  unless (exists($self->{earlier}{$date})) {
    $self->{erefs}{-log}->trace('==> Add actual')
        if ($self->{erefs}{-log});
    $self->addSet('cfg', [ @{$cfg} ], $date);
    $source->removeCfg($date);
  } # unless #

  return 0;
} # Method _mergeData

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

  my $tpt = { %EVENT_CFG };
  while (my ($name, $ref) = each(%{$self->{plugin}})) {
    if (exists($ref->{-template})) {
      my $evref = $self->callback($ref->{-template});
      while (my ($key, $val) = each(%{$evref})) {
        $tpt->{$key} = $val;
      } # while #
    } # if #
  } # while #
  return $tpt;
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
#  -1 if less than
#  0 if equal
#  1 if greater than

sub compareCfg($$;$) {
  # parameters
  my $self = shift;
  my ($r1, $r2) = @_;

  return (join('', @$r1) cmp join('', @$r2))
      if ($r2);
  return (join('', @$r1) cmp join('', @{$self->{cfg}}));
} # Method compareCfg

#----------------------------------------------------------------------------
#
# Method:      addCfg
#
# Description: Add active event configuration setting
#              Add is not done if setting is equal to active setting
#
# Arguments:
#  - Object reference
#  - Reference to event cfg data
#  - Date
# Returns:
#  -

sub addCfg($$$) {
  # parameters
  my $self = shift;
  my ($set, $date) = @_;


  # Is it equal to active? Do not record the change
  return 0
      unless ($self->compareCfg($set));

  if ($date gt $self->{date}) {
    # Push the active to earlier
    $self->{earlier}{$self->{date}} = $self->{cfg};
    $self->{strings}{$self->{date}} = $self->{str};
    $self->{cfg} = [];
    $self->{date} = $date;
  } # if #
  @{$self->{cfg}} = @{$set};
  $self->{str} = _text_strings($self->{cfg});
  # TODO Is it OK that settings call save()
  #      I thought we should set dirty here.

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
#  - Object reference
#  - Condense setting
#      >0 Condense by value
#      <0 Condense to selected number of fields
# Optional Arguments:
#  - Date to get string for
# Returns:
#  - Event match regexp
#  - Adjusted condense setting, if too big

sub matchString($$;$) {
  # parameters
  my $self = shift;
  my ($condense, $date) = @_;


  my ($cfg_r, $str_r) = $self->getEventCfg($date);

  my $event_no;
  if ($condense < 0) {
    if ($#{$cfg_r} > -$condense) {
      $event_no = -$condense;
    } else {
      $event_no = $#{$cfg_r};
      $condense = $event_no;
    } # if #
  } elsif ($#{$cfg_r} > $condense) {
    $event_no = @{$cfg_r} - $condense;
  } else {
    $event_no = $#{$cfg_r};
    $condense = $event_no;
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
      push @values,
        substr($ev_r->{-sz_values}[0], index($ev_r->{-sz_values}[0], '=>')+2);
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
