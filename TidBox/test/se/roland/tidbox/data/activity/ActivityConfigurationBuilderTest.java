package se.roland.tidbox.data.activity;

import static org.junit.Assert.*;

import org.junit.Test;

public class ActivityConfigurationBuilderTest {

	@Test
	public void constructor() {
		ActivityConfigurationBuilder b = new ActivityConfigurationBuilder("2015-12-08", 3);
		
//		b.add("Project", ActivityConfigurationDefinitions.Type.DIGITS, 6);
		b.add("Project", 'd', 6);
//		b.add("Task", ActivityConfigurationDefinitions.Type.NUMBER, 6);
		b.add("Task", 'D', 6);
//		b.add(ActivityItem.RADIO_ALIAS, "Type", radio);
//		b.add("Description", ActivityConfigurationDefinitions.Type.FREE_TEXT, 24);
		b.add("Description", '.', 24);
		
		ActivityConfigurationItem ac = b.createActivityConfiguration();
		
		assertNotNull("Not expected result null", ac);
		assertEquals("Number of fields should be 3", 3, ac.getSize());
		
	}

}
