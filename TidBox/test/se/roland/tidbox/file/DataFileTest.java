package se.roland.tidbox.file;

import static org.junit.Assert.*;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;

import org.junit.Test;

public class DataFileTest implements DataFileSave, DataFileLoad {
	
	private static final String of = "dataFile.dat";
	private static final String af = "dataFileAppend.dat";
	private static final String[] testContents = {
		"2013-11-27,11:16,first line", 
		"r:t:b", 
	 	"just another string"
	};
	private static final String testAppend = "String to append to file";
	private static final String tag = "TIDBOX TEST FILE";
//	private String[] results;
	private ArrayList<String> readData;


	/*
	 * # Format:F
	 * # This file is generated, do not edit
	 * # Creator: Tidbox
	 * 
	 * [REGISTERED TIME EVENTS]
	 * 2012-01-07,17:30,BEGINWORK,
	 */

	@Test
	public void saveTestFile() {
		File testFile = new File(of);
		testFile.delete();
		assertFalse("File should not exist", testFile.exists());
		testFile = null;  // Get rid of testFile
		
		boolean r = DataFile.save(of, tag, this);
		assertTrue("File should be saved OK", r);
		
		r = DataFile.save(of, tag, this);
		assertTrue("File should be replaced OK", r);		
	}

	@Override
	public boolean saveData(BufferedWriter bw) throws IOException {
		for (String s : testContents) {
			bw.write(s);
			bw.write("\n");
		}
		return true;
	}
	
	

	@Test
	public void loadTestFile() throws Exception {
		boolean r = DataFile.load("NoSuchFile.dat", tag, this);
		assertFalse("File should fail to load", r);
		
		r = DataFile.load(of, tag, this);
		assertTrue("File should load OK", r);
		assertEquals("Result should have same length as input", testContents.length, readData.size());
		for (int i = 0; i < testContents.length; i++) {
			assertTrue(testContents[i].equals(readData.get(i)));
		}
	}

	@Override
	public boolean loadData(BufferedReader br) throws IOException {
		String s;
		readData = new ArrayList<String>();
		try {
			while ((s = br.readLine()) != null) {
				readData.add(s);
			}
//			results = new String[testContents.length];
//			readData = new ArrayList<String>();
//			int i = 0;
//			try {
//				while ((s = br.readLine()) != null) {
//					if (i < testContents.length) {
//						results[i] = s;
//						i++;
//					} else {
//						readData.add(s);
//					}
//				}
		} catch (Exception e) {
			return false;
		}
		return true;
	}

	@Test
	public void appendToFile() throws Exception {
		File testFile = new File(af);
		testFile.delete();
		boolean n = DataFile.append(af, testAppend);
		assertFalse("Append should fail if file does not exist", n);

		boolean r = DataFile.save(af, tag, this);
		assertTrue("File should be saved OK", r);
		
		boolean a = DataFile.append(af, testAppend);
		assertTrue("File should be appended OK", a);

		boolean l = DataFile.load(af, tag, this);
		assertTrue("File should load OK", l);
		for (int i = 0; i < testContents.length; i++) {
			assertTrue(testContents[i].equals(readData.get(i)));
		}
		assertTrue("Data should have been appended", testAppend.equals(readData.get(testContents.length)));

	}

}
