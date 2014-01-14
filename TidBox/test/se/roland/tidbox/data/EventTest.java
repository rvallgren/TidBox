/**
 * 
 */
package se.roland.tidbox.data;

import static org.junit.Assert.*;

import org.junit.Test;

/**
 * @author Roland Vallgren
 *
 */
public class EventTest {

	/**
	 * Event
	 * Fields
	 * - date
	 * - time
	 * - state
	 *		BEGINWORK
	 *		WORKEND
	 *		EVENT		+ Required, Need additional activity
	 *		ENDEVENT
	 *		PAUS		+ Required
	 *		ENDPAUS
	 *
	 * Create an event with date, time, state, [activity]
	 * Get fields
	 * Change fields
	 */
	@Test
	public void testCreateEvent() {
		// Create events that have no additional activity
		Event ePause = new Event("2013-10-30", "15:25", Event.PAUSE);

		assertEquals("2013-10-30", ePause.getDate());
		assertEquals("15:25", ePause.getTime());
		assertEquals(Event.PAUSE, ePause.getState());
		assertNull(ePause.getActivity());
		
		assertEquals("15:25,PAUS", ePause.dayString());
		assertEquals("2013-10-30,15:25,PAUS", ePause.toString());
		
		Event eEvent = new Event("2013-10-30", "15:46", Event.EVENT, "Activity");
		
		assertEquals("2013-10-30", eEvent.getDate());
		assertEquals("15:46", eEvent.getTime());
		assertEquals(Event.EVENT, eEvent.getState());
		assertEquals("Activity", eEvent.getActivity());
		assertEquals("15:46,EVENT,Activity", eEvent.dayString());
		assertEquals("2013-10-30,15:46,EVENT,Activity", eEvent.toString());
		
		// Change events
		ePause.setDate("2013-01-01");
		ePause.setTime("07:18");
		ePause.setState(Event.ENDPAUSE);
		
		assertEquals("2013-01-01", ePause.getDate());
		assertEquals("07:18", ePause.getTime());
		assertEquals(Event.ENDPAUSE, ePause.getState());
		assertNull(ePause.getActivity());

		ePause.setState(Event.EVENT);
		ePause.setActivity("Activity changed");
		
		assertEquals(Event.EVENT, ePause.getState());
		assertEquals("Activity changed", ePause.getActivity());

		// Activity is "null" when not an EVENT
		ePause.setState(Event.PAUSE);
		assertNull(ePause.getActivity());
		ePause.setState(Event.EVENT);
		assertEquals("", ePause.getActivity());
		
		// Clone event
		Event eClone = eEvent.clone();
		assertEquals(eClone.getDate(), eEvent.getDate());
		assertEquals(eClone.getTime(), eEvent.getTime());
		assertEquals(eClone.getState(), eEvent.getState());
		assertEquals(eClone.getActivity(), eEvent.getActivity());
	
		// Copy event information from another event
		Event eCopy = new Event("2010-01-01", "01:01", Event.WORKEND);
		
		eCopy.copy(eEvent);
		assertEquals(eCopy.getDate(), eEvent.getDate());
		assertEquals(eCopy.getTime(), eEvent.getTime());
		assertEquals(eCopy.getState(), eEvent.getState());
		assertEquals(eCopy.getActivity(), eEvent.getActivity());
}
	
	/**
	 * Test formatting of events
	 * Tidbox::Calculate::format
	 * 
	 * BEGINWORKDAY => Börja arbetsdagen
	 * ENDWORKDAY   => Sluta arbetsdagen
	 * BEGINPAUS    => Börja paus
	 * ENDPAUS      => Sluta paus
	 * BEGINEVENT   => Börja händelse
	 * ENDEVENT     => Sluta händelse
	 * 
	 * Format:
	 * BEGINEVENT	time  Börja händelse
	 * TODO: Format events better? Alias handling?
	 *              time  proj,task,art,kommentar
	 * BEGINPAUS    time  Börja paus
	 */
	@Test
	public void testEventFormatting(){
		Event ePause = new Event("2013-10-30", "15:25", Event.PAUSE);
		Event eEndPause = new Event("2013-10-30", "15:25", Event.ENDPAUSE);
		Event eWork = new Event("2013-10-30", "15:25", Event.BEGINWORK);
		Event eEndWork = new Event("2013-10-30", "15:25", Event.WORKEND);
		Event eEvent = new Event("2013-10-30", "15:25", Event.EVENT, "Project,Task,Art,Kommentar text");
		Event eEventEmpty = new Event("2013-10-30", "15:25", Event.EVENT);
		Event eEndEvent = new Event("2013-10-30", "15:25", Event.ENDEVENT);
		
		assertEquals("15:25  Börja paus", ePause.format());
		assertEquals("15:25  Sluta paus", eEndPause.format());
		assertEquals("15:25  Börja arbetsdagen", eWork.format());
		assertEquals("15:25  Sluta arbetsdagen", eEndWork.format());
		assertEquals("15:25  Project,Task,Art,Kommentar text", eEvent.format());
		assertEquals("15:25  Börja händelse", eEventEmpty.format());
		assertEquals("15:25  Sluta händelse", eEndEvent.format());
		
	}

	@Test
	public void testGet() {
		Event event = new Event("2013-11-06", "16:38", Event.PAUSE);
		
		assertEquals(2013, event.getYearI());
		assertEquals(10, event.getMonthI());
		assertEquals(6, event.getDayI());
		assertEquals(16, event.getHourI());
		assertEquals(38, event.getMinuteI());
		
	}
	
	/**
	 * Test comapring events
	 * Compare Priority
	 * - Date
	 * - Time
	 * - Registration: BEGINWORK, ENDEVENT, ENDPAUSE, EVENT, PAUSE, WORKEND
	 * - Event CFG 
	 */
	@Test
	public void testCompareEvent(){
//		Compare dates
		Event eA = new Event("2013-11-10", "15:25", Event.WORKEND);
		Event eB = new Event("2013-11-11", "14:25", Event.PAUSE);
		Event eC = new Event("2013-11-11", "14:25", Event.PAUSE);
		
		assertTrue(eA.compareTo(eB) < 0);
		assertTrue(eB.compareTo(eA) > 0);
		assertEquals(0, eB.compareTo(eC));

		// Should have the same hash code if they are  comparable and equal
		assertNotEquals("Should have different hashCode", eA.hashCode(), eB.hashCode());
		assertEquals("Should have same hashCode", eB.hashCode(), eC.hashCode());
		Event eE = new Event("2013-11-11", "14:25", Event.EVENT, "Must have same hashCode");
		Event eF = new Event("2013-11-11", "14:25", Event.EVENT, "Must have same hashCode");
		Event eG = new Event("2013-11-11", "14:25", Event.EVENT, "Must have different hashCode");
		assertEquals("Should have same hashCode", eE.hashCode(), eF.hashCode());
		assertNotEquals("Should have different hashCode", eE.hashCode(), eG.hashCode());
		
//		Compare times
		eA.setDate(eB.getDate());

		assertTrue(eA.compareTo(eB) > 0);
		assertTrue(eB.compareTo(eA) < 0);
		
//		Compare state
		eA.setTime(eB.getTime());

		assertTrue(eA.compareTo(eB) > 0);
		assertTrue(eB.compareTo(eA) < 0);

//		Compare activity
		eA.setState(Event.EVENT);
		eB.setState(Event.EVENT);
		eC.setState(Event.EVENT);
		eA.setActivity("A");
		eB.setActivity("B");
		eC.setActivity("B");

		assertTrue(eA.compareTo(eB) < 0);
		assertTrue(eB.compareTo(eA) > 0);
		assertEquals(0, eB.compareTo(eC));
	}


}
