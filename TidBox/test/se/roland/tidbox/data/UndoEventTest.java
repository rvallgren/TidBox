package se.roland.tidbox.data;

import static org.junit.Assert.*;

import org.junit.Test;

public class UndoEventTest {

	@Test
	public void undoEvent() {
		UndoEvent u = new UndoEvent();

		assertTrue("Undo is empty from beginnig", u.undoIsEmpty());
		assertTrue("Redo is empty from beginnig", u.redoIsEmpty());
		
		Event ePause = Event.make("2013-01-01", "23:59", Event.PAUSE);
		u.add(ePause);
		
		assertFalse("One item added to undo", u.undoIsEmpty());
		assertTrue("Redo is cleared when undo is added",u.redoIsEmpty());

		Event[] eTmp1 = u.getUndo();
		
		assertTrue("One item removed from undo", u.undoIsEmpty());
		assertFalse("and is moved to redo", u.redoIsEmpty());
		assertTrue(eTmp1[0].equals(ePause));
		assertNull(eTmp1[1]);
		
		Event[] eTmp2 = u.getRedo();
		
		assertTrue(u.redoIsEmpty());
		assertFalse(u.undoIsEmpty());
		assertTrue(eTmp2[0].equals(ePause));
		assertNull(eTmp2[1]);
		
		Event[] eTmp3 = u.getUndo();
		
		assertTrue(u.undoIsEmpty());
		assertFalse(u.redoIsEmpty());
		assertTrue(eTmp3[0].equals(ePause));
		assertNull(eTmp3[1]);
		
		u.add(ePause);
		u.add(ePause);
		assertTrue(u.redoIsEmpty());

		Event[] eTmp4Peek = u.peekUndo();
		
		assertFalse(u.undoIsEmpty());
		assertTrue(u.redoIsEmpty());
		assertTrue(eTmp4Peek[0].equals(ePause));
		assertNull(eTmp4Peek[1]);

		Event[] eTmp4 = u.getUndo();
		
		assertFalse(u.undoIsEmpty());
		assertFalse(u.redoIsEmpty());
		assertTrue(eTmp4[0].equals(eTmp4Peek[0]));
		assertNull(eTmp4[1]);
	}

	@Test
	public void undoReplaceRemove() {
		UndoEvent u = new UndoEvent();

		Event pauseA = Event.make("2013-01-01", "10:00", Event.PAUSE);
		Event pauseB = Event.make("2013-01-01", "11:00", Event.PAUSE);

		// replace
		u.add(pauseA, pauseB);

		Event[] eTmpPeek = u.peekUndo();
		
		assertFalse(u.undoIsEmpty());
		assertTrue(u.redoIsEmpty());
		assertTrue(eTmpPeek[0].equals(pauseA));
		assertTrue(eTmpPeek[1].equals(pauseB));

		Event[] eTmp = u.getUndo();
		
		assertTrue(u.undoIsEmpty());
		assertFalse(u.redoIsEmpty());
		assertTrue(eTmp[0].equals(pauseA));
		assertTrue(eTmp[1].equals(pauseB));

		// Remove
		u.add(null, pauseB);
		
		Event[] eTmp1Peek = u.peekUndo();
		
		assertNull(eTmp1Peek[0]);
		assertTrue(eTmp1Peek[1].equals(pauseB));
		
		Event[] eTmp1 = u.getUndo();
		
		assertNull(eTmp1[0]);
		assertTrue(eTmp1[1].equals(pauseB));
		
	}
}
