package se.roland.tidbox.data;

import static org.junit.Assert.*;

import java.util.ArrayList;
import org.junit.Test;

/**
 * @author Roland Vallgren
 *
 */
public class TimesTest {

	/*
	 * Create Times, a list of events
	 * - Add event
	 * - get events for a date
	 * - Remove event
	 */
	@Test
	public void createTimes() {
		Times t = new Times();
		
		Event ePause = new Event("2013-01-01", "23:59", Event.PAUSE);
		assertTrue("It is always OK to add an event", t.add(ePause));
		
		ArrayList<Event> empty = t.getDate("2012-01-01");

		assertNotNull(empty);
		assertTrue(empty instanceof ArrayList<?>);
		assertEquals(0, empty.size());

		ArrayList<Event> tDate = t.getDate("2013-01-01");
 
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0) instanceof Event);
		Event eCheck = tDate.get(0);
		assertEquals(ePause, eCheck);
		
		Event eEvent = new Event("2013-01-01", "01:01", Event.EVENT, "An event");
		t.add(eEvent);
		
		tDate = t.getDate("2013-01-01");
		
		assertEquals(2, tDate.size());
		for (Event eCh : tDate) {
			assertTrue(eCh instanceof Event);
		}
		// Verify event list is sorted
		eCheck = tDate.get(0);
		assertEquals(eEvent, eCheck);
		eCheck = tDate.get(1);
		assertEquals(ePause, eCheck);
		
//		Replace an event
		Event eReplace = new Event("2013-01-01", "01:01", Event.EVENT, "Replaced event");
		tDate = t.getDate("2013-01-01");
		eCheck = tDate.get(0);
		assertTrue("OK to replce an existing event", t.replace(eCheck, eReplace));

		tDate = t.getDate("2013-01-01");
		Event eCheck2 = tDate.get(0);
		assertNotEquals(eCheck, eCheck2);
		
//		Remove. Here only remove by sending the Event works.
		assertTrue("OK to remove an existing event", t.remove(eCheck2));
		
		tDate = t.getDate("2013-01-01");
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0) instanceof Event);
		eCheck = tDate.get(0);
		assertEquals(eReplace, eCheck2);
		
		// TODO Replace an event that does not exist
		Event eReplaceNotExist = new Event("2013-01-01", "01:01", Event.EVENT, "Not existing event");
		Event eRemoveNotExist = new Event("2013-01-01", "01:01", Event.EVENT, "Not existing event");
		Event eAnother  = new Event("2013-01-01", "01:01", Event.EVENT, "Another event");
		assertFalse("Should fail to replace a not existing event", t.replace(eReplaceNotExist, eAnother));
		assertFalse("Should fail to remove a not existing event", t.remove(eRemoveNotExist));
		
	}

	/*
	 * Create Times, a list of events
	 * - Add event
	 * - get events for a date
	 * - Remove event
	 */
	@Test
	public void undoTimes() {
		Times t = new Times();
		
		assertTrue(t.isUndoEmpty());
		assertTrue(t.isRedoEmpty());
		
		Event ePause = new Event("2013-01-01", "23:59", Event.PAUSE);
		t.add(ePause);
		assertFalse(t.isUndoEmpty());
		assertTrue(t.isRedoEmpty());

		Event[] u = t.peekUndo();
		assertEquals(2, u.length);
		assertTrue(u[0].equals(ePause));
		assertNull(u[1]);
		
		Event eReplace = new Event("2013-01-01", "22:59", Event.PAUSE);
		t.replace(ePause, eReplace);
		ArrayList<Event> tDate = t.getDate("2013-01-01");
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0).equals(eReplace));
		
		t.remove(eReplace);
		tDate = t.getDate("2013-01-01");

		assertFalse(t.isUndoEmpty());
		assertTrue(t.isRedoEmpty());
		assertEquals(0, tDate.size());

		// Undo remove
		t.undo();
		tDate = t.getDate("2013-01-01");
		
		assertFalse(t.isUndoEmpty());
		assertFalse(t.isRedoEmpty());
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0).equals(eReplace));

		// Undo replace
		t.undo();
		tDate = t.getDate("2013-01-01");
		
		assertFalse(t.isUndoEmpty());
		assertFalse(t.isRedoEmpty());
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0).equals(ePause));
		
		// Undo add
		t.undo();
		tDate = t.getDate("2013-01-01");
		
		assertTrue(t.isUndoEmpty());
		assertFalse(t.isRedoEmpty());
		assertEquals(0, tDate.size());
		
		// Redo add
		t.redo();
		tDate = t.getDate("2013-01-01");
		
		assertFalse(t.isUndoEmpty());
		assertFalse(t.isRedoEmpty());
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0).equals(ePause));
		
		// Redo replace
		t.redo();
		tDate = t.getDate("2013-01-01");

		assertFalse(t.isUndoEmpty());
		assertFalse(t.isRedoEmpty());
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0).equals(eReplace));
		
		// Redo remove
		t.redo();
		tDate = t.getDate("2013-01-01");
		
		assertFalse(t.isUndoEmpty());
		assertTrue(t.isRedoEmpty());
		assertEquals(0, tDate.size());
		
	}
	
	@Test
	public void save() throws Exception {
		Times t = new Times();
		Event attempt = new Event("2013-11-28", "08:10", Event.EVENT, "Not saved event");
		Event beginWork = new Event("2013-11-28", "08:10", Event.BEGINWORK);
		t.add(attempt);
		t.replace(attempt, beginWork);
		t.add(new Event("2013-11-28", "11:30", Event.PAUSE));
		t.add(new Event("2013-11-28", "09:10", Event.EVENT, "Startade tidbox"));
		t.add(new Event("2013-11-28", "09:43", Event.EVENT, "Startade tidbox"));
		t.add(new Event("2013-11-28", "09:19", Event.EVENT, "Java TDD Tidbox GUI"));
		t.add(new Event("2013-11-28", "14:04", Event.EVENT, "Java TDD Tidbox GUI"));
		t.add(new Event("2013-11-28", "14:49", Event.EVENT, "Java TDD Tidbox GUI"));
		t.add(new Event("2013-11-28", "10:46", Event.EVENT, "Atlassian"));
		t.add(new Event("2013-11-28", "12:54", Event.EVENT, "Atlassian"));
		t.add(new Event("2013-11-28", "14:43", Event.EVENT, "Atlassian"));
		t.add(new Event("2013-11-28", "10:46", Event.EVENT, "Konsultlunch"));
		t.add(new Event("2013-11-28", "15:40", Event.WORKEND));
		
		// save
		assertTrue("File should save successfully", t.save());
		
		// load
		Times r = new Times();
		assertTrue("File should load successfully", r.load());
		
		// We need to get the list sorted.
		ArrayList<Event> b = t.getDate("2013-11-28");
		ArrayList<Event> c = r.getDate("2013-11-28");
		
		assertEquals("Saved content should have same length as original", t.size(), r.size());
		for (int i = 0; i < t.size(); i++) {
			assertTrue("Saved content should be the same as original at " + i + " " +  c.get(i).toString() + " != " + b.get(i).toString(), 
					c.get(i).toString().equals(b.get(i).toString()));
		}
		
		// Save again should not save, that is dirty should be maintained
		assertFalse("File should not save a second time unless there are changes", t.save());
		
		// Do a change and save again, that is dirty should be maintained
		Event dirty = new Event("2013-11-28", "08:10", Event.EVENT, "Verify dirty handling");
		t.replace(beginWork, dirty);
		assertTrue("File should be saved as there are changes", t.save());
		
		// Verify that an add appends directly to the file
		t.add(beginWork);
		assertFalse("File should not be saved as event was appended", t.save());

		// Verify that appended elements have correct data
		Event eAppend = new Event("2013-11-28", "10:47", Event.EVENT, "Appended EVENT");
		t.add(eAppend);
		assertFalse("File should not be saved as second event was appended", t.save());
		
		Times a = new Times();
		assertTrue("File should load successfully", a.load());
		ArrayList<Event> x = t.getDate("2013-11-28");
		ArrayList<Event> y = a.getDate("2013-11-28");
		for (int i = 0; i < x.size(); i++) {
			assertTrue("Saved content should be the same as original at " + i + " " +  x.get(i).toString() + " != " + y.get(i).toString(), 
					x.get(i).toString().equals(y.get(i).toString()));
		}
		

	}

}
