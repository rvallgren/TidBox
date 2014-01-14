/**
 * 
 */
package se.roland.tidbox;

import static org.junit.Assert.*;
import org.junit.Test;

/**
 * @author Roland Vallgren
 * 
 * Clock
 * 
 * Tick once a second, read system time and keep time internally
 *
 * Getters:
 * 	time, date, year, month, day, weekday, weeknumber, hour, minute, (second optional).
 * 
 * Repeat: call method once every second, minute, hour, day, ?
 * 
 * Display clock in Gui?
 * 
 * Standard Java support?
 *
 */

/*
 * ClockTest.testCreateClock
 * 
 * NOTE: Actually this test mostly tests the standard implementation of java.util.GregorianCalendar
 * 
 * 1381391641120L
 * 
 * java.util.GregorianCalendar
 * [
 *  time=1381391641120,
 *  areFieldsSet=true,
 *  areAllFieldsSet=true,
 *  lenient=true,
 *  zone=sun.util.calendar.ZoneInfo
 *   [
 *    id="Europe/Berlin",
 *    offset=3600000,
 *    dstSavings=3600000,
 *    useDaylight=true,
 *    transitions=143,
 *    lastRule=java.util.SimpleTimeZone
 *     [
 *      id=Europe/Berlin,
 *      offset=3600000,
 *      dstSavings=3600000,
 *      useDaylight=true,
 *      startYear=0,
 *      startMode=2,
 *      startMonth=2,
 *      startDay=-1,
 *      startDayOfWeek=1,
 *      startTime=3600000,
 *      startTimeMode=2,
 *      endMode=2,
 *      endMonth=9,
 *      endDay=-1,
 *      endDayOfWeek=1,
 *      endTime=3600000,
 *      endTimeMode=2
 *     ]
 *   ],
 *  firstDayOfWeek=2,
 *  minimalDaysInFirstWeek=4,
 *  ERA=1,
 *  YEAR=2013,
 *  MONTH=9,
 *  WEEK_OF_YEAR=41,
 *  WEEK_OF_MONTH=2,
 *  DAY_OF_MONTH=10,
 *  DAY_OF_YEAR=283,
 *  DAY_OF_WEEK=5,
 *  DAY_OF_WEEK_IN_MONTH=2,
 *  AM_PM=0,
 *  HOUR=9,
 *  HOUR_OF_DAY=9,
 *  MINUTE=54,
 *  SECOND=1,
 *  MILLISECOND=120,
 *  ZONE_OFFSET=3600000,
 *  DST_OFFSET=3600000
 * ]
*/

public class ClockTest implements ClockEventMethod{

	long testTime = 1381391641120L;
	private boolean timerExecuted;

	private Clock setup(long time) {
		return new Clock(time);
	}

	private Clock setup() {
		return setup(testTime);
	}
	
	@Test
	public void testCreateClock() {
//		Test 2013-10-10 09:54:01
		Clock cl = this.setup();
		
		assertEquals(testTime, cl.getTimeInMilliseconds());

		assertEquals("2013", cl.getYear());
		assertEquals("10", cl.getMonth());
		assertEquals("10", cl.getDay());
		assertEquals(2013, cl.getYearI());
		assertEquals(9, cl.getMonthI());
		assertEquals(10, cl.getDayI());
		assertEquals("2013-10-10", cl.getDate());
		assertEquals("41", cl.getWeek());
		assertEquals("Torsdag", cl.getDayOfWeek());

		assertEquals("09", cl.getHour());
		assertEquals("54", cl.getMinute());
		assertEquals("01", cl.getSecond());
		assertEquals(9, cl.getHourI());
		assertEquals(54, cl.getMinuteI());
		assertEquals(1, cl.getSecondI());
		assertEquals("09:54", cl.getTime());
		
		assertEquals("2013-10-10 09:54:01", cl.getDateTime());
		
		// Tick clock once, step one second
		cl.tick(1);

		assertEquals("2013-10-10", cl.getDate());
		assertEquals("09:54", cl.getTime());
		assertEquals("02", cl.getSecond());

		// Tick clock once, step one minute
		cl.tick(60);
		
		assertEquals("2013-10-10", cl.getDate());
		assertEquals("09:55", cl.getTime());
		assertEquals("02", cl.getSecond());
		
		// Tick clock once, step one hour
		cl.tick(60 * 60);
		
		assertEquals("2013-10-10", cl.getDate());
		assertEquals("10:55", cl.getTime());
		assertEquals("02", cl.getSecond());
		
		// Tick clock once, step 24 hours, one day
		cl.tick(60 * 60 * 24);
		
		assertEquals("2013-10-11", cl.getDate());
		assertEquals("10:55", cl.getTime());
		assertEquals("02", cl.getSecond());
		
		// Tick clock once, step 31 days
		cl.tick(60 * 60 * 24 * 31);
		
		assertEquals("2013-11-11", cl.getDate());
		// Scary, end of daylight saving
		assertEquals("09:55", cl.getTime());
		assertEquals("02", cl.getSecond());
		
		// Tick clock once, step 365 days
		cl.tick(60 * 60 * 24 * 365);
		
		assertEquals("2014-11-11", cl.getDate());
		assertEquals("09:55", cl.getTime());
		assertEquals("02", cl.getSecond());
		
	}

/*
 * Test real clock would right now mean a parallell use of java.util.GregorianCalendar
 */
//	@Test
//	public void testRealClock() {
//		Use current time and verify Clock behaviour
//		Clock cl = this.setup();
//		long testMilliSeconds = cl.getTimeInMilliseconds();
//	}

	/*
	 * Test install, trigger and removal of a timed method
	 * Once a second, minute, hour, day 
	 */
	@Test
	public void testClockTimer(){
		Clock cl = this.setup();

//		cl.timerSecond(new timerEvent<V>(this));
//		cl.timerSecond(new ClockEvent(this));
		cl.timerSecond(this);

		this.timerExecuted = false;
		cl.tick();
		
		assertEquals(true, this.timerExecuted);
		
		
	}

	@Override
	public void executeEvent(ClockEventMethod e) {
		this.timerExecuted = true;
	}
}

//class timerEvent<V> implements Callable<V> {
//	
//	private ClockTest ref;
//	
//	public timerEvent<V> (ClockTest t){
//		this.ref = t;
//	}
//
//	@Override
//	public V call() throws Exception {
//		this.ref.executed();
//		return null;
//	}
//	
//}

