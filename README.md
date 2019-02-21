# Tidbox

Register time as input for time reporting.

## Basic time calculation

Time is either work time or not work time, that is pause. Only work time is registered.
However pause time during a workday, for example lunch, is accumulated.

Register start time of an activity or pause.

Next registered time, an activity or a pause, is considered end of an activity.

The work time for an activity is calculated from start time to end time.
If the same activity is repeated several times during a workday, the time for each are added.

The work time for an activity is accumulated for a day and reported in hours and decimal hours.

The accumulated data can be exported to a .csv file or a Excel file. These
are mainly intended to import in a time reporting system.

NOTE: Tidbox is in Swedish.

## Tidbox

The main window is for time registration today and basic editing.

Week window calculates the work time for the week.

The edit window is for advanced editing.

## Time

Time is entered in hour and minute, for example `15:23`.

Delta time is calculated, for example: `15:00+30` is evaluated to `15:30`.

Delta time can be specified in tenths of hours, for example: `8:00+1,5` is evaluated to `09:30`.

If a time is entered without separators the value an attempt to guess what the was attempted: `98` is evaluated to `09:08`

---
## Installation of Tidbox Perl version

Perl implementation of Tidbox is stored in `PerlTidbox/src`:
- `tidbox.pl` : Main program
- `lib` : Perlmodules

Extract these into a directory were you have write access for example
- Windows: `<username>\Tidbox`
- Unix: `$HOME/Tidbox`

Note: From release `4.12` Tidbox downloads new version and updates itself
      if it has write access

### Startup

`<Path to Perl>\wperl.exe` `<Path to Tidbox>\tidbox.pl`

## Perl

Tidbox is verified with:
- `Strawberry Perl 5.28.1.1`
- `Perl/Tk VERSION 804.034`

For Windows the following install procedure is used to install Perl and Perl/Tk:

- Download Strawberry Perl 5.28.1.1 portable from http://strawberryperl.com/

- Extract the zip-file into for example: `C:\StrawberryPerl5.28.1.1`
  NOTE: Choose a directory name without spaces and non us-ascii characters
  NOTE: It is recommended to use 7zip to extract

- Launch `C:\StrawberryPerl5.28.1.1\portableshell.bat` -
  it should open a command prompt window

- Install Perl/Tk:
  `ppm install Tk`

---
## Java implementation

The Java implementation of Tidbox is on hold.

### TidBox

The functional code of TidBox

### TidBoxGui

Gui to TidBox

