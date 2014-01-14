package se.roland.tidbox.data;

import java.util.HashMap;

public class Event implements Comparable<Event>, Cloneable {

	/**
	 * Constants defining states
	 */
	public static final String BEGINWORK = "BEGINWORK";
	public static final String WORKEND = "WORKEND";
	public static final String PAUSE = "PAUS";
	public static final String ENDPAUSE = "ENDPAUS";
	public static final String EVENT = "EVENT";
	public static final String ENDEVENT = "ENDEVENT";
	
	private static final HashMap<String, String> showStrings = new HashMap<String, String>();
	{
		showStrings.put(BEGINWORK, "Börja arbetsdagen"); 
		showStrings.put(WORKEND, "Sluta arbetsdagen"); 
		showStrings.put(PAUSE, "Börja paus"); 
		showStrings.put(ENDPAUSE, "Sluta paus"); 
		showStrings.put(EVENT, "Börja händelse"); 
		showStrings.put(ENDEVENT, "Sluta händelse");
	}

	
	/**
	 * Fields
	 * date
	 * time
	 * state
	 * state == EVENT
	 * 	[activity]
	 */
	private String date;
	private String time;
	private String state;
// TODO: activity: own class???
	private String activity;
	
	/**
	 * Constructor
	 * @param date
	 * @param time
	 * @param state
	 */
	public Event(String date, String time, String state) {
		this.date = date;
		this.time = time;
		this.state = state;
		if (state.equals(Event.EVENT)) {
			this.activity = "";
		}
	}

	/**
	 * Constructor
	 * @param date
	 * @param time
	 * @param state
	 * @param event activity
	 */
	public Event(String date, String time, String state, String activity) {
		this(date, time, state);
		this.activity = activity;
	}

	public String getDate() {
		return date;
	}

	public void setDate(String date) {
		this.date = date;
	}

	public String getTime() {
		return time;
	}

	public void setTime(String time) {
		this.time = time;
	}

	public String getState() {
		return state;
	}

	public void setState(String state) {
		if ( ! this.state.equals(state)) {
			if (state.equals(EVENT)) {
				this.activity = "";
			} else {
				this.activity = null;
			}
		}
		this.state = state;
	}

	public String getActivity() {
		return activity;
	}

	public void setActivity(String activity) {
		this.activity = activity;
	}

	public String dayString() {
		if (state.equals(Event.EVENT)) {
			return time + "," + state + "," + activity;
		} else {
//			return time + "," + state + ",";
			return time + "," + state;
		}
	}

	@Override
	public String toString() {
		return date + "," + dayString();
	}

	public String format() {
		if (state.equals(Event.EVENT) && activity.length() > 0) {
			return time + "  " + activity;
		} else {
			return time + "  " + showStrings.get(state);
		}
	}
	
	@Override
	public int compareTo(Event o) {
		int c = this.date.compareTo(o.getDate());
		if (c != 0)
			return c;
		c = this.time.compareTo(o.getTime());
		if (c != 0)
			return c;
		c = this.state.compareTo(o.getState());
		if (c != 0)
			return c;
		// Both are equal, If EVENT, then compare activity
		if (! this.state.equals(Event.EVENT))
			return 0;
		return this.activity.compareTo(o.getActivity());
	}

	@Override
	public int hashCode() {
		int hash = date.hashCode() + time.hashCode()*13+state.hashCode()*17;
		if (activity != null) {
			hash += activity.hashCode();
		}
		return hash;
	}
	
	public Event clone() {
		if (state.equals(Event.EVENT) && activity.length() > 0) {
			return new Event(date, time, state, activity);
		} else {
			return new Event(date, time, state);
		}
	}

	public void copy(Event e) {
		this.date = e.getDate();
		this.time = e.getTime();
		this.state = e.getState();
		if (state.equals(Event.EVENT)) {
			this.activity = e.getActivity();
		} else {
			this.activity = "";
		}
	}

	// TODO: Should use Calendar parse instead!!
	//       or maybe Event should have date and time as a Calendar object
	public int getYearI() {
		return Integer.parseInt(date.substring(0, 4));
	}

	public int getMonthI() {
		return Integer.parseInt(date.substring(5, 7)) - 1;
	}

	public int getDayI() {
		return Integer.parseInt(date.substring(8));
	}

	public int getHourI() {
		return Integer.parseInt(time.substring(0, 2));
	}

	public int getMinuteI() {
		return Integer.parseInt(time.substring(3));
	}


	
}
