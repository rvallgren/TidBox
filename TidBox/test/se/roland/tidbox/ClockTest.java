/**
 * 
 */
package se.roland.tidbox;

import static org.junit.Assert.*;
import java.time.Instant;
import java.time.ZoneId;
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
 * NOTE: Actually this test mostly tests the standard implementation of java.timeZonedDateTime
 * 
*/

public class ClockTest implements ClockEventMethod{

//	Test 2013-10-10 09:54:01
//	long testTime = 1381391641120L;
//	Test 2015-11-20 14:28:46
//	long testTime = 1448026126569L;
//	Test 2015-10-21 15:46:02 Onsdag vecka 43
	final static long testTime = 1445435162626L;
	final static int testDateYearI   = 2015;
	final static int testDateMonthI  = 10;
	final static int testDateDayI    = 21;
	final static int testDateHourI   = 15;
	final static int testDateMinuteI = 46;
	final static int testDateSecondI =  2;
	final static int testDateWeekI   = 43;
	// Set to 1 if the year after test year not is a leap year
	final static int leapYearAdjust  =  0;

	final String testDateStr    = String.join("-", formatTwoDigits(testDateYearI),
			formatTwoDigits(testDateMonthI),
			formatTwoDigits(testDateDayI));
	final String testTimeStr    = String.join(":", formatTwoDigits(testDateHourI), formatTwoDigits(testDateMinuteI));
	final String testDateTime   = String.join(" ", testDateStr,
			String.join(":", testTimeStr, formatTwoDigits(testDateSecondI)));
	
	private boolean timerExecuted;

	private Clock setup(long time) {
		return new Clock(java.time.Clock.fixed(Instant.ofEpochMilli(time), ZoneId.of("Europe/Stockholm")));
//		return new Clock(time);
	}

	private Clock setup() {
		return setup(testTime);
	}
	
	private String formatTwoDigits(int i) {
		String res;
		if (i < 10) {
			res = "0" + Integer.toString(i);
		} else {
			res = Integer.toString(i);
		}
		return res;
	}
	
	
	
	@Test
	public void testCreateClock() {
		Clock cl = this.setup();
		
//		assertEquals(testTime, cl.getTimeInMilliseconds());

		assertEquals(testDateTime, cl.getDateTime());

		assertEquals(formatTwoDigits(testDateYearI), cl.getYear());
		assertEquals(formatTwoDigits(testDateMonthI), cl.getMonth());
		assertEquals(formatTwoDigits(testDateDayI), cl.getDay());
		assertEquals(testDateYearI, cl.getYearI());
		assertEquals(testDateMonthI, cl.getMonthI());
		assertEquals(testDateDayI, cl.getDayI());
		assertEquals(testDateStr, cl.getDate());
		assertEquals(formatTwoDigits(testDateWeekI), cl.getWeek());
		assertEquals("Onsdag", cl.getDayOfWeek());

		assertEquals(formatTwoDigits(testDateHourI), cl.getHour());
		assertEquals(formatTwoDigits(testDateMinuteI), cl.getMinute());
		assertEquals(formatTwoDigits(testDateSecondI), cl.getSecond());
		assertEquals(testDateHourI, cl.getHourI());
		assertEquals(testDateMinuteI, cl.getMinuteI());
		assertEquals(testDateSecondI, cl.getSecondI());
		assertEquals(testTimeStr, cl.getTime());
		
		
		// Tick clock once, step one second
		cl.tick(1);

		assertEquals(testDateStr, cl.getDate());
		assertEquals(testTimeStr, cl.getTime());
		assertEquals(formatTwoDigits(testDateSecondI + 1), cl.getSecond());

		// Tick clock once, step one minute
		cl.tick(60);
		String testIncMinuteStr = String.join(":", formatTwoDigits(testDateHourI), formatTwoDigits(testDateMinuteI + 1));
		
		assertEquals(testDateStr, cl.getDate());
		assertEquals(testIncMinuteStr, cl.getTime());
		assertEquals(formatTwoDigits(testDateSecondI + 1), cl.getSecond());
		
		// Tick clock once, step one hour
		cl.tick(60 * 60);
		String testIncTimeStr = String.join(":", formatTwoDigits(testDateHourI + 1), formatTwoDigits(testDateMinuteI + 1));
		
		assertEquals(testDateStr, cl.getDate());
		assertEquals(testIncTimeStr, cl.getTime());
		assertEquals(formatTwoDigits(testDateSecondI + 1), cl.getSecond());
		
		// Tick clock once, step 24 hours, one day
		cl.tick(60 * 60 * 24);
		String testIncDay    = String.join("-", formatTwoDigits(testDateYearI),
				formatTwoDigits(testDateMonthI),
				formatTwoDigits(testDateDayI + 1));
		
		assertEquals(testIncDay, cl.getDate());
		assertEquals(testIncTimeStr, cl.getTime());
		assertEquals(formatTwoDigits(testDateSecondI + 1), cl.getSecond());
		
		// Tick clock once, step 31 days
		cl.tick(60 * 60 * 24 * 31);
		String testIncMonth    = String.join("-", formatTwoDigits(testDateYearI),
				formatTwoDigits(testDateMonthI + 1),
				formatTwoDigits(testDateDayI + 1));
		
		assertEquals(testIncMonth, cl.getDate());
		// Scary, end of daylight saving
		assertEquals(testIncMinuteStr, cl.getTime());
// TODO		assertEquals(testIncTimeStr, cl.getTime());
		assertEquals(formatTwoDigits(testDateSecondI + 1), cl.getSecond());
		
		// Tick clock once, step 365 days
		cl.tick(60 * 60 * 24 * 365);
		// Cool: Leap year
		String testIncYear = String.join("-", formatTwoDigits(testDateYearI + 1),
				formatTwoDigits(testDateMonthI + 1),
				formatTwoDigits(testDateDayI + leapYearAdjust));
		
		assertEquals(testIncYear, cl.getDate());
		assertEquals(testIncMinuteStr, cl.getTime());
		assertEquals(formatTwoDigits(testDateSecondI + 1), cl.getSecond());
		
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

