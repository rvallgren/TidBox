package se.roland.tidbox.data;

public class UndoItem {

//	private enum STATES {ADD, REPLACE, REMOVE};
	
//	private STATES state;
	private Event[] events = new Event[2];

	/*
	 * Default constructor, not used?
	 */
//	private UndoItem() {
//		// TODO Auto-generated constructor stub
//	}

	/*
	 * Undo Item with one event as argument, ADD action
	 */
	public UndoItem(Event event) {
		// TODO Auto-generated constructor stub
//		this.state = STATES.ADD;
		events[0] = event;
		events[1] = null;
	}

	/*
	 * Undo item with two arguments, replace
	 * eNew: The new event to use instead, if eNew is null, change is a remove
	 * eOld: The event to be replaced
	 */
	public UndoItem(Event eNew, Event eOld) {
//		this.state = STATES.REPLACE;
		events[0] = eNew;
		events[1] = eOld;
	}

	public Event[] getEvent() {
		return events;
	}
	
	
}
