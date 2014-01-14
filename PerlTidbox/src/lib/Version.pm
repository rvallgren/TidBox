#
package Version;
#
#   Version:  1.5   Created: 2013-05-27
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Version.pmx
#

my $VERSION = '1.5';
my $DATEVER = '2013-05-27';

# Register version information
sub register_version(%);
{
  register_version(-name    => __PACKAGE__,
                   -version => $VERSION,
                   -date    => $DATEVER,
                  );
}
# History information:
#
# 1.0  2007-03-25  Roland Vallgren
#      First issue.
# 1.1  2007-09-08  Roland Vallgren
#      Use reference to string to allow Tidbox URL to be copied.
#      Added perl version to tool_info
#      Use NoteBook layout of confirm window
# 1.3  2008-09-13  Roland Vallgren
#      Preparing for 4.2
#      Added prepared in About tab
# 1.4  2011-03-20  Roland Vallgren
#      Copyright information more perl
#      Dynamic session information
# 1.5  2013-05-18  Roland Vallgren
#      Handle session lock
#

#----------------------------------------------------------------------------
#
# Setup
#
use strict;
use warnings;
use Carp;
use integer;

# Export tool info
BEGIN {
       use Exporter ();
       our (@ISA, @EXPORT_OK);
       @ISA = qw(Exporter);
       # symbols to export on request
       @EXPORT_OK = qw(%tool_info
                       register_version
                       register_starttime
                       register_import
                       register_external
                      );
      }
our (@EXPORT_OK);

our %tool_info;


my %components;

# Version information
%tool_info = (
    title     => 'Arbetstid verktyg',
    icontitle => 'TidBox',
    date      => '2013-05-27',
    prepared  => 'Roland Vallgren',
    VERSION   => '4.7',
);
$tool_info{version} =
   "$tool_info{icontitle} Version: $tool_info{VERSION} $tool_info{title}";
$tool_info{year} = substr($tool_info{date}, 0, 4);

#----------------------------------------------------------------------------
#
# Define about
#
$tool_info{about_head} = [
   'Om',
   'Nyheter',
   'Felrättningar',
   'Hemsida',
   'Komponenter',
   'Externt',
                         ];
$tool_info{about} = [
# Version and Starttime
$tool_info{title} . "  :  " . $tool_info{icontitle} .
   "  Version: " . $tool_info{VERSION} .
"\n  Uppgjord: " . $tool_info{prepared} .
"\n  Datum: " . $tool_info{date} .
"\n" .
"\n  Copyright (c) " . $tool_info{year} . ' ' . $tool_info{prepared} . " All rights reserved" .
"\n  This program is free software. It may be used, redistributed" .
"\n  and/or modified under the same terms as Perl itself. "
,

#  >>>>>>>>>> Nyheter i denna version: <<<<<<<<<
'Nyheter i denna version:

Anpassningar för Perl 5.16
Tidbox skapar en låsfil, en andra Tidbox körs med enbart läsning
Tidbox laddas ner från intra
'
,

#--------------- Felrättningar ---------------
'Felrättningar i denna version:

Försök inte rotera loggen på backup om ingen backup används.
Ta bort i main kontrollerar lås.
Ändring av inställningar för händelser ej tillåtet för låsta veckor.
'
,

#------------------ Hemsida ------------------
\'http://intra.tieto.com/profile/vallgrol'
,

#---------------- Komponenter ----------------
\%components
,

#----------------- Externals -----------------
''
,

];

#----------------------------------------------------------------------------
#
# Function:    register_version
#
# Description: Register version of a package, module, class, etc.
#
# Arguments:
#  0 - Information hash
#        -name     package name
#        -version  Version string, number
#        -date     Date when the version was created
# Returns:
#  -

sub register_version(%) {
  # parameters
  my (%i) = @_;

  $components{$i{-name}} =
                  '  =>  Version: ' . $i{-version} .
                     '  Datum: ' . $i{-date} ;

  return 0;
} # sub register_version

#----------------------------------------------------------------------------
#
# Function:    register_starttime
#
# Description: Register starttime in About data
#
# Arguments:
#  0 - Date
#  1 - Time
# Returns:
#  -

sub register_starttime($$) {
  # parameters
  my $class = shift;
  my ($d, $t) = @_;

  $tool_info{about}[0] .= "\n\nSessionen startades\n  Datum: " . $d .
                          "\n  Klockan: " . $t;

  return 0;
} # sub register_starttime

#----------------------------------------------------------------------------
#
# Function:    register_import
#
# Description: Register import information
#
# Arguments:
#  - Version information
#  - File format information
# Returns:
#  -

sub register_import($$) {
  # parameters
  my ($v, $f) = @_;

  $tool_info{about}[0] .=
     "\nImporterade Tidbox-data från:\n" .
     "  TidBox Version: " . $v . "\n" .
     "  Filformat: " . $f . "\n"
     ;

  return 0;
} # sub register_import

#----------------------------------------------------------------------------
#
# Function:    register_external
#
# Description: Register external dependencies information
#
# Arguments:
#  - Version information
# Returns:
#  -

sub register_external(@) {
  $tool_info{about}[5] = join("\n", @_);

  return 0;
} # sub register_external

#----------------------------------------------------------------------------
#
# Function:    register_locked_session
#
# Description: Register a lock of the session
#
# Arguments:
#  - Lock string
# Returns:
#  -

sub register_locked_session($) {
  # parameters
  my $class = shift;
  my ($s) = @_;

  $tool_info{about}[0] .= "\n\n" . $s
      if ($s);
  return 0;
} # sub register_locked_session


1;
__END__
