package se.roland.tidbox.data;

import static org.junit.Assert.*;

import org.junit.Test;

public class UndoItemTest {

	@Test
	public void undoItem() {
		// Test Add item
		Event eOne = Event.make("2013-01-01", "23:51", Event.PAUSE);
		Event eTwo = Event.make("2013-01-01", "23:52", Event.PAUSE);
//		Event eThree = Event.make("2013-01-01", "23:53", Event.PAUSE);
		UndoItem iAdd = UndoItem.make(eOne);
		UndoItem iChange = UndoItem.make(eTwo, eOne);
		UndoItem iRemove = UndoItem.make(null, eTwo);
		
		Event[] a = iAdd.getEvent();
		assertEquals(2, a.length);
		assertTrue("Items should be equal", a[0].equals(eOne));
		assertNull("Only one item exists", a[1]);
		
		Event[] c = iChange.getEvent();
		assertEquals(2, c.length);
		assertTrue("Items should be equal", c[0].equals(eTwo));
		assertTrue("Items should be equal", c[1].equals(eOne));
		
		Event[] r = iRemove.getEvent();
		assertEquals(2, r.length);
		assertNull(r[0]);
		assertTrue(r[1].equals(eTwo));
		
		
		
	}

}
