
# Tidbox


Verktyg f&ouml;r att ber&auml;kna tid f&ouml;r tidrapportering.


## Princip


Registrera starttid f&ouml;r en aktivitet eller en paus i Tidbox. Tidbox ber&auml;knar sedan tids&aring;tg&aring;ngen i timmar och decimaler av timmar.
All tid i Tidbox hanteras endast p&aring; minut, sekunder hanteras inte.


## Grundl&auml;ggande tidber&auml;kningar


Tiden &auml;r antingen arbetstid eller inte arbetstid, allts&aring; paus. Enbart arbetstid registreras.
Paus tid r&auml;knas ihop och dras bort fr&aring;n arbetstiden.

Registrera tiden n&auml;r en aktivitet startar.

N&auml;sta registrerade tidpunkt, b&ouml;rjan p&aring; en ny aktivitet eller en b&ouml;rjan p&aring; en pause, hanteras som sluttid p&aring; den p&aring;g&aring;ende aktiviteten.

Arbetstiden f&ouml;r en aktivitet ber&auml;knas som tiden mellan starttiden och sluttiden.
Om samma aktivitet f&ouml;rekommer flera g&aring;nger under en arbetsdag s&aring; adderas tiderna.

Den accumulerade arbetstiden f&ouml;r en aktivitet under en dag rapporteras som timmar och delar av timmar i tiondelar och hundradelar.
Hundradelarna &auml;r ungef&auml;rliga eftersom alla ber&auml;kningar av tid g&ouml;rs i hela minuter.

De sammanr&auml;knade tiderna kan exporteras till en .csv-fil eller en Microsoft Excel fil. Dessa filer &auml;r framf&ouml;rallt avsedda att importeras i ett tidrapporteringssystem.

Tidbox &auml;r helt p&aring; svenska.


## Tidbox f&ouml;nster


Huvudf&ouml;nstret i Tidbox &auml;r till f&ouml;r att registrera tiden f&ouml;r den aktuella dagen och grundl&auml;ggande redigeringar.

Veckan &auml;r ett f&ouml;nster som ber&auml;knar och redovisar arbetstiden per aktivitet f&ouml;r en vecka.

Redigera f&ouml;nstret &auml;r till f&ouml;r lite mer avancerad redigering och f&ouml;r att redigera andra dagar.

&Aring;r &auml;r f&ouml;r att se vilka veckor det finns registrerade h&auml;ndelser.


## Tid


Tid anges i timmar och minuter, till exempel: `15:23`.

Deltatid kan ber&auml;knas, till exempel en timma och trettio minuter: `15:00+1:30` r&auml;knas om till `16:30`.

Deltatid kan anges i timmar och decimaler, till exempel: `8:00+1,5` r&auml;knas om till `09:30`.

Om tiden anges utan avdelare eller f&ouml;rkortat f&ouml;rs&ouml;ker Tidbox gissa en rimlig tid, till exempel: `98` antas bli `09:08`

---

## Installation av Tidbox och Perl version


Perl implementationen av Tidbox lagras i katalogen `PerlTidbox/src`:
- `tidbox.pl` : Huvudprogram
- `lib` : Perlmoduler

Packa upp dessa till en katalog som du har skrivbeh&ouml;righet i, till exempel:
- Windows: `<username>\Tidbox`
- Unix: `$HOME/Tidbox`

Note: Fr&aring;n och med utg&aring;va `4.12` laddar Tidbox ner nya versioner och
      uppdaterar sig sj&auml;lv om den har skrivbeh&ouml;righet i installationskatalogen.


### Starta s&aring; h&auml;r


`<`S&ouml;kv&auml;g till Perl`>\wperl.exe` `<`S&ouml;kv&auml;g till Tidbox`>\tidbox.pl`

P&aring; Windows kan det se ut s&aring; h&auml;r (byt ut `<username>` mot ditt anv&auml;ndarnamn:

`C:\StrawberryPerl5.28.1.1Tk\perl\bin\wperl.exe "C:\Users\<username>\Tidbox\tidbox.pl"`

L&auml;gg till detta i `startup` s&aring; att den alltid &auml;r ig&aring;ng n&auml;r du &auml;r inloggad.


## Perl


Tidbox &auml;r verifierad med:
- `Strawberry Perl 5.28.1.1`
- `Perl/Tk VERSION 804.034`

G&ouml;r s&aring; h&auml;r f&ouml;r att installera Perl och Perl/Tk p&aring; Windows:

- Ladda ner Strawberry Perl 5.28.1.1 portable fr&aring;n http://strawberryperl.com/

- Packa upp zip-filen till ett passande st&auml;lle, till exempel: `C:\StrawberryPerl5.28.1.1`
  OBS: V&auml;lj ett katalognamn utan blanktecken eller icke ascii-tecken.
  OBS: 7zip rekommenderas f&ouml;r att packa upp.

- Starta `C:\StrawberryPerl5.28.1.1\portableshell.bat` -
  den &ouml;ppnar ett kommando f&ouml;nster.

- F&ouml;r att installera Perl/Tk ge detta kommando:
  `ppm install Tk`

---

## Java implementation


Java implementationen av Tidbox &auml;r pausad.


### TidBox


Funktionalitet TidBox


### TidBoxGui


TidBox Gui

