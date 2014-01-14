package se.roland.tidbox.gui;

//import java.awt.event.ActionEvent;
//import java.awt.event.ActionListener;
import java.util.ArrayList;
import java.util.HashMap;

//import javax.swing.ButtonGroup;
//import javax.swing.Timer;






import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.List;
import org.eclipse.swt.widgets.ToolBar;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.DateTime;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Text;
import org.eclipse.swt.widgets.ToolItem;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.Control;
import org.eclipse.swt.custom.CBanner;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.layout.RowLayout;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.custom.ScrolledComposite;
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;

import se.roland.tidbox.Clock;
import se.roland.tidbox.ClockEventMethod;
import se.roland.tidbox.data.DayList;
import se.roland.tidbox.data.Event;
import se.roland.tidbox.data.Times;
import se.roland.tidbox.data.activity.ActivityConfigurationItem;

import org.eclipse.swt.layout.RowData;
import org.eclipse.swt.layout.GridData;
//import org.eclipse.swt.events.KeyAdapter;
//import org.eclipse.swt.events.KeyEvent;
import org.eclipse.swt.events.ShellAdapter;
import org.eclipse.swt.events.ShellEvent;

//public class Main implements ClockEventMethod, ActionListener {
public class Main implements ClockEventMethod {

	private static final String BUTTON_DATETTIME_NOW = "Nu";
	private static final String STATE_ENDEVENT = "Sluta h\u00E4ndelse";
	private static final String STATE_BEGINEVENT = "B\u00F6rja h\u00E4ndelse";
	private static final String STATE_ENDPAUS = "Sluta paus";
	private static final String STATE_BEGINPAUSE = "B\u00F6rja paus";
	private static final String STATE_ENDWORKDAY = "Sluta arbetsdagen";
	private static final String STATE_BEGINWORKDAY = "B\u00F6rja arbetsdagen";
	private static final String BUTTON_REMOVE = "Ta bort";
	private static final String REMOVE_REGISTERED_ITEM = "Tag bort en registrering";
	private static final String BUTTON_CHANGE = "\u00C4ndra";
	private static final String TOOL_TIP_CHANGE_REGISTERED_ITEM = "\u00C4ndra tid eller egenskaper f\u00F6r en registrering";
	private static final String CLEAR_REGISTERED_SHOW = "Rensa inmatningsfält";
	private static final String BUTTON_CLEAR = "Rensa";
	private static final String LABEL_ADD = "L\u00E4gg till";
	private static final String LABEL_ADD_EVENT = "L\u00E4gg till h\u00E4ndelse";
//	private static final String LABEL_EVENT = "H\u00E4ndelse:";
	private static final String LABEL_ACTION = "\u00C5tg\u00E4rd:";
	private static final String LABEL_DATE_TIME = "Datum Tid:";
	private static final String TOOL_YESTERDAY = "Ig\u00E5r";
	private static final String TOOL_TODAY = "Idag";
	private static final String MENU_PREFERENCES = "Inst\u00E4llningar";
	private static final String MENU_EDIT = "Redigera";
	private static final String MENU_WEEK = "Veckan";
	private static final String MENU_SHOW = "Visa";
	private static final String MENU_EXIT = "Avsluta";
	private static final String MENU_EXPORT = "Exportera";
	private static final String MENU_SAVE = "Spara";
	private static final String MENU_FILE = "File";
	private static final String TIDBOX_TITLE = "Tidbox";
	private static final String TIDBOX_VERSION = "5.0";

	private enum ButtonPressed { BUTTON_PRESSED_ADD, BUTTON_PRESSED_CHANGE,
						BUTTON_PRESSED_REMOVE, BUTTON_PRESSED_CLEAR,
						BUTTON_PRESSED_UNDO, BUTTON_PRESSED_REDO };

	private String title = TIDBOX_TITLE;

	protected Shell shlTidbox;
	protected GridData gd_composite;
	protected Display display;
//	protected Text enterTask;
//	protected Text enterDetails;
	protected Menu menuBar;
//	protected Timer clockTimer;
	protected MenuItem mntmFile;
	protected Menu menuFile;
	protected MenuItem mntmSpara;
	protected MenuItem mntmExportera;
	protected MenuItem mntmAvsluta;
	protected MenuItem mntmVisa;
	protected Menu menuShow;
	protected MenuItem mntmVeckan;
	protected MenuItem mntmEdit;
	protected Menu menuEdit;
	protected MenuItem mntmPreferences;
	protected Composite composite;
	protected RowLayout rl_composite;
	protected ToolBar toolBar;
	protected ToolItem tltmToday;
	protected ToolItem tltmYesterday;
	protected CBanner banner;
	protected Composite compositeLeft;
	protected RowLayout left_rl_composite;
	protected ScrolledComposite scrolledComposite;
	protected Composite compositeRight;
	protected RowLayout right_rl_composite;
	protected Composite compositeDateTime;
	protected RowLayout rl_compositeDateTime;
	protected Label lblDateTime;
	protected DateTime date;
	protected DateTime time;
	protected Composite compositeAction;
	protected RowLayout rl_compositeAction;
	protected Label lblAction;
	protected Button btnAddEvent;
	protected Button btnChangeEvent;
	protected Button btnRemoveEvent;
	protected Button btnClear;
	private Activity activity;
//	protected Composite compositeEventCfg;
//	protected RowLayout rl_compositeEventCfg;
//	protected Composite composite_1;
//	protected Label lblTask;
//	protected Label lblDetails;
//	protected Composite composite_2;
//	protected Label lblProject;
//	protected Button btnSelect;
//	protected Menu menu_1;
//	protected MenuItem menuItem;
//	protected MenuItem mntmIdleTime;
//	protected MenuItem mntmTraining;
//	protected MenuItem mntmAbsence;
//	protected Composite composite_3;
//	protected Label lblType;
//	protected Button btnN;
//	protected Button btnFlex;
//	protected Button button;
//	protected Button btnR;
//	protected Button btnS;
//	protected Button btnFlexUttag;
	protected Composite composite_Bottom;
	protected Button btnWeek;
	protected Button btnSettings;
	protected Button btnExit;
	protected Button btnNow;
	private Composite compositeState;

	private static final HashMap<String, Button> btnState = new HashMap<String, Button>();

	protected Clock clock;
	protected Times times;
	
	protected String radioState;
	private List wDayList;
	private DayList dayList;
	private Event dayListSelectedEvent;
	private int nowCounter;
	private int lastHour;
	private int lastMinute;
	private Button btnUndo;
	private Button btnRedo;
//	private ButtonGroup stateRadioGroup; 
	private ActivityConfigurationItem activityCfg;
	

	/**
	 * Launch the application.
	 * @param args
	 */
//	TODO: Move to a main class, not GUI main
	public static void main(String[] args) {
		try {
			Main window = new Main();
			window.open();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	/**
	 * Open the window.
	 */
	public void open() {
		display = Display.getDefault();
		createContents();
		shlTidbox.open();
		shlTidbox.layout();
		startClock();
		initialize();
//		TODO: Load from file
		times = new Times();
		times.load();
		dayList = new DayList(times);
		setDateTimeNow(0);
		updateDayList();
		while (!shlTidbox.isDisposed()) {
			if (!display.readAndDispatch()) {
				display.sleep();
			}
		}
	}

	/**
	 * Create contents of the window.
	 * TODO Understanding Layouts in SWT
	 */
	protected void createContents() {
		shlTidbox = new Shell();
		shlTidbox.addShellListener(new ShellAdapter() {
			@Override
			public void shellClosed(ShellEvent e) {
				exit();
			}
		});
		shlTidbox.setSize(530, 455);
		shlTidbox.setText(TIDBOX_TITLE + " " + TIDBOX_VERSION);
//		shlTidbox.setLayout(new StackLayout());
		shlTidbox.setLayout(new GridLayout());
		
		createMenuBar();

		composite = new Composite(shlTidbox, SWT.NONE);
		gd_composite = new GridData(SWT.CENTER, SWT.CENTER, true, true, 1, 1);
		gd_composite.heightHint = 329;
		composite.setLayoutData(gd_composite);
		rl_composite = new RowLayout(SWT.VERTICAL);
		rl_composite.wrap = false;
		composite.setLayout(rl_composite);

		toolBar = new ToolBar(composite, SWT.BORDER | SWT.FLAT | SWT.WRAP | SWT.RIGHT);
		
		tltmToday = new ToolItem(toolBar, SWT.RADIO);
		tltmToday.setEnabled(false);
		tltmToday.setText(TOOL_TODAY);

		tltmYesterday = new ToolItem(toolBar, SWT.RADIO);
		tltmYesterday.setEnabled(false);
		tltmYesterday.setText(TOOL_YESTERDAY);

		banner = new CBanner(composite, SWT.NONE);
		banner.setLayoutData(new RowData(SWT.DEFAULT, 293));
		banner.setRightMinimumSize(new Point(100, 250));

//		Left
		compositeLeft = new Composite(banner, SWT.NONE);
//		compositeLeft.setToolTipText("H\u00E4ndelser f\u00F6r dagen");
		banner.setLeft(compositeLeft);
		left_rl_composite = new RowLayout(SWT.VERTICAL);
		left_rl_composite.fill = true;
		left_rl_composite.wrap = false;
		compositeLeft.setLayout(left_rl_composite);

		createDayListComposite();

//		Right
		compositeRight = new Composite(banner, SWT.NONE);
		banner.setRight(compositeRight);
		right_rl_composite = new RowLayout(SWT.VERTICAL);
		right_rl_composite.fill = true;
		right_rl_composite.center = true;
		right_rl_composite.wrap = false;
		compositeRight.setLayout(right_rl_composite);
		
		createDateTimeComposite();
		
		createStateComposite();

		createActionsComposite();
		
		activity = new Activity(compositeRight);
		// TODO should be read from file
		activityCfg = new ActivityConfigurationItem("2013-12-18", 4);
//		Project:d:6
		activityCfg.add("Project", 'd', 6);
//		Task:D:8
		activityCfg.add("Task", 'D', 8);
//		Type:W:17
		activityCfg.add("Type", 'W', 17);
//		Details:.:40
		activityCfg.add("Details", '.', 40);
		
		activity.createActivityComposite(activityCfg);

//		TODO: Should be removed? Toolbar at bottom with buttons???
		composite_Bottom = new Composite(banner, SWT.NONE);
		banner.setBottom(composite_Bottom);
		composite_Bottom.setLayout(new RowLayout(SWT.HORIZONTAL));

		btnWeek = new Button(composite_Bottom, SWT.NONE);
		btnWeek.setEnabled(false);
		btnWeek.setText(MENU_WEEK);

		btnSettings = new Button(composite_Bottom, SWT.NONE);
		btnSettings.setEnabled(false);
		btnSettings.setText(MENU_PREFERENCES);

		btnExit = new Button(composite_Bottom, SWT.NONE);
		btnExit.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				exit();
			}
		});
		btnExit.setText(MENU_EXIT);

	}

	/**
	 * 
	 */
	private void createMenuBar() {
		menuBar = new Menu(shlTidbox, SWT.BAR);
		shlTidbox.setMenuBar(menuBar);
		
		mntmFile = new MenuItem(menuBar, SWT.CASCADE);
		mntmFile.setText(MENU_FILE);
		
		menuFile = new Menu(mntmFile);
		mntmFile.setMenu(menuFile);
		
		mntmSpara = new MenuItem(menuFile, SWT.NONE);
		mntmSpara.setText(MENU_SAVE);
		
		mntmExportera = new MenuItem(menuFile, SWT.NONE);
		mntmExportera.setText(MENU_EXPORT);
		
		mntmAvsluta = new MenuItem(menuFile, SWT.NONE);
		mntmAvsluta.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				exit();
			}
		});
		mntmAvsluta.setText(MENU_EXIT);
		
		mntmVisa = new MenuItem(menuBar, SWT.CASCADE);
		mntmVisa.setText(MENU_SHOW);

		menuShow = new Menu(mntmVisa);
		mntmVisa.setMenu(menuShow);
		
		mntmVeckan = new MenuItem(menuShow, SWT.NONE);
		mntmVeckan.setText(MENU_WEEK);
		
		mntmEdit = new MenuItem(menuBar, SWT.CASCADE);
		mntmEdit.setText(MENU_EDIT);

		menuEdit = new Menu(mntmEdit);
		mntmEdit.setMenu(menuEdit);

		mntmPreferences = new MenuItem(menuEdit, SWT.NONE);
		mntmPreferences.setText(MENU_PREFERENCES);
	}

	/**
	 * 
	 */
	private void createDayListComposite() {
		//		Day list
		// TODO: Width and height
		scrolledComposite = new ScrolledComposite(compositeLeft, SWT.BORDER | SWT.H_SCROLL | SWT.V_SCROLL);
		scrolledComposite.setExpandHorizontal(true);
		scrolledComposite.setExpandVertical(true);
		
		wDayList = new List(scrolledComposite, SWT.BORDER | SWT.V_SCROLL);
		wDayList.addSelectionListener(new SelectionAdapter() {
			
			@Override
			public void widgetSelected(SelectionEvent e) {
				dayListSelectedEvent = dayList.get(wDayList.getSelectionIndex());
				date.setDate(dayListSelectedEvent.getYearI(), dayListSelectedEvent.getMonthI(), dayListSelectedEvent.getDayI());
				time.setHours(dayListSelectedEvent.getHourI());
				time.setMinutes(dayListSelectedEvent.getMinuteI());
				//				btnState.get(radioState).setSelection(true);
				//				radioState = event.getState();
				stateSelected(dayListSelectedEvent.getState());
				// Event cfg
				if (radioState.equals(Event.EVENT)) {
					String inf = dayListSelectedEvent.getActivity();
					if (inf != null) {
						activity.insert(inf);
					}
				} else {
					activity.clear();
				}
				btnChangeEvent.setEnabled(true);
				btnRemoveEvent.setEnabled(true);
				btnClear.setEnabled(true);
				nowCounter = 120;
			}
		});
		scrolledComposite.setContent(wDayList);
	}

	/**
	 * 
	 */
	private void createDateTimeComposite() {
		//		Date Time
		compositeDateTime = new Composite(compositeRight, SWT.NONE);
		compositeDateTime.setLayoutData(new RowData(SWT.DEFAULT, 30));
		rl_compositeDateTime = new RowLayout(SWT.HORIZONTAL);
		rl_compositeDateTime.fill = true;
		rl_compositeDateTime.wrap = false;
		compositeDateTime.setLayout(rl_compositeDateTime);
		
		lblDateTime = new Label(compositeDateTime, SWT.NONE);
		lblDateTime.setText(LABEL_DATE_TIME);
		
		// TODO: Do we need to create an own DateTime widget?
		//       This one does not allow copy, empty, other than date, etc...
		date = new DateTime(compositeDateTime, SWT.BORDER | SWT.DROP_DOWN);
		
		time = new DateTime(compositeDateTime, SWT.BORDER | SWT.TIME | SWT.SHORT);
		time.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				nowCounter  = 120;
			}
		});
		
		btnNow = new Button(compositeDateTime, SWT.NONE);
		btnNow.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				setDateTimeNow(60);
//				clock.start();
				
			}
		});
		btnNow.setText(BUTTON_DATETTIME_NOW);
	}
	
	/**
	 * 
	 */
	private void createStateComposite() {
		// State
		compositeState = new Composite(compositeRight, SWT.NONE);
		compositeState.setLayoutData(new RowData(SWT.DEFAULT, 67));
		compositeState.setLayout(new GridLayout(2, false));

		Button tmp;
//		stateRadioGroup = new ButtonGroup();

		// TODO: Foreach loop??
		tmp = new Button(compositeState, SWT.RADIO);
//		tmp.setData(Event.BEGINWORK);
		tmp.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.BEGINWORK);
			}
		});
		tmp.setText(STATE_BEGINWORKDAY);
//		stateRadioGroup.add(tmp);
		btnState.put(Event.BEGINWORK, tmp);
		
		tmp = new Button(compositeState, SWT.RADIO);
//		tmp.setData(Event.WORKEND);
		tmp.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.WORKEND);
			}
		});
		tmp.setText(STATE_ENDWORKDAY);
		btnState.put(Event.WORKEND, tmp);
		
		tmp = new Button(compositeState, SWT.RADIO);
//		tmp.setData(Event.PAUSE);
		tmp.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.PAUSE);
			}
		});
		tmp.setText(STATE_BEGINPAUSE);
		btnState.put(Event.PAUSE, tmp);

		tmp = new Button(compositeState, SWT.RADIO);
//		btnEndPause.setData(Event.ENDPAUSE);
		tmp.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.ENDPAUSE);
			}
		});
		tmp.setText(STATE_ENDPAUS);
		btnState.put(Event.ENDPAUSE, tmp);

		
		tmp = new Button(compositeState, SWT.RADIO);
//		btnBeginEvent.setData(Event.EVENT);
		tmp.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.EVENT);
			}
		});
		tmp.setText(STATE_BEGINEVENT);
		btnState.put(Event.EVENT, tmp);

		
		tmp = new Button(compositeState, SWT.RADIO);
//		btnEndEvent.setData(Event.ENDEVENT);
		tmp.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.ENDEVENT);
			}
		});
		tmp.setText(STATE_ENDEVENT);
		btnState.put(Event.ENDEVENT, tmp);
	}

	/**
	 * 
	 */
	private void createActionsComposite() {
		//		Registrations handling
		compositeAction = new Composite(compositeRight, SWT.NONE);
		compositeAction.setLayoutData(new RowData(352, SWT.DEFAULT));
		rl_compositeAction = new RowLayout(SWT.HORIZONTAL);
		rl_compositeAction.wrap = false;
		compositeAction.setLayout(rl_compositeAction);
		
		lblAction = new Label(compositeAction, SWT.CENTER);
		lblAction.setAlignment(SWT.CENTER);
		lblAction.setText(LABEL_ACTION);
		
		btnAddEvent = new Button(compositeAction, SWT.NONE);
		btnAddEvent.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_ADD);
			}
			@Override
			public void widgetDefaultSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_ADD);
			}
		});
		btnAddEvent.setToolTipText(LABEL_ADD_EVENT);
		btnAddEvent.setText(LABEL_ADD);
		
		btnChangeEvent = new Button(compositeAction, SWT.NONE);
		btnChangeEvent.setEnabled(false);
		btnChangeEvent.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_CHANGE);
			}
			@Override
			public void widgetDefaultSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_CHANGE);
			}
		});
		btnChangeEvent.setToolTipText(TOOL_TIP_CHANGE_REGISTERED_ITEM);
		btnChangeEvent.setText(BUTTON_CHANGE);
		
		btnRemoveEvent = new Button(compositeAction, SWT.NONE);
		btnRemoveEvent.setEnabled(false);
		btnRemoveEvent.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_REMOVE);
			}
			@Override
			public void widgetDefaultSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_REMOVE);
			}
		});
		btnRemoveEvent.setToolTipText(REMOVE_REGISTERED_ITEM);
		btnRemoveEvent.setText(BUTTON_REMOVE);
		
		btnClear = new Button(compositeAction, SWT.NONE);
		btnClear.setEnabled(false);
		btnClear.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_CLEAR);
			}
			@Override
			public void widgetDefaultSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_CLEAR);
			}
		});
		btnClear.setToolTipText(CLEAR_REGISTERED_SHOW);
		btnClear.setText(BUTTON_CLEAR);
		
		btnUndo = new Button(compositeAction, SWT.FLAT);
		btnUndo.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_UNDO);
			}
			@Override
			public void widgetDefaultSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_UNDO);
			}
		});
		btnUndo.setEnabled(false);
		btnUndo.setText("\u00C5ngra");
		
		btnRedo = new Button(compositeAction, SWT.NONE);
		btnRedo.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_REDO);
			}
			@Override
			public void widgetDefaultSelected(SelectionEvent e) {
				buttonAction(ButtonPressed.BUTTON_PRESSED_REDO);
			}
		});
		btnRedo.setEnabled(false);
		btnRedo.setText("Igen");
	}


//	/**
//	 * 
//	 */
//	private void createActivityComposite() {
//		//		Configurable Activity
//		// TODO: Configurable Activity
//		compositeEventCfg = new Composite(compositeRight, SWT.NONE);
//		//		compositeEventCfg.setEnabled(false);
//		rl_compositeEventCfg = new RowLayout(SWT.VERTICAL);
//		rl_compositeEventCfg.fill = true;
//		rl_compositeEventCfg.marginHeight = 2;
//		rl_compositeEventCfg.marginWidth = 2;
//		rl_compositeEventCfg.wrap = false;
//		compositeEventCfg.setLayout(rl_compositeEventCfg);
//		
//		composite_2 = new Composite(compositeEventCfg, SWT.NONE);
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
//		composite_1 = new Composite(compositeEventCfg, SWT.NONE);
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
//		composite_3 = new Composite(compositeEventCfg, SWT.NONE);
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
//	}

	private void initialize() {
//		btnState.get(Event.EVENT).setSelection(true);
//		this.radioState = Event.EVENT;
		stateSelected(Event.EVENT);
		this.nowCounter = 0;
		this.lastHour = 0;
		this.lastMinute = 0;
	}

	protected void stateSelected(String state) {
		if (radioState != null)
			btnState.get(radioState).setSelection(false);
		this.radioState = state;
		btnState.get(state).setSelection(true);
		if (state.equals(Event.EVENT)) {
			activity.setEnabled(true);
		} else {
			activity.setEnabled(false);
		}
	}

	private String getDate() {
		int y = this.date.getYear();
		int m = this.date.getMonth() + 1;
		int d = this.date.getDay();
		
		StringBuilder date = new StringBuilder(10);
		date.append(y);
		date.append("-");
		if (m < 10)
			date.append("0");			
		date.append(m);
		date.append("-");
		if (d < 10)
			date.append("0");			
		date.append(d);
		
		return date.toString();
	}
	
	private String getTime() {
		int h = this.time.getHours();
		int m = this.time.getMinutes();
		
		StringBuilder time = new StringBuilder(5);
		if (h < 10)
			time.append("0");			
		time.append(h);
		time.append(":");
		if (m < 10)
			time.append("0");			
		time.append(m);
		
		return time.toString();
	}
	
	private void setDateTimeNow(int cnt) {
		date.setDate(clock.getYearI(), clock.getMonthI(), clock.getDayI());
		time.setTime(clock.getHourI(), clock.getMinuteI(), 0);
		this.nowCounter  = cnt;
	}

	private void buttonAction(ButtonPressed but) {
		String date;
		String time;
		String activity;
		Event event;

		switch (but) {
		case BUTTON_PRESSED_ADD:
			date = getDate();
			time = getTime();
			event = new Event(date, time, this.radioState);
			// TODO: Configurable event
			if (this.radioState.equals(Event.EVENT)) {
				activity = this.activity.get();
				event.setActivity(activity);
				this.activity.clear();
			}
			this.dayList.add(event);
			break;

		case BUTTON_PRESSED_CHANGE:
			date = getDate();
			time = getTime();
			event = new Event(date, time, this.radioState);
			// TODO: Configurable event
			if (this.radioState.equals(Event.EVENT)) {
				activity = this.activity.get();
				event.setActivity(activity);
				this.activity.clear();
			}
			if (! dayListSelectedEvent.equals(event)) {
//				dayListSelectedEvent.copy(event);
				dayList.replace(dayListSelectedEvent, event);
			}
			break;
			
		case BUTTON_PRESSED_REMOVE:
			dayList.remove(dayListSelectedEvent);
			// TODO: Configurable event
			this.activity.clear();
			break;
			
		case BUTTON_PRESSED_CLEAR:
//			wDayList.deselectAll();
			dayListSelectedEvent = null;
			this.activity.clear();
			break;
			
		case BUTTON_PRESSED_UNDO:
			dayList.undo();
			dayListSelectedEvent = null;
			break;
			
		case BUTTON_PRESSED_REDO:
			dayList.redo();
			dayListSelectedEvent = null;
			break;
			
		default:
			break;
		}

		nowCounter = 0;
		setDateTimeNow(0);
		updateDayList();
//		this.date.
		// TODO: Today? How do we handle a date other than today in daylist
		//       This is also an issue Edit events for another day
		//       Java tutorial:  "How to Use Spinners"
	}
	
	public void updateDayList() {
		String date = getDate();
		this.wDayList.removeAll();
		ArrayList<Event> l = this.dayList.getDate(date);
		for (Event event : l) {
			this.wDayList.add(event.format());
		}
		btnChangeEvent.setEnabled(false);
		btnRemoveEvent.setEnabled(false);
		btnClear.setEnabled(false);
		btnUndo.setEnabled(! this.dayList.isUndoEmpty());			
		btnRedo.setEnabled(! this.dayList.isRedoEmpty());			
	}

	private void startClock() {
		clock = new Clock();
		clock.timerSecond(this);
//		clockTimer = new Timer(1000, this);
////		clockTimer = new Timer(6000, this);
//		clockTimer.start();
		clock.start();
	}
	
//	@Override
//	public void actionPerformed(ActionEvent e) {
//		clock.tick();
//	}

	@Override
	public void executeEvent(ClockEventMethod e) {
		display.asyncExec(new Runnable() {
			@Override
			public void run() {
				int h, m;
				if (!shlTidbox.isDisposed()) {
					shlTidbox.setText(title +
									  " " + clock.getDayOfWeek() +
									  " Vecka: " + clock.getWeek() +
									  " Datum: " + clock.getDateTime());
//									  + " w: " + clock.getLastTimeMillis());
					h = clock.getHourI();
					m = clock.getMinuteI();
					if (nowCounter > 0) {
						nowCounter--;
					} else if (lastMinute != m || lastHour != h) {
						setDateTimeNow(0);
						lastMinute = m;
						lastHour = h;
						updateDayList();
					}
				}
			}
		}
		);
	}

	private void exit() {
//		clockTimer.stop();
		clock.stop();
		shlTidbox.setText(TIDBOX_VERSION + " Exiting");
		times.save();
		shlTidbox.dispose();
	}
}
