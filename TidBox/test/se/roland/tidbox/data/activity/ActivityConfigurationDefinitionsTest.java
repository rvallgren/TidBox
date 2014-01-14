/**
 * 
 */
package se.roland.tidbox.data.activity;

import static org.junit.Assert.*;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.Test;

/**
 * @author vallgrol
 *
 *     UPPERCASE          A  => [ '[A-ZÅÄÖ]'        , 'Versaler (A-Ö)'           , 1 ],
 *     ALPHABETIC         a  => [ '[a-zåäöA-ZÅÄÖ]'  , 'Alfabetiska (a-öA-Ö)'     , 2 ],
 *     ALPHANUMERIC       w  => [ '\\w'             , 'Alfanumerisk (a-ö0-9_)'   , 3 ],
 *     TEXT               W  => [ '[^,\n\r]'        , 'Text (ej ,)'              , 4 ],
 *     DIGITS             d  => [ '\\d'             , 'Siffror (0-9)'            , 5 ],
 *     NUMBER             D  => [ '[\\d\\.\\+\\-]'  , 'Numeriska (0-9.+-)'       , 6 ],
 *     RADIO              r  => [ '[^,\n\r]'        , 'Radioknapp'               , 7 ],
 *     RADIO_ALIAS        R  => [ '[^,\n\r]'        , 'Radioknapp översätt'      , 8 ],
 *     FREE_TEXT         '.' => [ '[^\n\r]'         , 'Fritext'                  , 9 ],
 */
public class ActivityConfigurationDefinitionsTest {
	
	@Test
	public void test() {
		
		Pattern p_A_uppercase = ActivityConfigurationDefinitions.getPattern('A');
		assertNotNull("A pattern should be returned", p_A_uppercase);
		Matcher m1_A_uppercase = p_A_uppercase.matcher("UPPERCASEONLY");
		assertTrue("UPPERCASE should match", m1_A_uppercase.matches());
		Matcher m2_A_uppercase = p_A_uppercase.matcher("Should not match");
		assertFalse("This should not match", m2_A_uppercase.matches());
		
		Pattern p_a_alphabetic = ActivityConfigurationDefinitions.getPattern('a');
		assertNotNull("A pattern should be returned", p_a_alphabetic);
		Matcher m1_a_alphabetic = p_a_alphabetic.matcher("OnlyAlphaBetIC");
		assertTrue("OnlyAlphaBetIC should match", m1_a_alphabetic.matches());
		Matcher m2_a_alphabetic = p_a_alphabetic.matcher("Should not match");
		assertFalse("This should not match", m2_a_alphabetic.matches());

		Pattern p_w_alphaNumeric = ActivityConfigurationDefinitions.getPattern('w');
		assertNotNull("A pattern should be returned", p_w_alphaNumeric);
		Matcher m1_w_alphaNumeric = p_w_alphaNumeric.matcher("Alpha123Numeric09");
		assertTrue("Alpha123Numeric09 should match", m1_w_alphaNumeric.matches());
		Matcher m2_w_alphaNumeric = p_w_alphaNumeric.matcher("Should not match,9");
		assertFalse("This should not match", m2_w_alphaNumeric.matches());
		
		Pattern p_W_text = ActivityConfigurationDefinitions.getPattern('W');
		assertNotNull("A pattern should be returned", p_W_text);
		Matcher m1_W_text = p_W_text.matcher("Some text.");
		assertTrue("Some text should match", m1_W_text.matches());
		Matcher m2_W_text = p_W_text.matcher("Comma , should not match");
		assertFalse("Comma should not match", m2_W_text.matches());
		
		Pattern p_d_digits = ActivityConfigurationDefinitions.getPattern('d');
		assertNotNull("A pattern should be returned", p_d_digits);
		Matcher m1_d_digits = p_d_digits.matcher("0987654321");
		assertTrue("Digits should match", m1_d_digits.matches());
		Matcher m2_d_digits = p_d_digits.matcher("a,non digit does not match");
		assertFalse("Non digits should not match", m2_d_digits.matches());
		
		Pattern p_D_number = ActivityConfigurationDefinitions.getPattern('D');
		assertNotNull("A pattern should be returned", p_D_number);
		Matcher m1_D_number = p_D_number.matcher("12.34+56-7890");
		assertTrue("Digits, dot, plus and minus should match", m1_D_number.matches());
		Matcher m2_D_number = p_D_number.matcher("Comma , should not match");
		assertFalse("Not a number should not match", m2_D_number.matches());
		
		Pattern p_r_RadioButton = ActivityConfigurationDefinitions.getPattern('r');
		assertNotNull("A pattern should be returned", p_r_RadioButton);
		Matcher m1_r_RadioButton = p_r_RadioButton.matcher("a;7;+-; 6g");
		assertTrue("A radiobutton definition should match", m1_r_RadioButton.matches());
		Matcher m2_r_RadioButton = p_r_RadioButton.matcher("Comma , should not match");
		assertFalse("This should not match", m2_r_RadioButton.matches());
		
		Pattern p_R_AliasRadioButton = ActivityConfigurationDefinitions.getPattern('R');
		assertNotNull("A pattern should be returned", p_R_AliasRadioButton);
		Matcher m1_R_AliasRadioButton = p_R_AliasRadioButton.matcher("Ö=>Overtime;n=>Normal");
		assertTrue("Radio button alias should match", m1_R_AliasRadioButton.matches());
		Matcher m2_R_AliasRadioButton = p_R_AliasRadioButton.matcher("Comma , should not match");
		assertFalse("This should not match", m2_R_AliasRadioButton.matches());
		
		Pattern p_dot_AnyText = ActivityConfigurationDefinitions.getPattern('.');
		assertNotNull("A pattern should be returned", p_dot_AnyText);
		Matcher m1_dot_AnyText = p_dot_AnyText.matcher("Some text , with comma.");
		assertTrue("Some text with , should match", m1_dot_AnyText.matches());
		Matcher m2_dot_AnyText = p_dot_AnyText.matcher("CR and LF (\r and \n) should not match");
		assertFalse("This should not match", m2_dot_AnyText.matches());
				
	}

}
