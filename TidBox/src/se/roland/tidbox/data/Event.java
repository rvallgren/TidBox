package se.roland.tidbox.data;

import java.util.HashMap;

/**
 * Immutable object Event
 * 
 * @author Roland Vallgren
 */
public class Event implements Comparable<Event>, Cloneable {

	/**
	 * Constants defining states
	 * TODO Extract to own definitions class
	 */
	public static final String BEGINWORK = "BEGINWORK";
	public static final String WORKEND = "WORKEND";
	public static final String PAUSE = "PAUS";
	public static final String ENDPAUSE = "ENDPAUS";
	public static final String EVENT = "EVENT";
	public static final String ENDEVENT = "ENDEVENT";
	
	private static final HashMap<String, String> showStrings = new HashMap<String, String>();
	{
		// TODO This should be class common data???
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
//	private Activity activity;
	private String activity;
	
	/**
	 * Private Default Constructor do nothing
	 */
	private Event() {
	}

	/**
	 * Constructor
	 * @param date
	 * @param time
	 * @param state
	 */
	private Event(String date, String time, String state) {
		this(date, time, state, "");
	}
	
	public static Event make(String date, String time, String state) {
		return new Event(date, time, state);
	}

	/**
	 * Construct an event
	 * @param date		Start date
	 * @param time		Start time
	 * @param state		Kind of event
	 * @param activity  Activity for event, only when state == EVENT
	 */
	private Event(String date, String time, String state, String activity) {
		this.date = date;
		this.time = time;
		this.state = state;
		if (state.equals(Event.EVENT)) {
			this.activity = activity;
		} else {
			this.activity = null;
		}
	}

	public static Event make(String date, String time, String state, String activity) {
		return new Event(date, time, state, activity);
	}
	

	public String getDate() {
		return date;
	}

	public Event changeDate(String setDate) {
		return new Event(setDate, time, state, activity);
	}

	public String getTime() {
		return time;
	}

	public Event changeTime(String setTime) {
		return new Event(date, setTime, state, activity);
	}

	public String getState() {
		return state;
	}

	public Event changeState(String setState) {
		if (state.equals(Event.EVENT)) {
			return new Event(date, time, setState, activity);
		} else {
			return new Event(date, time, setState);
		}
	}

	public String getActivity() {
		return activity;
	}

	public Event changeEventActivity(String setActivity) {
		return new Event(date, time, Event.EVENT, setActivity);
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
		return Integer.parseInt(date.substring(5, 7));
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
