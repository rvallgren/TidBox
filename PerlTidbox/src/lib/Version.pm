#
package Version;
#
#   Version:  1.6   Created: 2017-09-29
#   Prepared: Roland Vallgren
#
#   NOTE: Source code in Exco R6 format.
#         Exco file: Version.pmx
#

my $VERSION = '1.6';
my $DATEVER = '2017-09-29';

# Register version information
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
# 1.6  2017-04-19  Roland Vallgren
#      Changed format in component list
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
                       register_plugin_version
                       register_starttime
                       register_import
                       register_external
                      );
      }
our (@EXPORT_OK);

our %tool_info;

my %components;
my %plugins;
# TODO When needed # my @plugin_names;

# Version information
%tool_info = (
    title     => 'Arbetstid verktyg',
    icontitle => 'TidBox',
    date      => '2017-09-29',
    prepared  => 'Roland Vallgren',
    VERSION   => '4.10',
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
   'Insticksmoduler',
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

Retur i datum ändrar händelse om händelse är vald.
Om en redigering inte är sparad bekräfta att ändringen skall kastas.
Retur eller blanksteg i daglistan visar händelsen.
Starta redigera från veckodag, klicka på dagens namn.
Rullisten visas inte i lista med dagens aktiviteter om den inte behövs.
Ny funktion exporterar veckan till en fil.
Ångra senaste finns nu också i huvudfönstret.
Stöd för insticksmoduler (plugin) infört.
Tagit bort import av Tidbox data från Tidbox före utgåva 4.0
  Tidbox 4.0 är från oktober 2007.
MyTime insticksmodul ersätter Terp.
Normal veckosrbetstid är nu en generell inställning

'
,

#--------------- Felrättningar ---------------
'Felrättningar i denna version:

Ta bort senaste händelsedefinitionen uppdaterade inte till föregående
Huvudfönster utan daglista gick inte att avsluta
'
,


#------------------ Hemsida ------------------
\'https://social.intra.tieto.com/tibbr/#!/messages/mention/filters/Roland%20Vallgren'
,

#---------------- Komponenter ----------------
\%components
,

#---------------- Plug-ins -------------------
\%plugins
,

#----------------- Externals -----------------
#''  Externals is pushed on last

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
      sprintf('  =>  Version: %-6s  Datum: %s',
              $i{-version}, $i{-date}
             );
  return 0;
} # sub register_version

#----------------------------------------------------------------------------
#
# Function:    register_plugin_version
#
# Description: Register version of a plug-in
#
# Arguments:
#  0 - Information hash
#        -name     plugin name
#        -version  Version string, number
#        -date     Date when the version was created
# Returns:
#  -

sub register_plugin_version(%) {
  # parameters
  my (%i) = @_;

  $plugins{$i{-name}} =
      sprintf('  =>  Version: %6s  Datum: %s',
              $i{-version}, $i{-date}
             );
# TODO When needed #  push @plugin_names, $i{-name};
  return 0;
} # sub register_plugin_version

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
  push @{$tool_info{about}}, join("\n", @_);

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
