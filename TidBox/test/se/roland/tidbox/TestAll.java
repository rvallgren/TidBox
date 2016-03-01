package se.roland.tidbox;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Suite;
import org.junit.runners.Suite.SuiteClasses;

import se.roland.tidbox.data.DayListTest;
import se.roland.tidbox.data.EventTest;
import se.roland.tidbox.data.TimesTest;
import se.roland.tidbox.data.UndoEventTest;
import se.roland.tidbox.data.UndoItemTest;
import se.roland.tidbox.data.activity.ActivityConfigurationBuilderTest;
import se.roland.tidbox.data.activity.ActivityConfigurationTest;
import se.roland.tidbox.data.activity.ActivityConfigurationDefinitionsTest;
import se.roland.tidbox.data.activity.ActivityConfigurationWorkTest;
import se.roland.tidbox.file.DataFileTest;

@RunWith(Suite.class)
@SuiteClasses({
			ClockTest.class,
			DayListTest.class,
			EventTest.class,
			TimesTest.class,
			UndoEventTest.class,
			UndoItemTest.class,
			DataFileTest.class,
			ActivityConfigurationDefinitionsTest.class,
			ActivityConfigurationWorkTest.class,
//			ActivityConfigurationTest.class,
			ActivityConfigurationBuilderTest.class,
		})

public class TestAll {

	@Test
	public void test() {
//		fail("Not yet implemented");
	}

}
