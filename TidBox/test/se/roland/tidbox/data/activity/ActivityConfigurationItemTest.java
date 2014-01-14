/**
 * 
 */
package se.roland.tidbox.data.activity;

import static org.junit.Assert.*;

import java.util.regex.Matcher;

import org.junit.Test;

/**
 * @author vallgrol
 *
 */
public class ActivityConfigurationItemTest {

	/**
	 * @param date
	 * @return
	 */
	private ActivityConfigurationItem setupActivityCfg(String date) {
		ActivityConfigurationItem a = new ActivityConfigurationItem(date, 4);
//		Project:d:6
		a.add("Project", 'd', 6);
//		Task:D:8
		a.add("Task", 'D', 8);
//		Type:W:17
		a.add("Type", 'W', 17);
//		Details:.:40
		a.add("Details", '.', 40);
		return a;
	}
	
	@Test
	public void constructor() {
		ActivityConfigurationItem b = new ActivityConfigurationItem(1);
		b.add("Text", '.', 10);
		Matcher bm = b.match("Some chars");
		assertNotNull("A matcher should be returned", bm);
		assertEquals("One group should match", 1, bm.groupCount());
		assertEquals("Project should match", "Some chars", bm.group(0));

		
		String date = "2013-12-18";
		ActivityConfigurationItem a = setupActivityCfg(date);
		
		// TODO Match an activity
		Matcher m = a.match("1,2.3,Some chars-except comma,Any characters: , + - .");
		assertNotNull("A matcher should be returned", m);
		assertEquals("Four groups should match", 4, m.groupCount());
		assertEquals("Project should match", "1", m.group(1));
		assertEquals("Task should match", "2.3", m.group(2));
		assertEquals("Type should match", "Some chars-except comma", m.group(3));
		assertEquals("Details should match", "Any characters: , + - .", m.group(4));
		
		// TODO Radio buttons
//		Project:R:?=>?;Obe=>135108;Utb=>135095;Räkn=>136627;Frånv=>66438;Polaris=>147735
//		Task:D:8
//		Type:R:N=>Normal -SE;F+=>Normal /flex -SE;Ö+=>Overtime Single /saved -SE-Overtime;R=>Travelling I /paid -SE;S=>Vacation -SE;F-=>Normal /used flex timi -SE;Ö-=>Compensation for Overtime -SE;Prm=>Leave of Absence /paid -SE;Sju=>Sick Leave -SE;;Doc=>Doctor Visit -SE;Vab=>Care of child Leave -SE;Fld=>Parental Leave -SE
//		Details:.:40

		// TODO splitData: Plocka en sträng i taget, Matchar den inte => tom sträng + tag bort till komma "," 
		// One field
		String oneField = "123";
		String[] oneFieldData = a.parse(oneField);
		String[] oneFieldExpected = {"123", "", "", ""};
		assertArrayEquals("Expected to be equal", oneFieldExpected, oneFieldData);

		// Two fields
		String twoField = "234,2.34";
		String twoFieldC = "234,2.34,,";
		String[] twoFieldData = a.parse(twoField);
		String[] twoFieldDataC = a.parse(twoFieldC);
		String[] twoFieldExpected = {"234", "2.34", "", ""};
		assertArrayEquals("Expected to be equal", twoFieldExpected, twoFieldData);
		assertArrayEquals("Expected to be equal", twoFieldExpected, twoFieldDataC);
		
		// Three fields
		String threeField = "3456,34.56,Three fields";
		String threeFieldC = threeField +",";
		String[] threeFieldData = a.parse(threeField);
		String[] threeFieldDataC = a.parse(threeFieldC);
		String[] threeFieldExpected = {"3456", "34.56", "Three fields", ""};
		assertArrayEquals("Expected to be equal", threeFieldExpected, threeFieldData);
		assertArrayEquals("Expected to be equal", threeFieldExpected, threeFieldDataC);
		
		// Three fields
		String fourField = "789,789.,Four 4 fields,And some text with comma ,";
		String[] fourFieldData = a.parse(fourField);
		String[] fourFieldExpected = {"789", "789.", "Four 4 fields", "And some text with comma ,"};
		assertArrayEquals("Expected to be equal", fourFieldExpected, fourFieldData);
	}


	/**
	 * Test toFile method for one item
	 * @throws Exception
	 */
	@Test
	public void toFile() throws Exception {
		String date = "2013-12-18";
		ActivityConfigurationItem a = setupActivityCfg(date);
		
//		2013-12-18
//		Project:d:6
//		Task:D:8
//		Type:W:17
//		Details:.:40
		assertEquals("Four configuration fields expected", 4, a.number());
		assertEquals("Date expected", date, a.toFile());
		assertEquals("Project:d:6 expected", "Project:d:6", a.toFile(0));
		assertEquals("Task:D:8 expected", "Task:D:8", a.toFile(1));
		assertEquals("Type:W:17 expected", "Type:W:17", a.toFile(2));
		assertEquals("Details:.:40 expected", "Details:.:40", a.toFile(3));
		
		assertEquals("The complete cfg expected",
				date + "\n" +
				"Project:d:6\n" + 
				"Task:D:8\n" + 
				"Type:W:17\n" + 
				"Details:.:40\n", a.save());
	}
	
	@Test
	public void guiSetupAndUse() throws Exception {
		String date = "2013-12-18";
		ActivityConfigurationItem a = setupActivityCfg(date);
		
		assertEquals("Label expected: Project", "Project", a.getLabel(0));
		assertEquals("Size expected: 6", 6, a.getSize(0));
		assertEquals("Label expected: Task", "Task", a.getLabel(1));
		assertEquals("Size expected: 8", 8, a.getSize(1));
		assertEquals("Label expected: Type", "Type", a.getLabel(2));
		assertEquals("Size expected: 17", 17, a.getSize(2));
		assertEquals("Label expected: Details", "Details", a.getLabel(3));
		assertEquals("Size expected: 40", 40, a.getSize(3));
		
		String[] expecteds = {"1", "2.3", "Some chars-except comma", "Any characters: , + - ."};
		String expected = "1,2.3,Some chars-except comma,Any characters: , + - .";
		String[] actuals = a.split(expected);
		
		assertArrayEquals("Expected to be equal", expecteds, actuals);
		assertEquals("Joined string to be equal", expected, a.join(actuals));
		
		// TODO splitData: Plocka en sträng i taget, Matchar den inte => tom sträng + tag bort till komma "," 
		
		
	}
}
