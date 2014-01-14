/**
 * 
 */
package se.roland.tidbox.file;

import java.io.BufferedReader;
import java.io.IOException;

/**
 * Load tidbox file
 * @author vallgrol
 *
 */
public interface DataFileLoad {

	public boolean loadData(BufferedReader br) throws IOException;
	
}
