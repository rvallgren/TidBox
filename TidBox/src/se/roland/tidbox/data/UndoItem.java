package se.roland.tidbox.data;

/**
 * Immutable Undo Item
 * 
 * @author Roland Vallgren
 */
public class UndoItem {

//	private enum STATES {ADD, REPLACE, REMOVE};
	
//	private STATES state;
	private Event[] events = new Event[2];

	/*
	 * Default constructor, not used?
	 */
	private UndoItem() {
	}

	/*
	 * Undo Item with one event as argument, ADD action
	 */
	private UndoItem(Event event) {
//		this.state = STATES.ADD;
		events[0] = event;
		events[1] = null;
	}
	
	public static UndoItem make(Event event) {
//		this.state = STATES.ADD;
		return new UndoItem(event);
	}
	

	/*
	 * Undo item with two arguments, replace
	 * eNew: The new event to use instead, if eNew is null, change is a remove
	 * eOld: The event to be replaced
	 */
	private UndoItem(Event eNew, Event eOld) {
//		this.state = STATES.REPLACE;
		events[0] = eNew;
		events[1] = eOld;
	}

	public static UndoItem make(Event eNew, Event eOld) {
//		this.state = STATES.ADD;
		return new UndoItem(eNew, eOld);
	}
	
	public Event[] getEvent() {
		return events.clone();
	}
	
	
}
