/**
 * 
 */
package se.roland.tidbox.data.activity;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * @author Roland Vallgren
 *
 */
public class ActivityConfigurationItem {

	private String date;
	private int numberOfElements;
	private String[] labels;
	private char[] types;
	private int[] sizes;
	private Pattern pattern;
	private Pattern[] patternParts;
	private Pattern any;

	/**
	 * Create an activity configuration item with a defined number of elements.
	 * 
	 * @param date
	 * @param number  Number of items in the activity configuration 
	 */
 	private ActivityConfigurationItem(String date, String[] labels, char[] types, int[] sizes) {
		this.date = date;
		this.labels = labels;
		this.types = types;
		this.sizes = sizes;
		numberOfElements = types.length;
		this.patternParts = new Pattern[numberOfElements];
		for (int i = 0; i < numberOfElements; i++) {
			patternParts[i] = Pattern.compile("(" + ActivityConfigurationDefinitions.getPatternString(types[i]) + "),?(.*)" );
		}

		StringBuilder s = new StringBuilder("(");
		int group = 1;
		for (int element = 0; element < numberOfElements; element++) {
			s.append(ActivityConfigurationDefinitions.getPatternString(types[element])).append(")");
			if (group < numberOfElements) {
				s.append(",(");
				group++;
			}
		}
		pattern = Pattern.compile(s.toString());
		this.any = Pattern.compile("[^,]*,(.*)");
	}


	public static ActivityConfigurationItem create(String d, String[] l, char[] t, int[] s) {
		return new ActivityConfigurationItem(d, l, t, s);
	}



	/**
	 * @return number of settings
	 */
	public int getSize() {
		return numberOfElements;
	}

	/**
	 * String of item date
	 * @return
	 */
	public String toFile() {
		return date;
	}

	/**
	 * Create a String with configuration information for item
	 * @param element
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
		Matcher m = pattern.matcher(line);
		if (m.matches())
			return m;
		return null;
	}


	/**
	 * Save configuration settings for the item
	 * @return
	 */
	public String save() {
		StringBuilder tmp = new StringBuilder(date + "\n");	
		for (int element = 0; element < numberOfElements; element++) {
			tmp.append(toFile(element));
			tmp.append("\n");
		}
		return tmp.toString();
	}

	/**
	 * Get label to use for entry number
	 * 
	 * @param element
	 * @return String label
	 */
	public String getLabel(int element) {
		return labels[element];
	}

	/**
	 * Get size for Gui text entry
	 * 
	 * @param element
	 * @return Size in number of characters
	 */
	public int getSize(int element) {
		return sizes[element];
	}

	/**
	 * Split an activity in parts
	 * 
	 * @param  information String to be split
	 * @return Array with strings of activity parts
	 */
	public String[] split(String information) {
		Matcher m = this.match(information);
		int n = m.groupCount();
		if (n == numberOfElements) {
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
	 * @param information   String to be parsed as event configuration data
	 * @return Array of strings with parsed data
	 */
	public String[] parse(String information) {
		String[] res = new String[numberOfElements];
		for (int element = 0; element < numberOfElements; element++) {
			Matcher m = patternParts[element].matcher(information);
			if (m.matches()) {
				res[element] = m.group(1);
				information = m.group(2);
			} else {
				res[element] = "";
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
