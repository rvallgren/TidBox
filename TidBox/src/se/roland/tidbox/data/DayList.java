package se.roland.tidbox.data;

import java.util.ArrayList;

public class DayList {
	
	private Times times;
	private String date;
	private ArrayList<Event> list;

	public DayList(Times t) {
		times = t;
	}

	private void refresh(Event event) {
		if (event.getDate().equals(this.date)) {
			this.getDate(this.date);
		}
	}
	
	public ArrayList<Event> getDate(String date) {
		this.date = date;
		this.list = times.getDate(date);
		return this.list;
	}

	public void add(Event event) {
		this.times.add(event);
		refresh(event);
	}

	public void remove(Event event) {
		this.times.remove(event);
		refresh(event);
	}
	
	public void replace(Event actualEvent, Event newEvent) {
		this.times.replace(actualEvent, newEvent);
	}

	public Event get(int i) {
		return this.list.get(i);
	}
	
	public boolean isUndoEmpty() {
		return this.times.isUndoEmpty();
	}
	
	public boolean isRedoEmpty() {
		return this.times.isRedoEmpty();
	}

	public void undo() {
		this.times.undo();
	}

	public void redo() {
		this.times.redo();
	}

}
