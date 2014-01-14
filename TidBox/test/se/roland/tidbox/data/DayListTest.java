package se.roland.tidbox.data;

import static org.junit.Assert.*;

import java.util.ArrayList;

import org.junit.Test;

/**
 * @author Roland Vallgren
 *
 */
public class DayListTest {

	/*
	 * Create Times, a list of events
	 * - Add event
	 * - get events for a date
	 * - Remove event
	 */
	@Test
	public void testCreateDayList() {
//		Times tmp = new Times();
		DayList d = new DayList(new Times());
		
		Event ePause = new Event("2013-01-01", "23:59", Event.PAUSE);
		d.add(ePause);
		
		ArrayList<Event> empty = d.getDate("2012-01-01");

		assertNotNull(empty);
		assertTrue(empty instanceof ArrayList<?>);
		assertEquals(0, empty.size());

		ArrayList<Event> tDate = d.getDate("2013-01-01");

		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0) instanceof Event);
		Event eCheck = tDate.get(0);
		assertEquals(ePause, eCheck);
		
		Event eEvent = new Event("2013-01-01", "01:01", Event.EVENT, "An event");
		d.add(eEvent);
		
		tDate = d.getDate("2013-01-01");
		
		assertEquals(2, tDate.size());
		for (Event eCh : tDate) {
			assertTrue(eCh instanceof Event);
		}
		// Verify event list is sorted
		eCheck = tDate.get(0);
		assertEquals(eEvent, eCheck);
		eCheck = tDate.get(1);
		assertEquals(ePause, eCheck);
		
//		TODO: Remove. Here only remove by sending the Event works.
		d.remove(eCheck);

		tDate = d.getDate("2013-01-01");
		assertEquals(1, tDate.size());
		assertTrue(tDate.get(0) instanceof Event);
		eCheck = tDate.get(0);
		assertEquals(eEvent, eCheck);
	}

	/*
	 * Test daylist handling with index
	 * - Return event for index
	 * 
	 */
	@Test
	public void testGetDate() {
		DayList d = new DayList(new Times());
		
		// Undo and Redo are empty
		assertTrue(d.isUndoEmpty());
		assertTrue(d.isRedoEmpty());

		// Add events unsorted
		String date = "2013-11-06";
		Event eBeginWork = new Event(date, "15:49", Event.BEGINWORK);
		Event ePause = new Event(date, "15:50", Event.PAUSE);
		Event eEndPause = new Event(date, "15:51", Event.ENDPAUSE);
		Event eEvent = new Event(date, "15:52", Event.EVENT, "An event");
		Event eEndEvent = new Event(date, "15:53", Event.ENDEVENT);
		Event eWorkEnd = new Event(date, "15:54", Event.WORKEND);

		d.add(eBeginWork);
		d.add(eEndPause);
		d.add(ePause);
		d.add(eEndEvent);
		d.add(eEvent);
		d.add(eWorkEnd);
		
		ArrayList<Event> l = d.getDate(date);
		
		assertEquals(eBeginWork, d.get(0));
		assertEquals(eWorkEnd, d.get(5));
		Event cBeginWork = eBeginWork.clone();
		assertNotEquals(cBeginWork, d.get(0));
		assertFalse(d.isUndoEmpty());
		assertTrue(d.isRedoEmpty());
		
		// Test replace
		l = d.getDate(date);
		eEvent = l.get(3);
		Event eGotten = eEvent.clone();
		Event eReplace = new Event(date, "15:52", Event.EVENT, "Replace event");
		d.replace(eEvent, eReplace);
		// FIXME Test that replace changes dirty in times to make sure change is saved to file 
		
		ArrayList<Event> r = d.getDate(date);
		
		assertEquals(l.size(), r.size());
		assertNotEquals(eGotten, r.get(3));
		
		// Test remove
		l = d.getDate(date);
		eEvent = l.get(3);
		eGotten = eEvent.clone();
		d.remove(eEvent);
		
		r = d.getDate(date);
		
		assertTrue(l.size() > r.size());
		assertFalse(r.indexOf(eEvent) >= 0);
		
		// Undo remove
		l = d.getDate(date);
		d.undo();
		r = d.getDate(date);
		
		assertTrue(l.size() < r.size());
		assertTrue(r.indexOf(eEvent) >= 0);
		assertFalse(d.isUndoEmpty());
		assertFalse(d.isRedoEmpty());
		
		// Redo remove
		l = d.getDate(date);
		d.redo();
		r = d.getDate(date);
		
		assertTrue(l.size() > r.size());
		assertFalse(r.indexOf(eEvent) >= 0);
		
	}
	
}
