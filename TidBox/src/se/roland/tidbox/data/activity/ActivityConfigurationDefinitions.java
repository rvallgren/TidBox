/**
 * 
 */
package se.roland.tidbox.data.activity;

import java.util.regex.Pattern;

/**
 * <p>
 * Definitions for event configurations.
 * </p>
 * <p>
 * Event configuration settings from Tidbox 4.9 Perl implementation.
 * </p>
 *
 * <pre>
 * 	Regexp and configuration selection
 *     UPPERCASE          A  => [ '[A-ZÅÄÖ]'        , 'Versaler (A-Ö)'           , 1 ],
 *     ALPHABETIC         a  => [ '[a-zåäöA-ZÅÄÖ]'  , 'Alfabetiska (a-öA-Ö)'     , 2 ],
 *     ALFANUMERIC        w  => [ '\\w'             , 'Alfanumerisk (a-ö0-9_)'   , 3 ],
 *     TEXT               W  => [ '[^,\n\r]'        , 'Text (ej ,)'              , 4 ],
 *     DIGITS             d  => [ '\\d'             , 'Siffror (0-9)'            , 5 ],
 *     NUMBER             D  => [ '[\\d\\.\\+\\-]'  , 'Numeriska (0-9.+-)'       , 6 ],
 *     RADIO              r  => [ '[^,\n\r]'        , 'Radioknapp'               , 7 ],
 *     RADIO_ALIAS        R  => [ '[^,\n\r]'        , 'Radioknapp översätt'      , 8 ],
 *     FREE_TEXT         '.' => [ '[^\n\r]'         , 'Fritext'                  , 9 ],
 *     
 *  MyTime
 *     2015-12-03	
 *     Project:d:6
 *     Task:D:6
 *     Type:R:
 *             'N'  . '=>'. 'Normal -SE'                          . ';' .
 *             'F+' . '=>'. 'Normal /flex -SE'                    . ';' .
 *             'Ö+' . '=>'. 'Overtime Single /saved -SE-Overtime' . ';' .
 *             'Res'. '=>'. 'Travelling I /paid -SE-Overtime'     . ';' .
 *             'F-' . '=>'. 'Normal /used flex timi -SE'          . ';' .
 *             'Ö-' . '=>'. 'Compensation for Overtime -SE'       . ';' .
 *             'Sem'. '=>'. 'Vacation -SE'
 *     Details:.:24
 *
 * </pre>
 * 
 * @author Roland Vallgren
 */
public final class ActivityConfigurationDefinitions {
	
	/**
	 * 
	 */
	private ActivityConfigurationDefinitions() {
		// TODO Auto-generated constructor stub
	}

	public enum Type {
		UPPERCASE,  
		ALPHABETIC, 
		ALFANUMERIC,
		TEXT,       
		DIGITS,     
		NUMBER,     
		RADIO,      
		RADIO_ALIAS,
		FREE_TEXT  
		};

	private static char[] types = new char[] {
			'A',
			'a',
			'w',
			'W',
			'd',
			'D',
			'r',
			'R',
			'.',
	};
	
	private static String idx = String.join("", String.valueOf(types));
	
	private static String[] regExps = new String[] {
			"[A-ZÅÄÖ]",
			"[a-zåäöA-ZÅÄÖ]",
			"\\w",
			"[^,\n\r]",
			"\\d",
			"[\\d\\.\\+\\-]",
			"[^,\n\r]",
			"[^,\n\r]",
			".",
	};
	
	private static String[] descriptions = new String[] {
			"Versaler (A-Ö)",
			"Alfabetiska (a-öA-Ö)",
			"Alfanumerisk (a-ö0-9_)",
			"Text (ej ,)",
			"Siffror (0-9)",
			"Numeriska (0-9.+-)",
			"Radioknapp",
			"Radioknapp översätt",
			"Fritext",
	};
		
	public static Pattern[] patterns = new Pattern[9];
		
	/**
	 * @param c
	 * @return
	 */
	public static String getPatternString(char c) {
		int i = idx.indexOf(c);
		if (i >= 0) {
			return regExps[i] + "*";
		}
		return null;
	}

	/**
	 * @param c
	 * @return
	 */
	public static Pattern getPattern(char c) {
		int i = idx.indexOf(c);
		Pattern p = null;
		if (i >= 0) {
			if (patterns[i] == null) {
//				patterns[i] = Pattern.compile("(" + regExps[i] + "*)");
				patterns[i] = Pattern.compile(regExps[i] + "*");
			}
			p = patterns[i];
		}
		return p;
	}




	
}
