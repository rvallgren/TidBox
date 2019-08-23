
## Inneh&aring;llsf&ouml;rteckning
 1. [Tidbox](#2)
 2. [Tidbox f&ouml;nster](#7)
 3. [Tidbox applikation](#8)
 4. [Installation av Tidbox](#9)
 5. [Installation av Perl till Tidbox](#10)
 6. [Starta Tidbox](#11)
 7. [Java implementation](#12)

## <a id="2">1.</a> Tidbox
Tidbox &auml;r ett verktyg f&ouml;r att ber&auml;kna den tid som har anv&auml;nts f&ouml;r att kunna
rapportera anv&auml;nd tid i timmar och delar av timmar.

De sammanr&auml;knade tiderna f&ouml;r en vecka kan exporteras till fil.

Tidbox &auml;r helt p&aring; svenska.

### Princip

Klockslaget n&auml;r en aktivitet eller paus startar registreras i Tidbox. Tidbox
kan sedan ber&auml;kna tiden fr&aring;n start och till slut. En ny aktivitet eller paus
inneb&auml;r att den p&aring;g&aring;ende slutar. Tiden som f&ouml;flutit ber&auml;knas i timmar
och delar av timmar. All tid i Tidbox hanteras endast per hel minut. Sekunder
hanteras inte.

### Grundl&auml;ggande tidber&auml;kningar

Tiden &auml;r antingen arbetstid eller inte arbetstid, allts&aring; paus. Enbart
arbetstid registreras. Tid f&ouml;r paus r&auml;knas ihop och presenteras.

Tidpunkten f&ouml;r n&auml;r en aktivitet eller en paus b&ouml;rjar registreras. N&auml;sta
registrerade tidpunkt, b&ouml;rjan p&aring; en ny aktivitet eller en b&ouml;rjan p&aring; en
paus, hanteras som sluttid f&ouml;r den p&aring;g&aring;ende aktiviteten.

Arbetstiden f&ouml;r en aktivitet ber&auml;knas som tiden mellan starttiden och
sluttiden. Om samma aktivitet f&ouml;rekommer flera g&aring;nger under en arbetsdag
s&aring; adderas tiderna.

Den ackumulerade arbetstiden f&ouml;r en aktivitet under en dag rapporteras som
timmar och delar av timmar i tiondelar och hundradelar. Hundradelarna &auml;r
ungef&auml;rliga eftersom alla ber&auml;kningar av tid g&ouml;rs i hela minuter.

### S&auml;tt att ange tid

Tid anges i timmar och minuter, till exempel: `15:23`.

Deltatid kan anges och Tidbox r&auml;knar om till tidpunkten. Till exempel en
timma och trettio minuter efter klockan tre: `15:00+1:30` r&auml;knas om till
`16:30`.

Deltatid kan anges i timmar och decimaler, till exempel: `8:00+1,5` r&auml;knas
om till `09:30`.

Om tiden anges utan avdelare eller f&ouml;rkortat f&ouml;rs&ouml;ker Tidbox gissa en
rimlig tid, till exempel: `98` antas bli `09:08`

### Registreringar

Tidbox hanterar sex grundl&auml;ggande typer av tidpunkter. Dessa kan anv&auml;ndas
efter behov:

**B&ouml;rja arbetsdagen**: Den f&ouml;rsta h&auml;ndelsen under en dag, f&aring;r endast
f&ouml;rekomma en g&aring;ng.

**Sluta arbetsdagen**: Den sista h&auml;ndelsen under en dag, f&aring;r endast
f&ouml;rekomma en g&aring;ng.

**B&ouml;rja paus**: B&ouml;rja ett uppeh&aring;ll. Till exempel lunch.

**Sluta paus**: Avsluta ett uppeh&aring;ll.

**B&ouml;rja h&auml;ndelse**: Till exempel ett m&ouml;te. Till h&auml;ndelsen kan man ange vad
h&auml;ndelsen avser. F&ouml;r tidregistrering kan konton, typ, aktivitet,
textkommentar etc. anges.

**Sluta h&auml;ndelse**: Avslutar den p&aring;g&aring;ende h&auml;ndelsen.

Alla dessa beh&ouml;ver inte anv&auml;ndas men finns vid behov. F&ouml;r att registrera
tider till ett tidrapporteringssystem d&auml;r till exempel projektnummer, etc.
beh&ouml;ver anges s&aring; anv&auml;nds "**B&ouml;rja h&auml;ndelse**", med den informationen. N&auml;r
n&auml;sta aktivitet b&ouml;rjar s&aring; anges den nya aktiviteten. N&auml;r det inte l&auml;ngre
&auml;r tid som beh&ouml;ver registreras s&aring; anv&auml;nds "**B&ouml;rja paus**". Det kan se ut s&aring;
h&auml;r:

```
  Tid     Projekt  Aktivitet  Typ     Kommentar
  -----   -------  ---------  ------  ----------------------
  08:00   1234     Meeting    Normal  Scrum
  08:30   1234     Design     Normal  Modulen veckoarbetstid
  11:30   Paus
```


## <a id="7">2.</a> Tidbox f&ouml;nster
Huvudf&ouml;nstret i Tidbox &auml;r till f&ouml;r att registrera tiden f&ouml;r den aktuella
dagen och enklare redigering av tider och h&auml;ndelser. H&auml;rifr&aring;n startas de andra
f&ouml;nstren:

**Veckan** &auml;r ett f&ouml;nster som ber&auml;knar och redovisar arbetstiden per aktivitet
f&ouml;r en vecka. Den ber&auml;knade tiden kan exporteras till fil, direkt till en
.csv-fil eller via insticksmoduler till anpassade format. F&ouml;r n&auml;rvarande
finns st&ouml;d f&ouml;r Microsoft Excel och .csv. H&auml;r startas &auml;ven **&Aring;r.**

**&Aring;r** visar alla &aring;r och veckor d&auml;r det finns registrerade h&auml;ndelser.

**Redigera** &auml;r till f&ouml;r lite mer avancerad redigering och f&ouml;r att
redigera andra dagar.

**Inst&auml;llningar** hanterar inst&auml;llningar i Tidbox.

---


## <a id="8">3.</a> Tidbox applikation
Tidbox &auml;r skriven i Perl och anv&auml;nder till Gui:t anv&auml;nds Perl/Tk. Tidbox
finns p&aring; Github. De f&ouml;rsta versionerna utvecklades p&aring; Solaris men sedan har
utvecklingen mestadels gjorts p&aring; MS Windows. Den kan fortfarande fungera p&aring;
Unix eller Linux, men jag har inte haft n&aring;gon maskin att verifiera den p&aring;.

## <a id="9">4.</a> Installation av Tidbox
F&ouml;r att ladda ner Tidbox fr&aring;n Github g&aring; in i "releases" och ladda ner fr&aring;n
"Source code (zip)" f&ouml;r den version du vill ha. F&ouml;rslagsvis den senaste
versionen.

Perl implementationen av Tidbox lagras i katalogen `PerlTidbox/src`:
- `tidbox.pl` : Huvudprogram
- `lib` : Katalog med perlmoduler

Packa upp dessa till en katalog som du har skrivbeh&ouml;righet i, till exempel:
- Windows: `<username>\Tidbox`
- Unix: `$HOME/Tidbox`

OBS: Fr&aring;n och med utg&aring;va `4.12` laddar Tidbox ner nya versioner och
     uppdaterar sig sj&auml;lv, om den har skrivbeh&ouml;righet i installationskatalogen.
     D&auml;rf&ouml;r rekommenderas att installera Tidbox i hemkatalogen.


## <a id="10">5.</a> Installation av Perl till Tidbox
Tidbox &auml;r verifierad med:
- `Windows 10`
- `Strawberry Perl 5.30.0.1 Portable 64bit`
- `Perl/Tk VERSION 804.034`

G&ouml;r s&aring; h&auml;r f&ouml;r att installera Perl och Perl/Tk p&aring; Windows:

- Ladda ner Strawberry Perl 5.30.0.1 portable 64bit:
  [Ladda ner](http://strawberryperl.com/download/5.30.0.1/strawberry-perl-5.30.0.1-64bit-PDL.zip)

- Packa upp zip-filen till ett passande st&auml;lle, till exempel: `C:\StrawberryPerl5.30.0.1`
  OBS: V&auml;lj ett katalognamn utan blanktecken eller icke ascii-tecken.
  OBS: 7zip rekommenderas f&ouml;r att packa upp.

- Starta (dubbelklicka p&aring;) `C:\StrawberryPerl5.30.0.1\portableshell.bat` -
  s&aring; &ouml;ppnas ett kommandof&ouml;nster.

- F&ouml;r att installera Perl/Tk ge detta kommando i kommandof&ouml;nstret:
  `cpan Tk`

Tidbox fungerar med &auml;ldre versioner av Perl ocks&aring;. Det &auml;r dock inte
verifierat f&ouml;r &auml;ldre versioner.

---


## <a id="11">6.</a> Starta Tidbox
N&auml;r du har installerat Tidbox och Perl s&aring; kan du starta Tidbox s&aring; h&auml;r:

`<`S&ouml;kv&auml;g till Perl bin `>\wperl.exe` `<`S&ouml;kv&auml;g till Tidbox`>\tidbox.pl`

P&aring; Windows kan det se ut s&aring; h&auml;r (byt ut `<username>` mot ditt anv&auml;ndarnamn:

`C:\StrawberryPerl5.30.0.1Tk\perl\bin\wperl.exe "C:\Users\<username>\Tidbox\tidbox.pl"`

**Tips:** L&auml;gg till en genv&auml;g i `startup` s&aring; att Tidbox alltid startas n&auml;r du loggar in.

`startup` finns i AppData i hemkatalogen:
`%HOME%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`


## <a id="12">7.</a> Java implementation
Java implementationen av Tidbox &auml;r pausad.

### TidBox

Funktionalitet TidBox

### TidBoxGui

TidBox Gui

