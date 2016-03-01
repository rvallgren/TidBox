/**
 * 
 */
package se.roland.tidbox.data.activity;

/**
 * @author Roland Vallgren
 *
 */
public class ActivityConfigurationBuilder {

	private int numberOfElements;
	private int indexInitialized;
	private String[] labels;
	private char[] types;
	private int[] sizes;
	private String date;

	public ActivityConfigurationBuilder(String date, int number) {
		this.numberOfElements = number;
		this.indexInitialized = 0;
		this.labels = new String[number];
		this.types = new char[number];
		this.sizes = new int[number];
//		this.any = Pattern.compile("[^,]*,(.*)");
		this.date = date;
	}

	/**
	 * @param label	label for the configuration item
	 * @param type	Type, see {@link #ActivityConfigurationDefinitions} type
	 * @param size	Width of field for GUI
	 */
	public void add(String label, char type, int size) {
		labels[indexInitialized] = label;
		types[indexInitialized] = type;
		sizes[indexInitialized] = size;
		indexInitialized++;
	}

	/**
	 * @return ActivityConfigurationItem
	 */
	public ActivityConfigurationItem createActivityConfiguration() {
		if (indexInitialized != numberOfElements) {
			// TODO Should throw an error?
			return null;
		}
		return ActivityConfigurationItem.create(date, labels, types, sizes);
	}

}
