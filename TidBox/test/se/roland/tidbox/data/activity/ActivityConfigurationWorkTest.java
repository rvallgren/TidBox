/**
 * 
 */
package se.roland.tidbox.data.activity;

import static org.junit.Assert.*;

import java.util.regex.Matcher;

import org.junit.Test;

/**
 * Test activity class
 * @author vallgrol
 *
 */
public class ActivityConfigurationWorkTest {

	@Test
	public void loadActivities() {
		// Activity configuration
		// 2013-10-07
		// Project:R:?=>?;Obe=>135108;Utb=>135095;Räkn=>136627;Frånv=>66438;Polaris=>147735
		// Task:D:8
		// Type:R:N=>Normal -SE;F+=>Normal /flex -SE;Ö+=>Overtime Single /saved -SE-Overtime;R=>Travelling I /paid -SE;S=>Vacation -SE;F-=>Normal /used flex timi -SE;Ö-=>Compensation for Overtime -SE;Prm=>Leave of Absence /paid -SE;Sju=>Sick Leave -SE;;Doc=>Doctor Visit -SE;Vab=>Care of child Leave -SE;Fld=>Parental Leave -SE
		// Details:.:40
		ActivityConfigurationItem cfg = new ActivityConfigurationItem(4);
		// TODO: Load activities from file
		// activityConfiguration splits line
		String l1 = "1177,01.02,Normal -SE,Detaljer för aktivitet, komma är tillåtet";
		Matcher m = cfg.match(l1);
		assertEquals("Project should match", "1177", m.group(0));
		assertEquals("Task should match", "01.02", m.group(1));
		assertEquals("Type should match", "Normal -SE", m.group(2));
		assertEquals("Details should match", "Detaljer för aktivitet, komma är tillåtet", m.group(3));
		// Populate activity
//		String[] e = new String[activityConfiguration.number()];
//		e[0] = "1177"; // Project
//		e[1] = "01.02"; // Task
//		e[2] = "Normal -SE"; // Type
//		e[3] = "Details for this activity"; // Details
//		
//		// Create the activity
//		Activity a = activityConfiguration.newActivity(e);
//		Activity b = activityConfiguration.newActivity();
//		b.insert(e);
		
		
		
		fail("Not yet implemented");
	}

}
