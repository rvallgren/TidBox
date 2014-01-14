package se.roland.tidbox.file;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

public class DataFile {
	
// TODO constants
	static final String headerFormat =  "# Format:";
	static final String[] headerComment =  
		{	"# This file is generated, do not edit", 
			"# Creator: Tidbox"};
	private static final String commentPrefix = "# ";
	private static final String tagPrefix = "[";
	private static final String tagSuffix = "]";
	private static final char FORMAT = 'F';
	private enum readState {NOT_REACHED, HEADER_COMMENT, EMPTY_LINE, FILE_TYPE_TAG, NO_HEADER_DETECTED, TAG_OK, DATA_OK, FILE_NOT_FOUND}; 


	public static boolean save(String fileName, String tag, DataFileSave caller) {
		boolean saved = false;
		try (BufferedWriter bw = new BufferedWriter(new FileWriter(fileName))) {
			bw.write(headerFormat);
			bw.write(FORMAT);
			bw.write('\n');
			for (String s : headerComment) {
				bw.write(s);
				bw.write('\n');
			}
			bw.write('\n');
			bw.write('[');
			bw.write(tag);
			bw.write(']');
			bw.write('\n');
			saved = caller.saveData(bw);
		} catch (IOException e) {
			e.printStackTrace();
		}
		return saved;
	}

	public static boolean append(String fileName, String line) {
		boolean saved = false;
		try (BufferedWriter bw = new BufferedWriter(new FileWriter(fileName, true))) {
			bw.write(line);
			bw.write('\n');
			saved = true;
		} catch (IOException e) {
			e.printStackTrace();
		}
		return saved;
	}


	public static boolean load(String fileName, String tag, DataFileLoad caller) {
		String tagString = new String(tagPrefix + tag + tagSuffix);
//		boolean loaded = false;
		readState state = readState.NOT_REACHED;
		try (BufferedReader br = new BufferedReader(new FileReader(fileName))) {
			String s;
			// Read header comments
			while (state != readState.EMPTY_LINE) {
				s = br.readLine();
				if (s == null) {
					state = readState.NO_HEADER_DETECTED;
					break;
				} else if (s.startsWith(commentPrefix)) {
					state = readState.HEADER_COMMENT;
					continue;
				} else if (s.length() == 0) {
					state = readState.EMPTY_LINE;
				}
			}
			if (state == readState.EMPTY_LINE) {
				s = br.readLine();
				if (s == null) {
					state = readState.NO_HEADER_DETECTED;
				} else if (s.equals(tagString)) {
					state = readState.TAG_OK;
				}
			}
			if (state == readState.TAG_OK) {
				if (caller.loadData(br)){
					state = readState.DATA_OK;
				}
			}
		} catch (FileNotFoundException e) {
			state = readState.FILE_NOT_FOUND;
		} catch (IOException e) {
			e.printStackTrace();
		}
		return state == readState.DATA_OK;
	}

}
