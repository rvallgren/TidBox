/**
 * 
 */
package se.roland.tidbox.data.activity;

import static org.junit.Assert.assertEquals;

import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

/**
 * @author vallgrol
 *
 */
public class ActivityConfigurationItem {

	private String date;
	private int number;
	private String[] labels;
	private char[] types;
	private int[] sizes;
	private Pattern pattern;
	private Pattern[] patternParts;
	private Pattern any;

	/**
	 * 
	 * @param i
	 */
 	public ActivityConfigurationItem(int number) {
		this.number = 0;
		this.labels = new String[number];
		this.types = new char[number];
		this.sizes = new int[number];
		this.patternParts = new Pattern[number];
		this.any = Pattern.compile("[^,]*,(.*)");
	}

	/**
	 * @param date
	 * @param i
	 */
	public ActivityConfigurationItem(String d, int i) {
		this(i);
		date = d;
	}


	/**
	 * @param string
	 * @param c
	 * @param i
	 */
	public void add(String desc, char type, int size) {
		labels[number] = desc;
		types[number] = type;
		sizes[number] = size;
		number++;
	}

	/**
	 * @return number of settings
	 */
	public int number() {
		return labels.length;
	}

	/**
	 * @return
	 */
	public String toFile() {
		return date;
	}

	/**
	 * @param i
	 * @return
	 */
	public String toFile(int element) {
		return labels[element] + ":" + types[element] + ":" + sizes[element];
	}

	/**
	 * @param string
	 * @return a Matcher if the line matches the pattern for the configuration item
	 */
	public Matcher match(String line) {
		if (pattern == null) {
			StringBuilder s = new StringBuilder("(");
			int g = 1;
			for (int i = 0; i < number; i++) {
				s.append(ActivityConfigurationDefinitions.getPatternString(types[i])).append(")");
				if (g < number) {
					s.append(",(");
					g++;
				}
			}
			pattern = Pattern.compile(s.toString());
		}
		Matcher m = pattern.matcher(line);
		if (m.matches())
			return m;
		return null;
	}


	/**
	 * @return
	 */
	public String save() {
		StringBuilder tmp = new StringBuilder(date + "\n");	
		for (int i = 0; i < labels.length; i++) {
			tmp.append(toFile(i));
			tmp.append("\n");
		}
		return tmp.toString();
	}

	/**
	 * @param iterator
	 * @return
	 */
	public String getLabel(int item) {
		return labels[item];
	}

	/**
	 * @param iterator
	 * @return
	 */
	public int getSize(int item) {
		return sizes[item];
	}

	/**
	 * @param inf
	 * @return
	 */
	public String[] split(String information) {
		Matcher m = this.match(information);
		int n = m.groupCount();
		if (n == number) {
			String[] res = new String[n];
			for (int i = 0; i < n; i++) {
				res[i] = m.group(i+1);
			}
			return res;
		}
		return null;
	}

	/**
	 * Join array of strings in one String with comma "," as separator
	 * 
	 * @param An array of Strings for an event
	 * @return String 
	 */
	public String join(String[] texts) {
		StringBuilder tmp = new StringBuilder("");
		for (int i = 0; i < texts.length; i++) {
			if (i > 0) {
				tmp.append(",");
			}
			tmp.append(texts[i]);
		}
		Matcher m = this.match(tmp.toString());
		if (m == null) {
			return null;
		} else {
			return tmp.toString();
		}
	}


	/**
	 * Parse an event string for event fields
	 * Non existing fields or fields with faulty content returns an empty string
	 * 
	 * @param information
	 * @return Array of String
	 */
	public String[] parse(String information) {
		String[] res = new String[number];
		for (int i = 0; i < patternParts.length; i++) {
			if (patternParts[i] == null) {
				patternParts[i] = Pattern.compile("(" + ActivityConfigurationDefinitions.getPatternString(types[i]) + "),?(.*)" );
			}
			Matcher m = patternParts[i].matcher(information);
			if (m.matches()) {
				res[i] = m.group(1);
				information = m.group(2);
			} else {
				res[i] = "";
				m = any.matcher(information);
				if (m.matches()) {
					information = m.group(1);
				} else {
					information = "";
				}
			}
		}
		return res;
	}


}
