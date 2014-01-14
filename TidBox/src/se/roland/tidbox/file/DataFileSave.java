/**
 * 
 */
package se.roland.tidbox.file;

import java.io.BufferedWriter;
import java.io.IOException;

/**
 * Interface to save .dat files for Tidbox
 * @author vallgrol
 *
 */
public interface DataFileSave {
	
	public boolean saveData(BufferedWriter bw) throws IOException;

}
