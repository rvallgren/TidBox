package se.roland.tidbox.data.activity;

import static org.junit.Assert.*;

import org.junit.Test;

public class ActivityConfigurationBuilderTest {

	@Test
	public void constructor() {
		ActivityConfigurationBuilder b = new ActivityConfigurationBuilder();
		
		b.add(ActivityConfigurationDefinitions.Type.DIGITS, "Project", 6);
		b.add(ActivityConfigurationDefinitions.Type.NUMBER, "Task", 6);
//		b.add(ActivityItem.RADIO_ALIAS, "Type", radio);
		b.add(ActivityConfigurationDefinitions.Type.FREE_TEXT, "Description", 24);
		
		ActivityConfiguration ac = b.createActivityConfiguration();
		
		assertNotNull("Not expected result null", ac);
		assertEquals("Number of fields should be 3", 3, ac.size());
		
	}

}
