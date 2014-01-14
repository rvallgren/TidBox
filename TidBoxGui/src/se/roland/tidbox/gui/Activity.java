/**
 * 
 */
package se.roland.tidbox.gui;

import se.roland.tidbox.data.activity.ActivityConfigurationItem;

import org.eclipse.swt.SWT;
import org.eclipse.swt.layout.RowLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Control;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.Text;


/**
 * @author vallgrol
 *
 */
public class Activity {
	
	
	private ActivityConfigurationItem activityConfigurationItem;
	private Composite composite;
	private Composite compositeActivity;
	private RowLayout rl_compositeActivity;
//	private Composite composite_2;
//	private Label lblProject;
//	private Button btnSelect;
//	private Menu menu_1;
//	private MenuItem menuItem;
//	private MenuItem mntmIdleTime;
//	private MenuItem mntmTraining;
//	private MenuItem mntmAbsence;
//	private Composite composite_1;
//	private Label lblTask;
//	private Text enterTask;
//	private Label lblDetails;
//	private Text enterDetails;
//	private Composite composite_3;
//	private Label lblType;
//	private Button btnN;
//	private Button btnFlex;
//	private Button button;
//	private Button btnR;
//	private Button btnS;
//	private Button btnFlexUttag;
	private Composite compositeFields;
	private Label[] labels;
	private Text[] texts;

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
		//		Configurable Activity
		activityConfigurationItem = cfg;
		// TODO: Configurable Activity
		compositeActivity = new Composite(composite, SWT.NONE);
		//		compositeEventCfg.setEnabled(false);
		rl_compositeActivity = new RowLayout(SWT.VERTICAL);
		rl_compositeActivity.fill = true;
		rl_compositeActivity.marginHeight = 2;
		rl_compositeActivity.marginWidth = 2;
		rl_compositeActivity.wrap = false;
		compositeActivity.setLayout(rl_compositeActivity);
		
		// TODO Here we go
		compositeFields = new Composite(compositeActivity, SWT.NONE);
		compositeFields.setLayout(new RowLayout(SWT.HORIZONTAL));
		int fields = cfg.number();
		int iterator = 0;
		labels = new Label[fields];
		texts = new Text[fields];
		while (iterator < fields) {
			Label l = new Label(compositeFields, SWT.NONE);
			l.setText(cfg.getLabel(iterator));
			labels[iterator] = l;
			int	s = cfg.getSize(iterator);
			Text t = new Text(compositeFields, SWT.BORDER);
			t.setSize(s, 10);
			texts[iterator] = t;
			iterator++;
		}
		
//		composite_2 = new Composite(compositeActivity, SWT.NONE);
//		composite_2.setLayout(new RowLayout(SWT.HORIZONTAL));
//		
//		lblProject = new Label(composite_2, SWT.NONE);
//		lblProject.setText("Project:");
//		
//		btnSelect = new Button(composite_2, SWT.NONE);
//		btnSelect.setText("V\u00E4lj");
//		
//		menu_1 = new Menu(btnSelect);
//		btnSelect.setMenu(menu_1);
//		
//		menuItem = new MenuItem(menu_1, SWT.NONE);
//		menuItem.setText("?");
//		
//		mntmIdleTime = new MenuItem(menu_1, SWT.NONE);
//		mntmIdleTime.setText("Obel\u00E4ggning");
//		
//		mntmTraining = new MenuItem(menu_1, SWT.NONE);
//		mntmTraining.setText("Utbildning");
//		
//		mntmAbsence = new MenuItem(menu_1, SWT.NONE);
//		mntmAbsence.setText("Fr\u00E5nvaro");
//		
//		composite_1 = new Composite(compositeActivity, SWT.NONE);
//		composite_1.setLayout(new RowLayout(SWT.HORIZONTAL));
//		
//		lblTask = new Label(composite_1, SWT.NONE);
//		lblTask.setText("Task:");
//		
//		enterTask = new Text(composite_1, SWT.BORDER);
//		//	TODO
//		//		enterTask.addKeyListener(new KeyAdapter() {
//		//			@Override
//		//			public void keyReleased(KeyEvent e) {
//		//				if (e.character == SWT.CR) {
//		//					
//		//				} else {
//		//
//		//				}
//		//			}
//		//		});
//		
//		lblDetails = new Label(composite_1, SWT.NONE);
//		lblDetails.setText("Details:");
//		// TODO:		compositeEventCfg.setTabList(new Control[]{enterTask, enterDetails});
//		
//		enterDetails = new Text(composite_1, SWT.BORDER);
//		
//		composite_3 = new Composite(compositeActivity, SWT.NONE);
//		composite_3.setLayout(new RowLayout(SWT.HORIZONTAL));
//		
//		lblType = new Label(composite_3, SWT.NONE);
//		lblType.setText("Type:");
//		
//		btnN = new Button(composite_3, SWT.RADIO);
//		btnN.setText("N");
//		
//		btnFlex = new Button(composite_3, SWT.RADIO);
//		btnFlex.setText("F+");
//		
//		button = new Button(composite_3, SWT.RADIO);
//		button.setText("\u00D6+");
//		
//		btnR = new Button(composite_3, SWT.RADIO);
//		btnR.setText("R");
//		
//		btnS = new Button(composite_3, SWT.RADIO);
//		btnS.setText("S");
//		
//		btnFlexUttag = new Button(composite_3, SWT.RADIO);
//		btnFlexUttag.setText("F-");
//		
//		composite_3.setTabList(new Control[]{btnN, btnFlex, button, btnR, btnS, btnFlexUttag});
	}

	/**
	 * @param b
	 */
	public void setEnabled(boolean enabled) {
		compositeActivity.setEnabled(enabled);
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
		insert("");
	}
	

}
