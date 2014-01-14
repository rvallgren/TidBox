/**
 * 
 */
package se.roland.tidbox.data.activity;

import java.util.regex.Pattern;

/**
 * @author vallgrol
 *
 *     UPPERCASE          A  => [ '[A-ZÅÄÖ]'        , 'Versaler (A-Ö)'           , 1 ],
 *     ALPHABETIC         a  => [ '[a-zåäöA-ZÅÄÖ]'  , 'Alfabetiska (a-öA-Ö)'     , 2 ],
 *     ALFANUMERIC        w  => [ '\\w'             , 'Alfanumerisk (a-ö0-9_)'   , 3 ],
 *     TEXT               W  => [ '[^,\n\r]'        , 'Text (ej ,)'              , 4 ],
 *     DIGITS             d  => [ '\\d'             , 'Siffror (0-9)'            , 5 ],
 *     NUMBER             D  => [ '[\\d\\.\\+\\-]'  , 'Numeriska (0-9.+-)'       , 6 ],
 *     RADIO              r  => [ '[^,\n\r]'        , 'Radioknapp'               , 7 ],
 *     RADIO_ALIAS        R  => [ '[^,\n\r]'        , 'Radioknapp översätt'      , 8 ],
 *     FREE_TEXT         '.' => [ '[^\n\r]'         , 'Fritext'                  , 9 ],
 */
public class ActivityConfigurationDefinitions {

	public enum Type {
		DIGITS, NUMBER, FREE_TEXT
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
	
	private static String idx = "AawWdDrR.";
	
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
