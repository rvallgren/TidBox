package se.roland.tidbox.data;

import java.util.Stack;

public class UndoEvent {
	
	private Stack<UndoItem> undo;
	private Stack<UndoItem> redo;

	public UndoEvent() {
		undo = new Stack<UndoItem>();
		redo = new Stack<UndoItem>();
	}

	public boolean undoIsEmpty() {
		return undo.isEmpty();
	}

	public boolean redoIsEmpty() {
		return redo.isEmpty();
	}
	
	public void add(Event e) {
		undo.push(UndoItem.make(e));
		redo.clear();
	}

	public void add(Event eOld, Event eNew) {
		undo.push(UndoItem.make(eOld, eNew));
		redo.clear();
	}

	public Event[] getUndo() {
		UndoItem i = undo.pop();
		redo.push(i);
		return i.getEvent();
	}

	public Event[] getRedo() {
		UndoItem i = redo.pop();
		undo.push(i);
		return i.getEvent();
	}

	public Event[] peekUndo() {
		UndoItem i = undo.peek();
		return i.getEvent();
	}
	
}
