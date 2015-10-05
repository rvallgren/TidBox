/**
 * Licens
 */
package se.roland.tidbox;

//import java.awt.event.ActionEvent;
//import java.awt.event.ActionListener;
import java.text.DateFormat;
import java.text.NumberFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Locale;
import java.util.Timer;
//import javax.swing.Timer;
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
 * 
 * @author Roland Vallgren
 */
//public class Clock extends GregorianCalendar {
//public class Clock implements ActionListener {
/**
 * @author vallgrol
 *
 */
public class Clock extends TimerTask {
	
//	private GregorianCalendar calendar;
	private Locale swedishLocale;
	private Calendar calendar;
	private DateFormat df = DateFormat.getDateInstance(DateFormat.SHORT);
	private DateFormat tf = DateFormat.getTimeInstance(DateFormat.SHORT);
	private NumberFormat nf = NumberFormat.getInstance();
	ArrayList<ClockEventMethod> secondTimers = new ArrayList<ClockEventMethod>(1);
	private Timer clockTimer;
	private int second;
	private long lastTimeMillis = 0;
//	private TimerTask task;

//	setMinimumIntegerDigits

	/**
	 * 
	 * @return millis Time in milliseconds of last clock tick
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
		this.calendar = Calendar.getInstance();
//		df.getNumberFormat().setMinimumIntegerDigits(2);
//		tf.getNumberFormat().setMinimumIntegerDigits(2);
		nf.setMinimumIntegerDigits(2);
		nf.setMaximumIntegerDigits(4);
		nf.setGroupingUsed(false);
	}

	/**
	 * Create Clock with defined start time
	 * 
	 * @param millis Time in milliseconds to start clock in
	 */
	public Clock(long millis) {
		this();
		this.calendar.setTimeInMillis(millis);
		ticked();
	}

	public long getTimeInMilliseconds() {
		return calendar.getTimeInMillis();
	}

	public int getYearI() {
		return calendar.get(Calendar.YEAR);
	}

	public String getYear() {
		return this.nf.format(this.getYearI());
	}

	public int getMonthI() {
		return calendar.get(Calendar.MONTH);
	}

	public String getMonth() {
		return this.nf.format(getMonthI() + 1);
	}
	
	public int getDayI() {
		return calendar.get(Calendar.DAY_OF_MONTH);
	}
	
	public String getDay() {
		return this.nf.format(getDayI());
	}

	public String getDate() {
		return this.df.format(calendar.getTime());
	}

	public int getHourI() {
		return calendar.get(Calendar.HOUR_OF_DAY);
	}
	
	public String getHour() {
		return this.nf.format(getHourI());
	}

	public int getMinuteI() {
		return calendar.get(Calendar.MINUTE);
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
		return this.tf.format(calendar.getTime());
	}

	public String getDateTime() {	
		return this.getDate() + " " + this.getTime() + ":" + this.getSecond();
	}

	/**
	 * Start timer to activate a clock ticke once a second 
	 */
	public void start() {
//		clockTimer = new Timer(1000, this);
//		clockTimer = new Timer(6000, this);
//		clockTimer.start();
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
		this.calendar.add(Calendar.SECOND, s);
		ticked();
	}

	// TODO: Keep timer running even though work takes a long time Own thread? How do I do that?
	/**
	 * Called when timer runs out and registers time now
	 * Should be called once a second
	 */
	public void tick() {
		long s = System.currentTimeMillis();
		this.calendar.setTimeInMillis(System.currentTimeMillis());
		ticked();
		lastTimeMillis  = System.currentTimeMillis() - s;
	}
	
	
	/**
	 * Tasks to be performed when clock was ticked
	 * Call subscriptions for new second events
	 */
	private void ticked() {
		int s = calendar.get(Calendar.SECOND);
		if (s != second) {
			second = s;
			for (ClockEventMethod e : this.secondTimers) {
				e.executeEvent(e);
			}
		}
	}

//	public synchronized void timerSecond(ClockEventMethod e) {
	/**
	 * Add a new subscription for second events 
	 * @param e
	 */
	public void timerSecond(ClockEventMethod e) {
		this.secondTimers.add(e);
	}

	public String getWeek() {
		return this.nf.format(calendar.get(Calendar.WEEK_OF_YEAR));
	}

	public String getDayOfWeek() {
		String d = calendar.getDisplayName(Calendar.DAY_OF_WEEK, Calendar.LONG, this.swedishLocale);
		return d.substring(0, 1).toUpperCase() + d.substring(1);
	}

	/**
	 * Stop timer when program is ended
	 */
	public void stop() {
//		clockTimer.stop();
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
