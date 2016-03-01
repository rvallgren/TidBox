package se.roland.tidbox.gui;

import java.util.ArrayList;
import java.util.HashMap;

import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;
//import org.eclipse.swt.widgets.Text;
import org.eclipse.swt.widgets.List;
import org.eclipse.swt.widgets.ToolBar;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.DateTime;
import org.eclipse.swt.widgets.Composite;
//import org.eclipse.swt.widgets.Control;
//import org.eclipse.swt.widgets.Text;
import org.eclipse.swt.widgets.ToolItem;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.layout.RowLayout;
//import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.custom.ScrolledComposite;
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;

import se.roland.tidbox.Clock;
import se.roland.tidbox.ClockEventMethod;
import se.roland.tidbox.data.DayList;
import se.roland.tidbox.data.Event;
import se.roland.tidbox.data.Times;
import se.roland.tidbox.data.activity.ActivityConfigurationBuilder;
import se.roland.tidbox.data.activity.ActivityConfigurationItem;

import org.eclipse.swt.layout.RowData;
//import org.eclipse.swt.events.KeyAdapter;
//import org.eclipse.swt.events.KeyEvent;
import org.eclipse.swt.events.ShellAdapter;
import org.eclipse.swt.events.ShellEvent;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.layout.FillLayout;

//public class Main implements ClockEventMethod, ActionListener {
public class Main implements ClockEventMethod {

	private static final String TOOL_TIP_SHOW_NOW_TIME = "Visa aktuell tid";
	private static final String TOOL_TIP_UNDO = "\u00C5ngra senaste";
	private static final String TOOL_TIP_REDO = "Registrera igen";
	private static final String REDO_BUTTON = "Igen";
	private static final String UNDO_BUTTON = "\u00C5ngra";
	private static final String TOOL_TIP_CLICK_TO_SELECT = "Klicka f\u00F6r att visa";
	private static final String BUTTON_DATETTIME_NOW = "Nu";
	private static final String STATE_ENDEVENT = "Sluta h\u00E4ndelse";
	private static final String STATE_BEGINEVENT = "B\u00F6rja h\u00E4ndelse";
	private static final String STATE_ENDPAUS = "Sluta paus";
	private static final String STATE_BEGINPAUSE = "B\u00F6rja paus";
	private static final String STATE_ENDWORKDAY = "Sluta arbetsdagen";
	private static final String STATE_BEGINWORKDAY = "B\u00F6rja arbetsdagen";
	private static final String BUTTON_REMOVE = "Ta bort";
	private static final String TOOL_TIP_REMOVE_REGISTERED_ITEM = "Tag bort en registrering";
	private static final String BUTTON_CHANGE = "\u00C4ndra";
	private static final String TOOL_TIP_CHANGE_REGISTERED_ITEM = "\u00C4ndra tid eller egenskaper f\u00F6r en registrering";
	private static final String TOOL_TIP_CLEAR_REGISTERED_SHOW = "Rensa inmatningsfält";
	private static final String BUTTON_CLEAR = "Rensa";
	private static final String LABEL_ADD = "L\u00E4gg till";
	private static final String TOOL_TIP_LABEL_ADD_EVENT = "L\u00E4gg till h\u00E4ndelse";
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

	private String title = String.join(" ", TIDBOX_TITLE, TIDBOX_VERSION);

	protected Shell shlTidbox;
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
	protected Composite compositeMain;
	protected Composite compositeLeft;
	protected RowLayout left_rl_composite;
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
	protected Activity activity;
	protected Button btnNow;
	protected Composite compositeRegistrationTypeSelection;
	
	// TODO EventCfg
//	private Composite compositeEventCfg;
//	private RowLayout rl_compositeEventCfg;

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
	private ActivityConfigurationBuilder activityCfgBuild;
	private ToolBar toolBar_1;
	private ToolItem tltmTestar;
	private Button stateRadioBtnBeginWork;
	private Button stateRadioBtnEndWork;
	private Button stateRadioBtnBeginPause;
	private Button stateRadioBtnEndPause;
	private Button stateRadioBtnBeginEvent;
	private Button stateRadioBtnEndEvent;
	private Composite compositeDatTimeLabel;
	private Composite compositeRegistrationType;
	private Composite compositeRegistrationAction;
	private Composite compositeRegistrationTypeLabel;
	private Label lblTyp;
	private Composite composite_1;
//	private Point compositeSize;
//	private Point shlSize;
	

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
	 * Open the window.'
	 * TODO: Separate GUI and application code
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
		printSizes("Initial");
//		compositeSize.x += 20;
//		compositeSize.y += 20;
//		shlTidbox.setSize(compositeSize);
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
//		shlTidbox.setSize(786, 421);
//		shlTidbox.setSize(new Point(786, 421));
		shlTidbox.setSize(new Point(597, 417));
		shlTidbox.setMinimumSize(new Point(461, 294));
		shlTidbox.setToolTipText("");
		shlTidbox.addShellListener(new ShellAdapter() {
			@Override
			public void shellClosed(ShellEvent e) {
				printSizes("Exit");
				exit();
			}
		});

		shlTidbox.setText(title);
		
		createMenuBar();

		composite = new Composite(shlTidbox, SWT.NONE);
		rl_composite = new RowLayout(SWT.VERTICAL);
		rl_composite.wrap = false;
		rl_composite.fill = true;
		composite.setLayout(rl_composite);
		
		compositeMain = new Composite(composite, SWT.BORDER);
		RowLayout rl_compositeMain = new RowLayout(SWT.HORIZONTAL);
		compositeMain.setLayout(rl_compositeMain);
				
		//		Left
		compositeLeft = new Composite(compositeMain, SWT.NONE);
		//		compositeLeft.setToolTipText("H\u00E4ndelser f\u00F6r dagen");
		left_rl_composite = new RowLayout(SWT.VERTICAL);
		left_rl_composite.justify = true;
		left_rl_composite.fill = true;
		left_rl_composite.center = true;
		left_rl_composite.wrap = false;
		compositeLeft.setLayout(left_rl_composite);
		
		wDayList = new List(compositeLeft, SWT.BORDER | SWT.H_SCROLL | SWT.V_SCROLL);
		wDayList.setLayoutData(new RowData(150, 200));
		wDayList.setToolTipText(TOOL_TIP_CLICK_TO_SELECT);
		wDayList.addSelectionListener(new SelectionAdapter() {
											
			@Override
			public void widgetSelected(SelectionEvent e) {
				dayListSelectedEvent = dayList.get(wDayList.getSelectionIndex());
				setDateW(dayListSelectedEvent.getYearI(), dayListSelectedEvent.getMonthI(), dayListSelectedEvent.getDayI());
				setTimeW(dayListSelectedEvent.getHourI(), dayListSelectedEvent.getMinuteI());
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
//				btnClear.setEnabled(true);
				nowCounter = 120;
			}
		});
		
		//		Right
		compositeRight = new Composite(compositeMain, SWT.BORDER);
		right_rl_composite = new RowLayout(SWT.VERTICAL);
		right_rl_composite.justify = true;
		right_rl_composite.fill = true;
		right_rl_composite.center = true;
		compositeRight.setLayout(right_rl_composite);
										
		toolBar = new ToolBar(compositeRight, SWT.BORDER | SWT.FLAT | SWT.WRAP | SWT.RIGHT);
				
		tltmToday = new ToolItem(toolBar, SWT.RADIO);
		tltmToday.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				setToday();
			}
		});
		//		tltmToday.setEnabled(false);
		tltmToday.setText(TOOL_TODAY);
		
		tltmYesterday = new ToolItem(toolBar, SWT.RADIO);
		tltmYesterday.setEnabled(false);
		tltmYesterday.setText(TOOL_YESTERDAY);
								
		//		Date Time
		compositeDateTime = new Composite(compositeRight, SWT.NONE);
		rl_compositeDateTime = new RowLayout(SWT.HORIZONTAL);
		rl_compositeDateTime.fill = true;
		rl_compositeDateTime.wrap = false;
		compositeDateTime.setLayout(rl_compositeDateTime);
		
		compositeDatTimeLabel = new Composite(compositeDateTime, SWT.NONE);
		RowLayout rl_composite_1 = new RowLayout(SWT.VERTICAL);
		rl_composite_1.wrap = false;
		rl_composite_1.pack = false;
		rl_composite_1.justify = true;
		compositeDatTimeLabel.setLayout(rl_composite_1);
		
		lblDateTime = new Label(compositeDatTimeLabel, SWT.HORIZONTAL | SWT.CENTER);
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
		btnNow.setToolTipText(TOOL_TIP_SHOW_NOW_TIME);
		btnNow.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				setDateTimeNow(60);
//				clock.start();
												
			}
		});
		btnNow.setText(BUTTON_DATETTIME_NOW);
		
		compositeRegistrationType = new Composite(compositeRight, SWT.NONE);
		RowLayout rl_composite_2 = new RowLayout(SWT.HORIZONTAL);
		rl_composite_2.fill = true;
		compositeRegistrationType.setLayout(rl_composite_2);
		
		compositeRegistrationTypeLabel = new Composite(compositeRegistrationType, SWT.NONE);
		RowLayout rl_compositeRegTypeLabel = new RowLayout(SWT.VERTICAL);
		rl_compositeRegTypeLabel.wrap = false;
		rl_compositeRegTypeLabel.pack = false;
		rl_compositeRegTypeLabel.justify = true;
		compositeRegistrationTypeLabel.setLayout(rl_compositeRegTypeLabel);
		
		lblTyp = new Label(compositeRegistrationTypeLabel, SWT.HORIZONTAL | SWT.CENTER);
		lblTyp.setText("Typ:");
		// State
		compositeRegistrationTypeSelection = new Composite(compositeRegistrationType, SWT.NONE);
		GridLayout gl_compositeRegistrationTypeSelection = new GridLayout(2, true);
		gl_compositeRegistrationTypeSelection.horizontalSpacing = 20;
		gl_compositeRegistrationTypeSelection.marginRight = 10;
		gl_compositeRegistrationTypeSelection.marginLeft = 9;
		compositeRegistrationTypeSelection.setLayout(gl_compositeRegistrationTypeSelection);
		//		stateRadioGroup = new ButtonGroup();
										
		// TODO: Foreach loop??
		stateRadioBtnBeginWork = new Button(compositeRegistrationTypeSelection, SWT.RADIO);
		//		stateRadioBtn.setData(Event.BEGINWORK);
		stateRadioBtnBeginWork.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.BEGINWORK);
			}
		});
		stateRadioBtnBeginWork.setText(STATE_BEGINWORKDAY);
		//		stateRadioGroup.add(tmp);
		btnState.put(Event.BEGINWORK, stateRadioBtnBeginWork);
																
		stateRadioBtnEndWork = new Button(compositeRegistrationTypeSelection, SWT.RADIO);
		//		tmp.setData(Event.WORKEND);
		stateRadioBtnEndWork.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.WORKEND);
			}
		});
		stateRadioBtnEndWork.setText(STATE_ENDWORKDAY);
		btnState.put(Event.WORKEND, stateRadioBtnEndWork);
																		
		stateRadioBtnBeginPause = new Button(compositeRegistrationTypeSelection, SWT.RADIO);
		//		tmp.setData(Event.PAUSE);
		stateRadioBtnBeginPause.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.PAUSE);
			}
		});
		stateRadioBtnBeginPause.setText(STATE_BEGINPAUSE);
		btnState.put(Event.PAUSE, stateRadioBtnBeginPause);
																				
		stateRadioBtnEndPause = new Button(compositeRegistrationTypeSelection, SWT.RADIO);
		//		btnEndPause.setData(Event.ENDPAUSE);
		stateRadioBtnEndPause.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.ENDPAUSE);
			}
		});
		stateRadioBtnEndPause.setText(STATE_ENDPAUS);
		btnState.put(Event.ENDPAUSE, stateRadioBtnEndPause);
																								
																										
		stateRadioBtnBeginEvent = new Button(compositeRegistrationTypeSelection, SWT.RADIO);
		//		btnBeginEvent.setData(Event.EVENT);
		stateRadioBtnBeginEvent.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.EVENT);
			}
		});
		stateRadioBtnBeginEvent.setText(STATE_BEGINEVENT);
		btnState.put(Event.EVENT, stateRadioBtnBeginEvent);
																														
		stateRadioBtnEndEvent = new Button(compositeRegistrationTypeSelection, SWT.RADIO);
		//		btnEndEvent.setData(Event.ENDEVENT);
		stateRadioBtnEndEvent.addSelectionListener(new SelectionAdapter() {
			@Override
			public void widgetSelected(SelectionEvent e) {
				stateSelected(Event.ENDEVENT);
			}
		});
		stateRadioBtnEndEvent.setText(STATE_ENDEVENT);
		btnState.put(Event.ENDEVENT, stateRadioBtnEndEvent);
		//		Registrations handling
		compositeAction = new Composite(compositeRight, SWT.NONE);
		rl_compositeAction = new RowLayout(SWT.HORIZONTAL);
		rl_compositeAction.wrap = false;
		rl_compositeAction.fill = true;
		compositeAction.setLayout(rl_compositeAction);
		
		compositeRegistrationAction = new Composite(compositeAction, SWT.NONE);
		RowLayout rl_compositeRegistrationAction = new RowLayout(SWT.VERTICAL);
		rl_compositeRegistrationAction.wrap = false;
		rl_compositeRegistrationAction.pack = false;
		rl_compositeRegistrationAction.justify = true;
		compositeRegistrationAction.setLayout(rl_compositeRegistrationAction);
		
		lblAction = new Label(compositeRegistrationAction, SWT.CENTER);
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
		btnAddEvent.setToolTipText(TOOL_TIP_LABEL_ADD_EVENT);
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
		btnRemoveEvent.setToolTipText(TOOL_TIP_REMOVE_REGISTERED_ITEM);
		btnRemoveEvent.setText(BUTTON_REMOVE);
																																
		btnClear = new Button(compositeAction, SWT.NONE);
//		btnClear.setEnabled(false);
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
		btnClear.setToolTipText(TOOL_TIP_CLEAR_REGISTERED_SHOW);
		btnClear.setText(BUTTON_CLEAR);
																																
		btnUndo = new Button(compositeAction, SWT.FLAT);
		btnUndo.setToolTipText(TOOL_TIP_UNDO);
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
		btnUndo.setText(UNDO_BUTTON);
		
		btnRedo = new Button(compositeAction, SWT.NONE);
		btnRedo.setToolTipText(TOOL_TIP_REDO);
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
		btnRedo.setText(REDO_BUTTON);
		
		// TODO should be read from file
//		activityCfg = new ActivityConfigurationItem("2013-12-18", 1);
//		activityCfg.add("Project", 'd', 6);
		activityCfgBuild = new ActivityConfigurationBuilder("2013-12-18", 4);
//		Project:d:6
		activityCfgBuild.add("Project", 'd', 6);
//		Task:D:8
		activityCfgBuild.add("Task", 'D', 8);
//		Type:W:17
		activityCfgBuild.add("Type", 'W', 17);
//		Details:.:40
		activityCfgBuild.add("Details", '.', 40);
		
		activity = new Activity(compositeRight);
		activity.createActivityComposite(activityCfgBuild.createActivityConfiguration());
		
//		composite_1 = new Composite(compositeRight, SWT.NONE);
//		composite_1.setLayout(new RowLayout(SWT.VERTICAL));
//		
//		Label lblLabel = new Label(composite_1, SWT.NONE);
//		lblLabel.setText("Label 1");
//		
//		Label lblLabel_1 = new Label(composite_1, SWT.NONE);
//		lblLabel_1.setText("Label 2");

//		toolBar_1 = new ToolBar(compositeRight, SWT.BORDER | SWT.FLAT | SWT.RIGHT);
//		
//		tltmTestar = new ToolItem(toolBar_1, SWT.CHECK);
//		tltmTestar.setToolTipText("Enbart f\u00F6r test av layouthanteraren");
//		tltmTestar.setText("Testar");

	}

	/**
	 * 
	 */
	private void createMenuBar() {
		shlTidbox.setLayout(new FillLayout(SWT.HORIZONTAL));
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

	protected void stateClear() {
		stateSelected(Event.EVENT);
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
		setDateW(clock.getYearI(), clock.getMonthI(), clock.getDayI());
		setTimeW(clock.getHourI(), clock.getMinuteI());
		this.nowCounter  = cnt;
	}

	private void setToday() {
		setDateW(clock.getYearI(), clock.getMonthI(), clock.getDayI());
	}

	private void setDateW(int y, int m, int d) {
		date.setDate(y, m-1, d);
	}
	
	private void setTimeW(int h, int m) {
		time.setTime(h, m, 0);
	}
	
	private void buttonAction(ButtonPressed but) {
		String date;
		String time;
		String activity;
		Event event;
		boolean errors = false;

		switch (but) {
		case BUTTON_PRESSED_ADD:
			date = getDate();
			time = getTime();
			// TODO: Configurable event
			if (this.radioState.equals(Event.EVENT)) {
				activity = this.activity.get();
				if (activity != null) {
					this.dayList.add(Event.make(date, time, this.radioState, activity));
					this.activity.clear();
					stateClear();
				} else {
					errors = true;
				}
			} else {
				this.dayList.add(Event.make(date, time, this.radioState));
				stateClear();
			}
			break;

		case BUTTON_PRESSED_CHANGE:
			date = getDate();
			time = getTime();
			// TODO: Configurable event
			if (this.radioState.equals(Event.EVENT)) {
				activity = this.activity.get();
				if (activity != null) {
					event = Event.make(date, time, this.radioState, activity);
					if (! dayListSelectedEvent.equals(event)) {
						dayList.replace(dayListSelectedEvent, event);
						this.activity.clear();
						stateClear();
					}
				} else {
					errors = true;
				}
			} else {
				event = Event.make(date, time, this.radioState);
				if (! dayListSelectedEvent.equals(event)) {
					dayList.replace(dayListSelectedEvent, event);
					stateClear();
				}
			}
					
			break;
			
		case BUTTON_PRESSED_REMOVE:
			dayList.remove(dayListSelectedEvent);
			// TODO: Configurable event
			this.activity.clear();
			stateClear();
			break;
			
		case BUTTON_PRESSED_CLEAR:
//			wDayList.deselectAll();
			dayListSelectedEvent = null;
			this.activity.clear();
			stateClear();
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
		if (! errors) {
			setDateTimeNow(0);
			updateDayList();
		}
//		this.date.
		// TODO: Today? How do we handle a date other than today in daylist
		//       This is also an issue Edit events for another day
		//       Java tutorial:  "How to Use Spinners"
	}
	
	private void updateDayList() {
		String date = getDate();
		this.wDayList.removeAll();
		ArrayList<Event> l = this.dayList.getDate(date);
		for (Event event : l) {
			this.wDayList.add(event.format());
		}
		btnChangeEvent.setEnabled(false);
		btnRemoveEvent.setEnabled(false);
//		btnClear.setEnabled(false);
		btnUndo.setEnabled(! this.dayList.isUndoEmpty());			
		btnRedo.setEnabled(! this.dayList.isRedoEmpty());			
	}

	private void printSizes(String message) {
		Point compositeSize = composite.getSize();
		Point shlSize = shlTidbox.getSize();
		System.out.println(message + " sizes");
		System.out.println(" Composite:  " + compositeSize);
		System.out.println(" Window: " + shlSize);
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
					shlTidbox.setText(String.join(" ",
										title,
										clock.getDayOfWeek(),
									    "Vecka:", clock.getWeek(),
									    "Datum:", clock.getDateTime()
									    )
							);
//									  + "w:" + clock.getLastTimeMillis());
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
		shlTidbox.setText(String.join(" ", TIDBOX_VERSION, "Exiting"));
		times.save();
		shlTidbox.dispose();
	}
}
