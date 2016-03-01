/**
 * 
 */
package se.roland.tidbox.gui;

import se.roland.tidbox.data.activity.ActivityConfigurationItem;

import org.eclipse.swt.SWT;
import org.eclipse.swt.layout.RowData;
import org.eclipse.swt.layout.RowLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Text;


/**
 * @author vallgrol
 *
 */
public class Activity {
	
	
	private ActivityConfigurationItem activityConfigurationItem;
	private Composite composite;
	private Composite compositeFields;
	private Label[] labels;
	private Composite[] labelComposites;
	private Text[] texts;
	private Composite[] fieldComposites;
	private Composite[] informationComposites;

	/**
	 * 
	 */
	public Activity(Composite comp) {
		composite = comp;
	}

	/**
	 * 
	 */
	public void createActivityComposite(ActivityConfigurationItem cfg) {
		int fields = cfg.getSize();
		int index = 0;
		fieldComposites = new Composite[fields];
		labelComposites = new Composite[fields];
		informationComposites = new Composite[fields];
		labels = new Label[fields];
		texts = new Text[fields];

		//		Configurable Activity
		activityConfigurationItem = cfg;
		// TODO: Configurable Activity
//		The user should be allowed to chose rows, grid, etc. or menu

		compositeFields = new Composite(composite, SWT.BORDER);
		compositeFields.setLayout(new RowLayout(SWT.VERTICAL));

		RowLayout horizontalRowLayout = new RowLayout(SWT.HORIZONTAL);
		horizontalRowLayout.wrap = false;
		horizontalRowLayout.pack = true;
		horizontalRowLayout.justify = true;
		horizontalRowLayout.fill = true;
		
		RowLayout verticalRowLayout = new RowLayout(SWT.VERTICAL);
		verticalRowLayout.wrap = false;
		verticalRowLayout.pack = true;
		verticalRowLayout.justify = true;
		verticalRowLayout.fill = false;

		Composite fieldC = new Composite(compositeFields, SWT.BORDER);
		fieldC.setLayout(horizontalRowLayout);
		fieldComposites[index] = fieldC;
		
		int length = 0;
		
		while (index < fields) {
			
			if (length > 27) {
				length = 0;
				// New composite for more fields
				fieldC = new Composite(compositeFields, SWT.BORDER);
				fieldC.setLayout(horizontalRowLayout);
				fieldComposites[index] = fieldC;
			} else {
				fieldComposites[index] = null;
			}
			
			// Label in own composite
			Composite labelC = new Composite(fieldC, SWT.NONE);
			labelC.setLayout(verticalRowLayout);
			labelComposites[index] = labelC;
			// Label
			Label l = new Label(labelC, SWT.NONE);
			l.setText(cfg.getLabel(index) + ":");
//			length += l.getSize().x;
			length += cfg.getLabel(index).length();
			labels[index] = l;
			
			// Information in own composite
			Composite inf = new Composite(fieldC, SWT.NONE);
			inf.setLayout(horizontalRowLayout);
			informationComposites[index] = inf;
			
			// Information
			int	s = cfg.getSize(index);
			Text t = new Text(inf, SWT.BORDER);
//			t.setSize(s, 10);
			t.setLayoutData(new RowData(s*4, SWT.DEFAULT));
//			length += t.getSize().x;
			length += s;
			texts[index] = t;
			index++;
			System.out.println("Length: " + length);
		}
		
	}

	/**
	 * @param b
	 */
	public void setEnabled(boolean enabled) {
		compositeFields.setEnabled(enabled);
	}

	/**
	 * @param inf
	 */
	public void insert(String inf) {
		String[] s = activityConfigurationItem.parse(inf);
		for (int i = 0; i < texts.length; i++) {
			texts[i].setText(s[i]);
		}
	}

	/**
	 * @return inf
	 */
	public String get() {
		String[] tmp = new String[texts.length];
		for (int i = 0; i < texts.length; i++) {
			tmp[i] = texts[i].getText();
		}
		return activityConfigurationItem.join(tmp);
	}

	/**
	 * 
	 */
	public void clear() {
//		insert("");
		for (int i = 0; i < texts.length; i++) {
			texts[i].setText("");
		}
	}
	

}
