package se.roland.tidbox.data;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;

import se.roland.tidbox.file.DataFile;
import se.roland.tidbox.file.DataFileLoad;
import se.roland.tidbox.file.DataFileSave;

public class Times implements DataFileSave, DataFileLoad {
	
	private static final String FILE_TAG = "REGISTERED TIME EVENTS";
	private static final String FILE_NAME = "times.dat";
	private ArrayList<Event> times;
	private UndoEvent undo;
	private boolean dirty;
	// TODO private boolean loaded;
	private String fileName;

	

	/**
	 * Set filename
	 * @param fileName
	 */
	public Times(String fileDir, String fileName) {
		this.fileName = fileDir + File.separator + fileName;
//		TODO: List list = Collections.synchronizedList(new ArrayList(...));
		this.times = new ArrayList<Event>();
		this.undo = new UndoEvent();
		this.dirty = false;
	}
	
	/**
	 * Set filename
	 * @param fileName
	 */
	public Times(String fileDir) {
		this(fileDir, Times.FILE_NAME);
	}


	public Times() {
		this(".");
	}
	

	/*
	 * Get all registrations for the specified date
	 */
	public ArrayList<Event> getDate(String date) {
		ArrayList<Event> t = new ArrayList<Event>();
		for (Event e : times) {
			if (e.getDate().equals(date)) {
				t.add(e);
			}
		}
		Collections.sort(t);
		return t;
	}

	public boolean add(Event event) {
		this.times.add(event);
		this.undo.add(event);
		if (! this.dirty) {
			// TODO Event should have an approptiate method to store a string in a times.dat file
			boolean a = false;
			String i = event.getActivity();
			if (i != null) {
				a = DataFile.append(this.fileName,
						event.getDate() + "," +
						event.getTime() + "," +
						event.getState() + "," +
					    i
					    );
			} else {
				a = DataFile.append(this.fileName,
						event.getDate() + "," +
						event.getTime() + "," +
						event.getState() + ","
						);
			}
			if (! a) {
				this.dirty = true;
			}
		}
		return true;
	}

	public boolean remove(Event eRemove) {
		boolean removed = this.times.remove(eRemove);
		// TODO How do we verify this?
//		assert removed;
		if (removed) {
			this.undo.add(null, eRemove);
			this.dirty = true;
		}
		return removed;
	}

	public boolean replace(Event eActual, Event eReplace) {
		int i = times.indexOf(eActual);
		// TODO How do we verify this?
//		assert i >= 0;
		if (i >= 0) {
			times.set(i, eReplace);
			this.undo.add(eActual, eReplace);
			this.dirty = true;
		}
		return i >= 0;
	}

	public boolean isUndoEmpty() {
		return this.undo.undoIsEmpty();
	}

	public boolean isRedoEmpty() {
		return this.undo.redoIsEmpty();
	}

	public Event[] peekUndo() {
		return this.undo.peekUndo();
	}

//	public Event[] getUndo() {
//		return this.undo.getUndo();
//	}
//	
//	private void doUndoRedo(Event[] action) {
//		if (action[1] == null) {
//			// Undo add
//			this.times.remove(action[0]);
//		} else if (action[0] != null) {
//			// Undo replace
//			int i = times.indexOf(action[1]);
//			times.set(i, action[0]);
//		} else {
//			// Undo remove
//			this.times.add(action[1]);
//		}
//	}

	public void undo() {
		Event[] u = this.undo.getUndo();
		if (u[1] == null) {
			// Undo add
			this.times.remove(u[0]);
		} else if (u[0] != null) {
			// Undo replace
			int i = times.indexOf(u[1]);
			times.set(i, u[0]);
		} else {
			// Undo remove
			this.times.add(u[1]);
		}
		this.dirty = true;
	}

	public void redo() {
		Event[] r = this.undo.getRedo();
		if (r[1] == null) {
			// Redo add
			this.times.add(r[0]);
		} else if (r[0] != null) {
			// Redo replace
			int i = times.indexOf(r[0]);
			times.set(i, r[1]);
		} else {
			// Redo remove
			this.times.remove(r[1]);
		}
		this.dirty = true;
	}

	public boolean save() {
		if (dirty) {
			this.dirty = false;
			return DataFile.save(this.fileName, Times.FILE_TAG, this);
		} else {
			return false;
		}
	}

	public boolean load() {
		this.dirty = false;
		return DataFile.load(this.fileName, Times.FILE_TAG, this);
	}


	@Override
	public boolean saveData(BufferedWriter bw) throws IOException {
//		Collections.sort(times);
		this.sort();
		String i;
		for (Event e : times) {
			// TODO Event should implement this in "toString()"
			bw.write(e.getDate());
			bw.write(',');
			bw.write(e.getTime());
			bw.write(',');
			bw.write(e.getState());
			bw.write(',');
			i = e.getActivity();
			if (i != null) {
				bw.write(i);
			}
			bw.write('\n');
		}
		return true;
	}

	@Override
	public boolean loadData(BufferedReader br) throws IOException {
		String s;
		try {
			while ((s = br.readLine()) != null) {
				// TODO Event should implement this
				// 2013-12-04,13:05,<type>[,[info]]
				String d = s.substring(0, 10);
				String t = s.substring(11, 16);
				int i = s.indexOf(',', 20);
				if (i < 0)
					i = s.length();
				String n = s.substring(17, i);
				i++; // Skip comma
				if (i < s.length()) {
					times.add(new Event(d, t, n, s.substring(i)));
				} else {
					times.add(new Event(d, t, n));
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
			return false;
		}
		return true;
	}

	public int size() {
		return times.size();
	}

	/**
	 * Get an iterator over times data
	 * @return Event
	 */
	public Iterator<Event> iterator() {
		return times.iterator();
	}

	public void sort() {
		Collections.sort(times);		
	}

//	public Event getItem(int i) {
//		return times.get(i);
//	}
	
}
