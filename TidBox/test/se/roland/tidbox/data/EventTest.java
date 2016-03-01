/**
 * 
 */
package se.roland.tidbox.data;

import static org.junit.Assert.*;

import org.junit.Test;

/**
 * Event should be an immutable object
 * 
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
		Event ePause = Event.make("2013-10-30", "15:25", Event.PAUSE);

		assertEquals("2013-10-30", ePause.getDate());
		assertEquals("15:25", ePause.getTime());
		assertEquals(Event.PAUSE, ePause.getState());
		assertNull(ePause.getActivity());
		
		assertEquals("15:25,PAUS", ePause.dayString());
		assertEquals("2013-10-30,15:25,PAUS", ePause.toString());
		
		Event eEvent = Event.make("2013-10-30", "15:46", Event.EVENT, "Activity");
		
		assertEquals("2013-10-30", eEvent.getDate());
		assertEquals("15:46", eEvent.getTime());
		assertEquals(Event.EVENT, eEvent.getState());
		assertEquals("Activity", eEvent.getActivity());
		assertEquals("15:46,EVENT,Activity", eEvent.dayString());
		assertEquals("2013-10-30,15:46,EVENT,Activity", eEvent.toString());
		
		// Change events
		// Immutable does not change, a new Event is returned
		Event ePauseNewDate = ePause.changeDate("2013-01-01");
		Event ePauseNewTime = ePause.changeTime("07:18");
		Event ePauseNewState = ePause.changeState(Event.ENDPAUSE);
		
		assertEquals("2013-01-01", ePauseNewDate.getDate());
		assertEquals("07:18", ePauseNewTime.getTime());
		assertEquals(Event.ENDPAUSE, ePauseNewState.getState());
		assertNull(ePause.getActivity());

		Event ePauseNewEventActivity = ePause.changeEventActivity("Activity changed");
		
		assertEquals(Event.EVENT, ePauseNewEventActivity.getState());
		assertEquals("Activity changed", ePauseNewEventActivity.getActivity());

		// Activity is "null" when not an EVENT
		Event ePauseNewPause = ePause.changeState(Event.PAUSE);
		assertNull(ePauseNewPause.getActivity());
		Event ePauseNewEventEmpty = ePause.changeState(Event.EVENT);
		assertEquals("", ePauseNewEventEmpty.getActivity());
		
		// Clone event
		Event eClone = eEvent.clone();
		assertEquals(eClone.getDate(), eEvent.getDate());
		assertEquals(eClone.getTime(), eEvent.getTime());
		assertEquals(eClone.getState(), eEvent.getState());
		assertEquals(eClone.getActivity(), eEvent.getActivity());
	
		// Copy event information from another event
		Event eCopy = Event.make("2010-01-01", "01:01", Event.WORKEND);
		
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
		Event ePause = Event.make("2013-10-30", "15:25", Event.PAUSE);
		Event eEndPause = Event.make("2013-10-30", "15:25", Event.ENDPAUSE);
		Event eWork = Event.make("2013-10-30", "15:25", Event.BEGINWORK);
		Event eEndWork = Event.make("2013-10-30", "15:25", Event.WORKEND);
		Event eEvent = Event.make("2013-10-30", "15:25", Event.EVENT, "Project,Task,Art,Kommentar text");
		Event eEventEmpty = Event.make("2013-10-30", "15:25", Event.EVENT);
		Event eEndEvent = Event.make("2013-10-30", "15:25", Event.ENDEVENT);
		
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
		Event event = Event.make("2013-11-06", "16:38", Event.PAUSE);
		
		assertEquals(2013, event.getYearI());
		assertEquals(11, event.getMonthI());
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
		Event eA = Event.make("2013-11-10", "15:25", Event.WORKEND);
		Event eB = Event.make("2013-11-11", "14:25", Event.PAUSE);
		Event eC = Event.make("2013-11-11", "14:25", Event.PAUSE);
		
		assertTrue(eA.compareTo(eB) < 0);
		assertTrue(eB.compareTo(eA) > 0);
		assertEquals(0, eB.compareTo(eC));

		// Should have the same hash code if they are  comparable and equal
		assertNotEquals("Should have different hashCode", eA.hashCode(), eB.hashCode());
		assertEquals("Should have same hashCode", eB.hashCode(), eC.hashCode());
		Event eE = Event.make("2013-11-11", "14:25", Event.EVENT, "Must have same hashCode");
		Event eF = Event.make("2013-11-11", "14:25", Event.EVENT, "Must have same hashCode");
		Event eG = Event.make("2013-11-11", "14:25", Event.EVENT, "Must have different hashCode");
		assertEquals("Should have same hashCode", eE.hashCode(), eF.hashCode());
		assertNotEquals("Should have different hashCode", eE.hashCode(), eG.hashCode());
		
//		Compare times
		Event eACD = eA.changeDate(eB.getDate());

		assertTrue(eACD.compareTo(eB) > 0);
		assertTrue(eB.compareTo(eACD) < 0);
		
		Event eACT = eB.changeTime(eA.getTime());

		assertTrue(eACT.compareTo(eB) > 0);
		assertTrue(eB.compareTo(eACT) < 0);

//		Compare state
//		Compare activity
		Event eAnewEvent = eA.changeEventActivity("A");
		Event eBnewEvent = eB.changeEventActivity("B");
		Event eCnewEvent = eC.changeEventActivity("B");

		assertTrue(eAnewEvent.compareTo(eBnewEvent) < 0);
		assertTrue(eBnewEvent.compareTo(eAnewEvent) > 0);
		assertEquals(0, eBnewEvent.compareTo(eCnewEvent));
	}


}
