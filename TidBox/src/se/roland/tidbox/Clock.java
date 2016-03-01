/**
 * Licens
 */
package se.roland.tidbox;

import java.text.NumberFormat;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.FormatStyle;
import java.time.format.TextStyle;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalField;
import java.time.temporal.WeekFields;
import java.util.ArrayList;
import java.util.Locale;
import java.util.Timer;
import java.util.TimerTask;


/**
 * <p>
 * Running clock</p>
 * <p>
 * Timer ticks once a second.</p>
 * <p>
 * Date and time is available for simple access.</p>
 * <p>
 * Second events are subscribable.</p>
 * <p>
 * 2015-11-20 Modified to use Java 8 java.time.</p>
 * <p>
 * TODO Clas name Clock does clash with java.time.Clock, do we need to fix this?</p>
 * 
 * @author Roland Vallgren
 */
public class Clock extends TimerTask {
	
	private Locale swedishLocale;
	private ZonedDateTime nowDateTime;
	private ZonedDateTime lastDateTime;
	private NumberFormat nf = NumberFormat.getInstance();
	private TemporalField weekOfYearField; 
	ArrayList<ClockEventMethod> secondTimers = new ArrayList<ClockEventMethod>(1);
	private Timer clockTimer;
	private int second;
	private long lastTimeMillis = 0;


	/**
	 * 
	 * @return millis Execution time in milliseconds of last clock tick
	 */
	public long getLastTimeMillis() {
		return lastTimeMillis;
	}

	/**
	 * Constructor
	 */
	public Clock() {
		this.swedishLocale = new Locale("sv", "SE");
		Locale.setDefault(this.swedishLocale);
		weekOfYearField = WeekFields.of(Locale.getDefault()).weekOfWeekBasedYear();
		this.nowDateTime = ZonedDateTime.now();
		this.lastDateTime = nowDateTime.minusSeconds(1);
		nf.setMinimumIntegerDigits(2);
		nf.setMaximumIntegerDigits(4);
		nf.setGroupingUsed(false);
	}

	/**
	 * Create Clock with defined start time
	 * 
	 * @param millis Time in milliseconds to start clock in
	 */
	public Clock(java.time.Clock fixedClock) {
		this();
		this.nowDateTime = ZonedDateTime.now(fixedClock);
		this.lastDateTime = nowDateTime.minusSeconds(1);
		
		ticked();
	}

//	public long getTimeInMilliseconds() {
//		long tmp = nowDateTime.
//		return calendar.getTimeInMillis();
//	}

	public int getYearI() {
		return nowDateTime.getYear();
	}

	public String getYear() {
		return this.nf.format(this.getYearI());
	}

	public int getMonthI() {
		return nowDateTime.getMonthValue();
	}

	public String getMonth() {
		return this.nf.format(getMonthI());
	}
	
	public int getDayI() {
		return nowDateTime.getDayOfMonth();
	}
	
	public String getDay() {
		return this.nf.format(getDayI());
	}

	public String getDate() {
		return nowDateTime.toLocalDate().toString();
	}

	public int getHourI() {
		return nowDateTime.getHour();
	}
	
	public String getHour() {
		return this.nf.format(getHourI());
	}

	public int getMinuteI() {
		return nowDateTime.getMinute();
	}
	
	public String getMinute() {
		return this.nf.format(getMinuteI());
	}

	public int getSecondI() {
		return second;
	}
	
	public String getSecond() {
		return this.nf.format(getSecondI());
	}

	public String getTime() {
		return nowDateTime.toLocalTime().truncatedTo(ChronoUnit.MINUTES).toString();
	}

	public String getDateTime() {	
//		return String.join(" ", this.getDate(), nowDateTime.toLocalTime().truncatedTo(ChronoUnit.SECONDS).toString());
		return String.join(" ", this.getDate(), nowDateTime.format(DateTimeFormatter.ofLocalizedTime(FormatStyle.MEDIUM)));
	}

	public String getWeek() {
		return this.nf.format(nowDateTime.get(weekOfYearField));
	}

	public String getDayOfWeek() {
		String d = nowDateTime.getDayOfWeek().getDisplayName(TextStyle.FULL_STANDALONE, this.swedishLocale);
		return d.substring(0, 1).toUpperCase() + d.substring(1);
	}

	/**
	 * Start timer to activate a clock tick once a second 
	 */
	public void start() {
		clockTimer = new Timer();
		clockTimer.schedule(this, 1000, 1000);
	}
	
//	@Override
//	public void actionPerformed(ActionEvent e) {
//		tick();
//	}
	
	/**
	 * Tick clock and set time in calendar
	 * 
	 * @param s Time in seconds to set
	 */
	public void tick(int s) {
		this.lastDateTime = this.nowDateTime;
		this.nowDateTime = lastDateTime.plusSeconds(s);
		ticked();
	}

	// TODO: Keep timer running even though work takes a long time Own thread? How do I do that?
	/**
	 * Called when timer runs out and registers time now
	 * Should be called once a second
	 */
	public void tick() {
		long s = System.currentTimeMillis();
		this.lastDateTime = this.nowDateTime;
		this.nowDateTime = ZonedDateTime.now();
		ticked();
		lastTimeMillis  = System.currentTimeMillis() - s;
		
		
	}
	
	
	/**
	 * Tasks to be performed when clock was ticked
	 * Call subscriptions for new second events
	 */
	private void ticked() {
		int s = nowDateTime.getSecond();
		if (s != second) {
			second = s;
			for (ClockEventMethod e : this.secondTimers) {
				e.executeEvent(e);
			}
		}
	}

	/**
	 * Add a new subscription for second events 
	 * @param e
	 */
	public void timerSecond(ClockEventMethod e) {
		this.secondTimers.add(e);
	}


	/**
	 * Stop timer when program is ended
	 */
	public void stop() {
		this.secondTimers.clear();
		clockTimer.cancel();
	}

	/* (non-Javadoc)
	 * @see java.util.TimerTask#run()
	 */
	@Override
	public void run() {
		tick();
	}

}
