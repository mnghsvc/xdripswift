import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications
import SwiftCharts
import HealthKitUI
import AVFoundation
import PieCharts
import WatchConnectivity
import SwiftUI

/// viewcontroller for the home screen
final class RootViewController: UIViewController, ObservableObject {
    
    // MARK: - Properties - Outlets and Actions for buttons and labels in home screen
    
    private var session: WCSession?
    
    
    @IBOutlet weak var toolbarOutlet: UIToolbar!
    
    
    @IBOutlet weak var preSnoozeToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func preSnoozeToolbarButtonAction(_ sender: UIBarButtonItem) {
        // opens the SnoozeViewController, see storyboard
    }
    
    @IBOutlet weak var bgReadingsToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func bgReadingsToolbarButtonAction(_ sender: UIBarButtonItem) {
        showBgReadingsView()
    }
    
    @IBOutlet weak var sensorToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func sensorToolbarButtonAction(_ sender: UIBarButtonItem) {
        createAndPresentSensorButtonActionSheet()
    }
    
    @IBOutlet weak var calibrateToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func calibrateToolbarButtonAction(_ sender: UIBarButtonItem) {
        
        // if this is a transmitter that does not require and is not allowed to be calibrated, then give warning message
        if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), (cgmTransmitter.isWebOOPEnabled() && !cgmTransmitter.overruleIsWebOOPEnabled()) {
            
            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.calibrationNotNecessary, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
            
            trace("calibration : user clicked the calibrate button", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
            requestCalibration(userRequested: true)
        }
        
    }
    
    
    @IBOutlet weak var helpToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func helpToolbarButtonAction(_ sender: UIBarButtonItem) {
        
        // get the 2 character language code for the App Locale (i.e. "en", "es", "nl", "fr")
        let languageCode = NSLocale.current.languageCode
            
        // if the user has the app in a language other than English and they have the "auto translate" option selected, then load the help pages through Google Translate
        // important to check the the URLs actually exist in ConstansHomeView before trying to open them
        if let languageCode = languageCode, languageCode != ConstantsHomeView.onlineHelpBaseLocale && UserDefaults.standard.translateOnlineHelp {
            
            guard let url = URL(string: ConstantsHomeView.onlineHelpURLTranslated1 + languageCode + ConstantsHomeView.onlineHelpURLTranslated2) else { return }
            
            UIApplication.shared.open(url)
            
        } else {
            
            // so the user is running the app in English
            // or
            // NSLocale.current.languageCode returned a nil value
            // or
            // they don't want to translate so let's just load it directly
            guard let url = URL(string: ConstantsHomeView.onlineHelpURL) else { return }
            
            UIApplication.shared.open(url)
        
        }
        
    }
    
    /// outlet for the lock button - it will change text based upon whether they screen is locked or not
    @IBOutlet weak var screenLockToolbarButtonOutlet: UIBarButtonItem!
    
    /// call the screen lock alert when the button is pressed
    @IBAction func screenLockToolbarButtonAction(_ sender: UIBarButtonItem) {
        screenLockAlert(showClock: true)
    }
    
    
    /// outlet for label that shows how many minutes ago and so on
    @IBOutlet weak var minutesLabelOutlet: UILabel!
    
    @IBOutlet weak var minutesAgoLabelOutlet: UILabel!
    
    
    /// outlet for label that shows difference with previous reading
    @IBOutlet weak var diffLabelOutlet: UILabel!
    
    @IBOutlet weak var diffLabelUnitOutlet: UILabel!
    
    
    /// outlet for label that shows the current reading
    @IBOutlet weak var valueLabelOutlet: UILabel!
    
    @IBAction func valueLabelLongPressGestureRecognizerAction(_ sender: UILongPressGestureRecognizer) {
        
        valueLabelLongPressed(sender)
        
    }
    
    
    /// outlet for chart
    @IBOutlet weak var chartOutlet: BloodGlucoseChartView!
    
    
    /// outlet for mini-chart showing a fixed history of x hours
    @IBOutlet weak var miniChartOutlet: BloodGlucoseChartView!

    @IBOutlet weak var miniChartHoursLabelOutlet: UILabel!
    
    
    @IBOutlet weak var segmentedControlsView: UIView!
    
    /// outlets for chart time period selector
    @IBOutlet weak var segmentedControlChartHours: UISegmentedControl!
    
    @IBAction func chartHoursChanged(_ sender: Any) {
        
        // update the chart period in hours
        switch segmentedControlChartHours.selectedSegmentIndex
            {
            case 0:
                UserDefaults.standard.chartWidthInHours = 3
            case 1:
                UserDefaults.standard.chartWidthInHours = 5
            case 2:
                UserDefaults.standard.chartWidthInHours = 12
            case 3:
                UserDefaults.standard.chartWidthInHours = 24
            default:
                break
            }
        
    }
    
    // create a view outlet (with the statistics day control inside) so that we can show/hide it as necessary
    @IBOutlet weak var segmentedControlStatisticsDaysView: UIView!
    
    @IBOutlet weak var segmentedControlStatisticsDays: UISegmentedControl!
    
    @IBAction func statisticsDaysChanged(_ sender: Any) {
        
        // update the days to use for statistics calculations
        switch segmentedControlStatisticsDays.selectedSegmentIndex
            {
            case 0:
                UserDefaults.standard.daysToUseStatistics = 0
            case 1:
                UserDefaults.standard.daysToUseStatistics = 1
            case 2:
                UserDefaults.standard.daysToUseStatistics = 7
            case 3:
                UserDefaults.standard.daysToUseStatistics = 30
            case 4:
                UserDefaults.standard.daysToUseStatistics = 90
            default:
                break
            }
        
    }
        
    /// outlets for statistics view
    @IBOutlet weak var statisticsView: UIView!
    @IBOutlet weak var pieChartOutlet: PieChart!
    @IBOutlet weak var lowStatisticLabelOutlet: UILabel!
    @IBOutlet weak var inRangeStatisticLabelOutlet: UILabel!
    @IBOutlet weak var highStatisticLabelOutlet: UILabel!
    @IBOutlet weak var averageStatisticLabelOutlet: UILabel!
    @IBOutlet weak var a1CStatisticLabelOutlet: UILabel!
    @IBOutlet weak var cVStatisticLabelOutlet: UILabel!
    @IBOutlet weak var lowTitleLabelOutlet: UILabel!
    @IBOutlet weak var inRangeTitleLabelOutlet: UILabel!
    @IBOutlet weak var highTitleLabelOutlet: UILabel!
    @IBOutlet weak var averageTitleLabelOutlet: UILabel!
    @IBOutlet weak var a1cTitleLabelOutlet: UILabel!
    @IBOutlet weak var cvTitleLabelOutlet: UILabel!
    @IBOutlet weak var lowLabelOutlet: UILabel!
    @IBOutlet weak var highLabelOutlet: UILabel!
    @IBOutlet weak var pieChartLabelOutlet: UILabel!
    @IBOutlet weak var timePeriodLabelOutlet: UILabel!
    @IBOutlet weak var activityMonitorOutlet: UIActivityIndicatorView!
    
    
    /// clock view
    @IBOutlet weak var clockView: UIView!
    @IBOutlet weak var clockLabelOutlet: UILabel!
        
    @IBOutlet weak var sensorCountdownOutlet: UIImageView!
    
    
    @IBAction func chartPanGestureRecognizerAction(_ sender: UIPanGestureRecognizer) {
        
        guard let glucoseChartManager = glucoseChartManager else {return}
        
        glucoseChartManager.handleUIGestureRecognizer(recognizer: sender, chartOutlet: chartOutlet, completionHandler: {
            
            // user has been panning, if chart is panned backward, then need to set valueLabel to value of latest chartPoint shown in the chart, and minutesAgo text to timeStamp of latestChartPoint
            if glucoseChartManager.chartIsPannedBackward {
                
                if let lastChartPointEarlierThanEndDate = glucoseChartManager.lastChartPointEarlierThanEndDate, let chartAxisValueDate = lastChartPointEarlierThanEndDate.x as? ChartAxisValueDate  {
                    
                    // valueLabel text should not be strikethrough (might still be strikethrough in case latest reading is older than 10 minutes
                    self.valueLabelOutlet.attributedText = nil
                    
                    // set value to value of latest chartPoint
                    self.valueLabelOutlet.text = lastChartPointEarlierThanEndDate.y.scalar.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    
                    // set timestamp to timestamp of latest chartPoint, in red so user can notice this is an old value
                    self.minutesLabelOutlet.text =  self.dateTimeFormatterForMinutesLabelWhenPanning.string(from: chartAxisValueDate.date)
                    self.minutesLabelOutlet.textColor = UIColor.red
                    
                    self.minutesAgoLabelOutlet.text = ""
                    
                    self.valueLabelOutlet.textColor = UIColor.lightGray
                    
                    // apply strikethrough to the BG value text format
                    let attributedString = NSMutableAttributedString(string: self.valueLabelOutlet.text!)
                    attributedString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: 1, range: NSMakeRange(0, attributedString.length))
                    
                    self.valueLabelOutlet.attributedText = attributedString
                    
                    // don't show anything in diff outlet
                    self.diffLabelOutlet.text = ""
                    
                    self.diffLabelUnitOutlet.text = ""
                    
                } else {
                    
                    // this would only be the case if there's no readings withing the shown timeframe
                    self.updateLabelsAndChart(overrideApplicationState: false)
                    
                }
                
            } else {
                
                // chart is not panned, update labels is necessary
                self.updateLabelsAndChart(overrideApplicationState: false)
                
            }
            
        })
        
    }
    
    @IBOutlet var chartPanGestureRecognizerOutlet: UIPanGestureRecognizer!
    
    @IBAction func chartLongPressGestureRecognizerAction(_ sender: UILongPressGestureRecognizer) {
        
        // this one needs trigger in case user has panned, chart is decelerating, user clicks to stop the decleration, call to handleUIGestureRecognizer will stop the deceleration
        // there's no completionhandler needed because the call in chartPanGestureRecognizerAction to handleUIGestureRecognizer already includes a completionhandler
        glucoseChartManager?.handleUIGestureRecognizer(recognizer: sender, chartOutlet: chartOutlet, completionHandler: nil)
        
    }
    
    @IBOutlet var chartLongPressGestureRecognizerOutlet: UILongPressGestureRecognizer!
    
    @IBAction func chartDoubleTapGestureRecognizer(_ sender: UITapGestureRecognizer) {
        
        // if the main chart is double-tapped then force a reset to return to the current date/time, refresh the chart and also all labels
        updateLabelsAndChart(forceReset: true)
        
    }
    
    @IBOutlet var chartDoubleTapGestureRecognizerOutlet: UITapGestureRecognizer!
    
    
    @IBAction func miniChartDoubleTapGestureRecognizer(_ sender: UITapGestureRecognizer) {
        
        
        // move the days range to the next one (or back to the first one) and also set the text. We'll use "24 hours" for the first range (to make it clear it's not a full day, but the last 24 hours), but to keep the UI simpler, we'll use "x days" for the rest.
        switch UserDefaults.standard.miniChartHoursToShow {
            
        case ConstantsGlucoseChart.miniChartHoursToShow1:
            
            UserDefaults.standard.miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow2
            
            miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow / 24).description + " " + Texts_Common.days
            
        case ConstantsGlucoseChart.miniChartHoursToShow2:
            
            UserDefaults.standard.miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow3
            
            miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow / 24).description + " " + Texts_Common.days
            
        case ConstantsGlucoseChart.miniChartHoursToShow3:
            
            UserDefaults.standard.miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow4
            
            miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow / 24).description + " " + Texts_Common.days
            
        case ConstantsGlucoseChart.miniChartHoursToShow4:
            
            // we're already on the last range, so roll back to the first range
            UserDefaults.standard.miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow1
            
            miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow).description + " " + Texts_Common.hours
            
        // the default will never get resolved as there is always an expected value assigned, but we need to include it to keep the compiler happy
        default:
            
            UserDefaults.standard.miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow1
            
            miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow).description + " " + Texts_Common.hours
            
        }
        
        // increase alpha to fully brighten the label temporarily
        miniChartHoursLabelOutlet.alpha = 1.0
        
        // wait for a second and then fade the label back out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            
            // make a animated transition with the label. Fade it out over a couple of seconds.
            UIView.transition(with: self.miniChartHoursLabelOutlet, duration: 2, options: .transitionCrossDissolve, animations: {
                self.miniChartHoursLabelOutlet.alpha = ConstantsGlucoseChart.miniChartHoursToShowLabelAlpha
            })
            
        }
    }
    
    @IBOutlet var miniChartDoubleTapGestureRecognizer: UITapGestureRecognizer!
    
    
    // MARK: - Actions for SwiftUI Hosting Controller integration
    
    @IBSegueAction func segueToBgReadingsView(_ coder: NSCoder) -> UIViewController? {
                    
        return UIHostingController(coder: coder, rootView: BgReadingsView().environmentObject(bgReadingsAccessor!).environmentObject(nightScoutUploadManager!))
            
    }
    
    
    
    // MARK: - Constants for ApplicationManager usage
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create updateLabelsAndChartTimer
    private let applicationManagerKeyCreateupdateLabelsAndChartTimer = "RootViewController-CreateupdateLabelsAndChartTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground
    private let applicationManagerKeyInvalidateupdateLabelsAndChartTimerAndCloseSnoozeViewController = "RootViewController-InvalidateupdateLabelsAndChartTimerAndCloseSnoozeViewController"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - initial calibration
    private let applicationManagerKeyInitialCalibration = "RootViewController-InitialCalibration"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground -  isIdleTimerDisabled
    private let applicationManagerKeyIsIdleTimerDisabled = "RootViewController-isIdleTimerDisabled"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - trace that app goes to background
    private let applicationManagerKeyTraceAppGoesToBackGround = "applicationManagerKeyTraceAppGoesToBackGround"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - trace that app goes to background
    private let applicationManagerKeyTraceAppGoesToForeground = "applicationManagerKeyTraceAppGoesToForeground"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillTerminate - trace that app goes to background
    private let applicationManagerKeyTraceAppWillTerminate = "applicationManagerKeyTraceAppWillTerminate"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - to clean GlucoseChartManager memory
    private let applicationManagerKeyCleanMemoryGlucoseChartManager = "applicationManagerKeyCleanMemoryGlucoseChartManager"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - to initialize the glucoseChartManager and update labels and chart
    private let applicationManagerKeyUpdateLabelsAndChart = "applicationManagerKeyUpdateLabelsAndChart"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - to dismiss screenLockAlertController
    private let applicationManagerKeyDismissScreenLockAlertController = "applicationManagerKeyDismissScreenLockAlertController"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - to do a NightScout Treatment sync
    private let applicationManagerKeyStartNightScoutTreatmentSync = "applicationManagerKeyStartNightScoutTreatmentSync"

    
    // MARK: - Properties - other private properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// coreDataManager to be used throughout the project
    private var coreDataManager:CoreDataManager?
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// calibrator to be used for calibration, value will depend on transmitter type
    private var calibrator:Calibrator?
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor:BgReadingsAccessor?
    
    /// CalibrationsAccessor instance
    private var calibrationsAccessor:CalibrationsAccessor?
	
    /// NightScoutUploadManager instance
    private var nightScoutUploadManager:NightScoutUploadManager?
    
    /// AlerManager instance
    private var alertManager:AlertManager?
    
    /// LoopManager instance
    private var loopManager:LoopManager?
    
    /// SoundPlayer instance
    private var soundPlayer:SoundPlayer?
    
    /// nightScoutFollowManager instance
    private var nightScoutFollowManager:NightScoutFollowManager?
    
    /// dexcomShareUploadManager instance
    private var dexcomShareUploadManager:DexcomShareUploadManager?
    
    /// WatchManager instance
    private var watchManager: WatchManager?
    
    /// healthkit manager instance
    private var healthKitManager:HealthKitManager?
    
    /// reference to activeSensor
    private var activeSensor:Sensor?
    
    /// reference to bgReadingSpeaker
    private var bgReadingSpeaker:BGReadingSpeaker?
    
    /// manages bluetoothPeripherals that this app knows
    private var bluetoothPeripheralManager: BluetoothPeripheralManager?
    
    /// - manage glucose chart
    /// - will be nillified each time the app goes to the background, to avoid unnecessary ram usage (which seems to cause app getting killed)
    /// - will be reinitialized each time the app comes to the foreground
    private var glucoseChartManager: GlucoseChartManager?
    
    /// - manage the mini glucose chart that shows a fixed amount of data
    /// - will be nillified each time the app goes to the background, to avoid unnecessary ram usage (which seems to cause app getting killed)
    /// - will be reinitialized each time the app comes to the foreground
    private var glucoseMiniChartManager: GlucoseMiniChartManager?
    
    /// statisticsManager instance
    private var statisticsManager: StatisticsManager?
    
    /// dateformatter for minutesLabelOutlet, when user is panning the chart
    private let dateTimeFormatterForMinutesLabelWhenPanning: DateFormatter = {
        
        let dateFormatter = DateFormatter()
        
        dateFormatter.amSymbol = ConstantsUI.timeFormatAM
        
        dateFormatter.pmSymbol = ConstantsUI.timeFormatPM
        
        dateFormatter.setLocalizedDateFormatFromTemplate(ConstantsGlucoseChart.dateFormatLatestChartPointWhenPanning)
        
        return dateFormatter
    }()
    
    /// housekeeper instance
    private var houseKeeper: HouseKeeper?
    
    /// current value of webOPEnabled, if nil then it means no cgmTransmitter connected yet , false is used as value
    /// - used to detect changes in the value
    ///
    /// in fact it will never be used with a nil value, except when connecting to a cgm transmitter for the first time
    private var webOOPEnabled: Bool?
    
    /// current value of nonFixedSlopeEnabled, if nil then it means no cgmTransmitter connected yet , false is used as value
    /// - used to detect changes in the value
    ///
    /// in fact it will never be used with a nil value, except when connecting to a cgm transmitter for the first time
    private var nonFixedSlopeEnabled: Bool?
    
    /// when was the last notification created with bgreading, setting to 1 1 1970 initially to avoid having to unwrap it
    private var timeStampLastBGNotification = Date(timeIntervalSince1970: 0)
    
    /// to hold the current state of the screen keep-alive
    private var screenIsLocked: Bool = false
    
    /// date formatter for the clock view
    private var clockDateFormatter = DateFormatter()
    
    /// initiate a Timer object that we will use later to keep the clock view updated if the user activates the screen lock
    private var clockTimer: Timer?
    
    /// UIAlertController to use when user chooses to lock the screen. Defined here so we can dismiss it when app goes to the background
    private var screenLockAlertController: UIAlertController?
    
    /// create the landscape view
    private var landscapeChartViewController: LandscapeChartViewController?

    
    // MARK: - overriden functions
    
    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // never seen it triggered, copied that from Loop
        glucoseChartManager?.cleanUpMemory()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)

        // check if allowed to rotate to landscape view
        updateScreenRotationSettings()
        
        // viewWillAppear when user switches eg from Settings Tab to Home Tab - latest reading value needs to be shown on the view, and also update minutes ago etc.
        updateLabelsAndChart(overrideApplicationState: true)
        
        // show the mini-chart as required
        if !screenIsLocked {
            miniChartOutlet.isHidden = !UserDefaults.standard.showMiniChart
        }
        
        // show the statistics view as required. If not, hide it and show the spacer view to keep segmentedControlChartHours separated a bit more away from the main Tab bar
        if !screenIsLocked {
            statisticsView.isHidden = !UserDefaults.standard.showStatistics
        }
        
        segmentedControlStatisticsDaysView.isHidden = !UserDefaults.standard.showStatistics
        
        if inRangeStatisticLabelOutlet.text == "-" {
            activityMonitorOutlet.isHidden = true
        } else {
            activityMonitorOutlet.isHidden = false
        }
        
        // display the sensor countdown graphics if applicable
        updateSensorCountdown()
        
        // update statistics related outlets
        updateStatistics(animatePieChart: true, overrideApplicationState: true)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
        updateWatchApp()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureWatchKitSession()
        
        // if the user requested to hide the help icon on the main screen, then remove it (and the flexible space next to it)
        // this is because we keep the help icon as the last one in the toolbar item array.
        if !UserDefaults.standard.showHelpIcon {
            
            toolbarOutlet.items!.removeLast(2)
            
        }
        
        // set up the clock view
        clockDateFormatter.dateStyle = .none
        clockDateFormatter.timeStyle = .short
        clockDateFormatter.dateFormat = "HH:mm"
        clockLabelOutlet.font = ConstantsUI.clockLabelFontSize
        clockLabelOutlet.textColor = ConstantsUI.clockLabelColor
        
        
        // ensure the screen layout
        screenLockUpdate(enabled: false)
                
        // this is to force update of userdefaults that are also stored in the shared user defaults
        // these are used by the today widget. After a year or so (september 2021) this can all be deleted
        UserDefaults.standard.urgentLowMarkValueInUserChosenUnit = UserDefaults.standard.urgentLowMarkValueInUserChosenUnit
        UserDefaults.standard.urgentHighMarkValueInUserChosenUnit = UserDefaults.standard.urgentHighMarkValueInUserChosenUnit
        UserDefaults.standard.lowMarkValueInUserChosenUnit = UserDefaults.standard.lowMarkValueInUserChosenUnit
        UserDefaults.standard.highMarkValueInUserChosenUnit = UserDefaults.standard.highMarkValueInUserChosenUnit
        UserDefaults.standard.bloodGlucoseUnitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        
        // set the localized text of the segmented controls
        segmentedControlChartHours.setTitle("3" + Texts_Common.hourshort, forSegmentAt: 0)
        segmentedControlChartHours.setTitle("6" + Texts_Common.hourshort, forSegmentAt: 1)
        segmentedControlChartHours.setTitle("12" + Texts_Common.hourshort, forSegmentAt: 2)
        segmentedControlChartHours.setTitle("24" + Texts_Common.hourshort, forSegmentAt:3)
        
        segmentedControlStatisticsDays.setTitle(Texts_Common.todayshort, forSegmentAt: 0)
        segmentedControlStatisticsDays.setTitle("24" + Texts_Common.hourshort, forSegmentAt: 1)
        segmentedControlStatisticsDays.setTitle("7" + Texts_Common.dayshort, forSegmentAt: 2)
        segmentedControlStatisticsDays.setTitle("30" + Texts_Common.dayshort, forSegmentAt:3)
        segmentedControlStatisticsDays.setTitle("90" + Texts_Common.dayshort, forSegmentAt:4)
               
        // update the segmented control of the chart hours
        switch UserDefaults.standard.chartWidthInHours
            {
            case 3:
                segmentedControlChartHours.selectedSegmentIndex = 0
            case 6:
                segmentedControlChartHours.selectedSegmentIndex = 1
            case 12:
                segmentedControlChartHours.selectedSegmentIndex = 2
            case 24:
                segmentedControlChartHours.selectedSegmentIndex = 3
            default:
                break
            }
        
        
        // update the segmented control of the statistics days
         switch UserDefaults.standard.daysToUseStatistics
             {
             case 0:
                segmentedControlStatisticsDays.selectedSegmentIndex = 0
             case 1:
                segmentedControlStatisticsDays.selectedSegmentIndex = 1
             case 7:
                segmentedControlStatisticsDays.selectedSegmentIndex = 2
             case 30:
                segmentedControlStatisticsDays.selectedSegmentIndex = 3
             case 90:
                segmentedControlStatisticsDays.selectedSegmentIndex = 4
             default:
                 break
             }
        
                
        // format the segmented control of the chart hours if possible (should normally be ok)
        if #available(iOS 13.0, *) {
            
            // set the basic formatting. We basically want it to dissapear into the background
            segmentedControlChartHours.backgroundColor = ConstantsUI.segmentedControlBackgroundColor
            segmentedControlChartHours.tintColor = ConstantsUI.segmentedControlBackgroundColor
            segmentedControlChartHours.layer.borderWidth = ConstantsUI.segmentedControlBorderWidth

            
            // format the unselected segments
            segmentedControlChartHours.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlNormalTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.normal)
            
            // format the selected segment
            segmentedControlChartHours.selectedSegmentTintColor = ConstantsUI.segmentedControlSelectedTintColor
            
            segmentedControlChartHours.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlSelectedTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.selected)
        
        }
        
        
        // format the segmented control of the chart hours if possible (should normally be ok)
        if #available(iOS 13.0, *) {
            
            // set the basic formatting. We basically want it to dissapear into the background
            segmentedControlStatisticsDays.backgroundColor = ConstantsUI.segmentedControlBackgroundColor
            
            segmentedControlStatisticsDays.tintColor = ConstantsUI.segmentedControlBackgroundColor
            
            segmentedControlStatisticsDays.layer.borderWidth = ConstantsUI.segmentedControlBorderWidth

            
            // format the unselected segments
            segmentedControlStatisticsDays.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlNormalTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.normal)
            
            // format the selected segment
            segmentedControlStatisticsDays.selectedSegmentTintColor = ConstantsUI.segmentedControlSelectedTintColor
            
            segmentedControlStatisticsDays.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlSelectedTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.selected)
            
        }
        
        // if a RTL localization is in use (such as arabic), then correctly align the low (<x) and high (>x) label outlets towards the centre of the (now reversed) horizontal stack views
        if UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == UIUserInterfaceLayoutDirection.rightToLeft {
            lowLabelOutlet.textAlignment = .right
            lowTitleLabelOutlet.textAlignment = .left
            highLabelOutlet.textAlignment = .right
            highTitleLabelOutlet.textAlignment = .left
        } else {
            lowLabelOutlet.textAlignment = .left
            lowTitleLabelOutlet.textAlignment = .right
            highLabelOutlet.textAlignment = .left
            highTitleLabelOutlet.textAlignment = .right
        }
        
        
        // enable or disable the buttons 'sensor' and 'calibrate' on top, depending on master or follower
        changeButtonsStatusTo(enabled: UserDefaults.standard.isMaster)
        
        // Setup Core Data Manager - setting up coreDataManager happens asynchronously
        // completion handler is called when finished. This gives the app time to already continue setup which is independent of coredata, like initializing the views
        coreDataManager = CoreDataManager(modelName: ConstantsCoreData.modelName, completion: {
            
            self.setupApplicationData()
            
            // housekeeper should be non nil here, kall housekeeper
            self.houseKeeper?.doAppStartUpHouseKeeping()
            
            // update label texts, minutes ago, diff and value
            self.updateLabelsAndChart(overrideApplicationState: true)
            
            // update the mini-chart
            self.updateMiniChart()
            
            // update sensor countdown
            self.updateSensorCountdown()
            
            // update statistics related outlets
            self.updateStatistics(animatePieChart: true, overrideApplicationState: true)
            
            // create badge counter
            self.createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
            
            // if licenseinfo not yet accepted, show license info with only ok button
            if !UserDefaults.standard.licenseInfoAccepted {
                
                let alert = UIAlertController(title: ConstantsHomeView.applicationName, message: Texts_HomeView.licenseInfo + ConstantsHomeView.infoEmailAddress, actionHandler: {
                    
                    // set licenseInfoAccepted to true
                    UserDefaults.standard.licenseInfoAccepted = true
                    
                    // create info screen about transmitters
                    let infoScreenAlert = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.transmitterInfo, actionHandler: nil)
                    
                    self.present(infoScreenAlert, animated: true, completion: nil)
                    
                })
                
                self.present(alert, animated: true, completion: nil)
                
            }
            
            // launch Nightscout sync
            UserDefaults.standard.nightScoutSyncTreatmentsRequired = true
            
        })
        
        // Setup View
        setupView()
        
        // observe setting changes
        // changing from follower to master or vice versa
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)

        // see if the user has changed the chart x axis timescale
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.KeysCharts.chartWidthInHours.rawValue, options: .new, context: nil)
        
        // have the mini-chart hours been changed?
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.miniChartHoursToShow.rawValue, options: .new, context: nil)
        
        // showing or hiding the mini-chart
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showMiniChart.rawValue, options: .new, context: nil)
        
        // see if the user has changed the statistic days to use
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.daysToUseStatistics.rawValue, options: .new, context: nil)
        
        // bg reading notification and badge, and multiplication factor
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInNotification.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInAppBadge.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.multipleAppBadgeValueWith10.rawValue, options: .new, context: nil)
        // also update of unit requires update of badge
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
        // update show clock value for the screen lock function
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showClockWhenScreenIsLocked.rawValue, options: .new, context: nil)
        
        
        // high mark , low mark , urgent high mark, urgent low mark. change requires redraw of graph
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.urgentLowMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.lowMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.highMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.urgentHighMarkValue.rawValue, options: .new, context: nil)

        // add observer for nightScoutTreatmentsUpdateCounter, to reload the chart whenever a treatment is added or updated or deleted changes
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutTreatmentsUpdateCounter.rawValue, options: .new, context: nil)
        
        // add observer for stopActiveSensor, this will reset the active sensor to nil when the user disconnects an intergrated transmitter/sensor (e.g. Libre 2 Direct). This will help ensure that the sensor countdown is updated disabled until a new sensor is started.
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.stopActiveSensor.rawValue, options: .new, context: nil)

        // setup delegate for UNUserNotificationCenter
        UNUserNotificationCenter.current().delegate = self
        
        // check if app is allowed to send local notification and if not ask it
        UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
            switch notificationSettings.authorizationStatus {
            case .notDetermined, .denied:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
                    if let error = error {
                        trace("Request Notification Authorization Failed : %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
                    }
                }
            default:
                break
            }
        }
        
        // setup self as delegate for tabbarcontroller
        self.tabBarController?.delegate = self
        
        // setup the timer logic for updating the view regularly
        setupUpdateLabelsAndChartTimer()
        
        // setup AVAudioSession
        setupAVAudioSession()
        
        // user may have activated the screen lock function so that the screen stays open, when going back to background, set isIdleTimerDisabled back to false and update the UI so that it's ready to come to foreground when required.
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyIsIdleTimerDisabled, closure: {
            
            UIApplication.shared.isIdleTimerDisabled = false
            
            self.screenLockUpdate(enabled: false)
            
        })
        
        // add tracing when app goes from foreground to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyTraceAppGoesToBackGround, closure: {trace("Application did enter background", log: self.log, category: ConstantsLog.categoryRootView, type: .info)})
        
        // add tracing when app comes to foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyTraceAppGoesToForeground, closure: {trace("Application will enter foreground", log: self.log, category: ConstantsLog.categoryRootView, type: .info)})
        
        // add tracing when app will terminaten - this only works for non-suspended apps, probably (not tested) also works for apps that crash in the background
        ApplicationManager.shared.addClosureToRunWhenAppWillTerminate(key: applicationManagerKeyTraceAppWillTerminate, closure: {trace("Application will terminate", log: self.log, category: ConstantsLog.categoryRootView, type: .info)})
        
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyCleanMemoryGlucoseChartManager, closure: {
            
            self.glucoseChartManager?.cleanUpMemory()
            
        })
        
        // reinitialise glucose chart and also to update labels and chart
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyUpdateLabelsAndChart, closure: {
            
            // Schedule a call to updateLabelsAndChart when the app comes to the foreground, with a delay of 0.5 seconds. Because the application state is not immediately to .active, as a result, updates may not happen - especially the synctreatments may not happen because this may depend on the application state - by making a call just half a second later, when the status is surely = .active, the treatments sync will be done.
            Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateLabelsAndChart), userInfo: nil, repeats:false)

            self.updateLabelsAndChart(overrideApplicationState: true)
            
            self.updateMiniChart()
            
            self.updateSensorCountdown()
            
            // update statistics related outlets
            self.updateStatistics(animatePieChart: false)
            
        })
        
        
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyDismissScreenLockAlertController, closure: {

            self.dismissScreenLockAlertController()
            
        })
        
        // launch nightscout treatment sync whenever the app comes to the foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyStartNightScoutTreatmentSync, closure: {
            UserDefaults.standard.nightScoutSyncTreatmentsRequired = true
        })
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In RootViewController, prepare for segue, Segue had no identifier")
        }
        
        switch segueIdentifier {
        
        case "RootViewToSnoozeView":
            
            guard let vc = segue.destination as? SnoozeViewController else {
                
                fatalError("In RootViewController, prepare for segue, viewcontroller is not SnoozeViewController" )
                
            }
            
            // configure view controller
            vc.configure(alertManager: alertManager)
            
        default:
            break
        }
    }
    
    /// sets AVAudioSession category to AVAudioSession.Category.playback with option mixWithOthers and
    /// AVAudioSession.sharedInstance().setActive(true)
    private func setupAVAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: AVAudioSession.CategoryOptions.mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            trace("in init, could not set AVAudioSession category to playback and mixwithOthers, error = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
    }
    
    // creates activeSensor, bgreadingsAccessor, calibrationsAccessor, NightScoutUploadManager, soundPlayer, dexcomShareUploadManager, nightScoutFollowManager, alertManager, healthKitManager, bgReadingSpeaker, bluetoothPeripheralManager, watchManager, housekeeper
    private func setupApplicationData() {
        
        // setup Trace
        Trace.initialize(coreDataManager: coreDataManager)
        
        // if coreDataManager is nil then there's no reason to continue
        guard let coreDataManager = coreDataManager else {
            fatalError("In setupApplicationData but coreDataManager == nil")
        }
        
        // get currently active sensor
        activeSensor = SensorsAccessor.init(coreDataManager: coreDataManager).fetchActiveSensor()
        
        // instantiate bgReadingsAccessor
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            fatalError("In setupApplicationData, failed to initialize bgReadings")
        }
		
        // instantiate calibrations
        calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        
        // instanstiate Housekeeper
        houseKeeper = HouseKeeper(coreDataManager: coreDataManager)
        
        // setup nightscout synchronizer
        nightScoutUploadManager = NightScoutUploadManager(coreDataManager: coreDataManager, messageHandler: { (title:String, message:String) in
            
            let alert = UIAlertController(title: title, message: message, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        })
        
        // setup SoundPlayer
        soundPlayer = SoundPlayer()
        
        // setup FollowManager
        guard let soundPlayer = soundPlayer else { fatalError("In setupApplicationData, this looks very in appropriate, shame")}
        
        // setup nightscoutmanager
        nightScoutFollowManager = NightScoutFollowManager(coreDataManager: coreDataManager, nightScoutFollowerDelegate: self)
        
        // setup healthkitmanager
        healthKitManager = HealthKitManager(coreDataManager: coreDataManager)
        
        // setup bgReadingSpeaker
        bgReadingSpeaker = BGReadingSpeaker(sharedSoundPlayer: soundPlayer, coreDataManager: coreDataManager)
        
        // setup loopManager
        loopManager = LoopManager(coreDataManager: coreDataManager)
        
        // setup dexcomShareUploadManager
        dexcomShareUploadManager = DexcomShareUploadManager(bgReadingsAccessor: bgReadingsAccessor, messageHandler: { (title:String, message:String) in
            
            let alert = UIAlertController(title: title, message: message, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        })
        
        /// will be called by BluetoothPeripheralManager if cgmTransmitterType changed and/or webOOPEnabled value changed
        /// - function to be used in BluetoothPeripheralManager init function, and also immediately after having initiliazed BluetoothPeripheralManager (it will not get called from within BluetoothPeripheralManager because didSet function is not called from init
        let cgmTransmitterInfoChanged = {
            
            // if cgmTransmitter not nil then reassign calibrator and set UserDefaults.standard.transmitterTypeAsString
            if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() {
                
                // reassign calibrator, even if the type of calibrator would not change
                self.calibrator = self.getCalibrator(cgmTransmitter: cgmTransmitter)
                
                // check if webOOPEnabled changed and if yes stop the sensor
                if let webOOPEnabled = self.webOOPEnabled, webOOPEnabled != cgmTransmitter.isWebOOPEnabled() {
                    
                    trace("in cgmTransmitterInfoChanged, webOOPEnabled value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.isWebOOPEnabled().description)
                    
                    self.stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
                    
                }
                
                // check if nonFixedSlopeEnabled changed and if yes stop the sensor
                if let nonFixedSlopeEnabled = self.nonFixedSlopeEnabled, nonFixedSlopeEnabled != cgmTransmitter.isNonFixedSlopeEnabled() {
                    
                    trace("in cgmTransmitterInfoChanged, nonFixedSlopeEnabled value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.isNonFixedSlopeEnabled().description)
                    
                    self.stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
                    
                }
                
                // check if cgmTransmitterType has changed, if yes reset transmitterBatteryInfo
                if let currentTransmitterType = UserDefaults.standard.cgmTransmitterType, currentTransmitterType != cgmTransmitter.cgmTransmitterType() {
                    
                    UserDefaults.standard.transmitterBatteryInfo = nil
                    
                }
                
                // check if the type of sensor supported by the cgmTransmitterType  has changed, if yes stop the sensor
                if let currentTransmitterType = UserDefaults.standard.cgmTransmitterType, currentTransmitterType.sensorType() != cgmTransmitter.cgmTransmitterType().sensorType() {
                    
                    trace("in cgmTransmitterInfoChanged, sensorType value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.cgmTransmitterType().sensorType().rawValue)
                    
                    self.stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
                    
                }
                
                // assign the new value of webOOPEnabled
                self.webOOPEnabled = cgmTransmitter.isWebOOPEnabled()
                
                // assign the new value of nonFixedSlopeEnabled
                self.nonFixedSlopeEnabled = cgmTransmitter.isNonFixedSlopeEnabled()
                
                // change value of UserDefaults.standard.transmitterTypeAsString
                UserDefaults.standard.cgmTransmitterTypeAsString = cgmTransmitter.cgmTransmitterType().rawValue
                
                // for testing only - for testing make sure there's a transmitter connected,
                // eg a bubble or mm, not necessarily (better not) installed on a sensor
                // CGMMiaoMiaoTransmitter.testRange(cGMTransmitterDelegate: self)
                
            }
            
        }
        
        // setup bluetoothPeripheralManager
        bluetoothPeripheralManager = BluetoothPeripheralManager(coreDataManager: coreDataManager, cgmTransmitterDelegate: self, uIViewController: self, cgmTransmitterInfoChanged: cgmTransmitterInfoChanged)
        
        // to initialize UserDefaults.standard.transmitterTypeAsString
        cgmTransmitterInfoChanged()
        
        // setup alertmanager
        alertManager = AlertManager(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        
        // setup watchmanager
        watchManager = WatchManager(coreDataManager: coreDataManager)
        
        // initialize glucoseChartManager
        glucoseChartManager = GlucoseChartManager(chartLongPressGestureRecognizer: chartLongPressGestureRecognizerOutlet, coreDataManager: coreDataManager)
        
        // initialize glucoseMiniChartManager
        glucoseMiniChartManager = GlucoseMiniChartManager(coreDataManager: coreDataManager)
        
        // initialize statisticsManager
        statisticsManager = StatisticsManager(coreDataManager: coreDataManager)
        
        // initialize chartGenerator in chartOutlet
        self.chartOutlet.chartGenerator = { [weak self] (frame) in
            return self?.glucoseChartManager?.glucoseChartWithFrame(frame)?.view
        }
        
        // initialize chartGenerator in miniChartOutlet
        self.miniChartOutlet.chartGenerator = { [weak self] (frame) in
            return self?.glucoseMiniChartManager?.glucoseChartWithFrame(frame)?.view
        }
        
    }
    
    /// process new glucose data received from transmitter.
    /// - parameters:
    ///     - glucoseData : array with new readings
    ///     - sensorAge : should be present only if it's the first reading(s) being processed for a specific sensor and is needed if it's a transmitterType that returns true to the function canDetectNewSensor
    private func processNewGlucoseData(glucoseData: inout [GlucoseData], sensorAge: TimeInterval?) {
        
        // unwrap calibrationsAccessor and coreDataManager and cgmTransmitter
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = coreDataManager, let cgmTransmitter = bluetoothPeripheralManager?.getCGMTransmitter() else {
            
            trace("in processNewGlucoseData, calibrationsAccessor or coreDataManager or cgmTransmitter is nil", log: log, category: ConstantsLog.categoryRootView, type: .error)
            
            return
            
        }
        
        if activeSensor == nil {
            
            if let sensorAge = sensorAge, cgmTransmitter.cgmTransmitterType().canDetectNewSensor() {

                // no need to send to transmitter, because we received processNewGlucoseData, so transmitter knows the sensor already
                self.startSensor(cGMTransmitter: cgmTransmitter, sensorStarDate: Date(timeIntervalSinceNow: -sensorAge), sensorCode: nil, coreDataManager: coreDataManager, sendToTransmitter: false)
                
            }
            
        }
        
        guard glucoseData.count > 0 else {
            
            trace("glucoseData.count = 0", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            return
            
        }
        
        // also for cases where calibration is not needed, we go through this code
        if let activeSensor = activeSensor, let calibrator = calibrator, let bgReadingsAccessor = bgReadingsAccessor {
            
            trace("calibrator = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, calibrator.description())
            
            // initialize help variables
            var lastCalibrationsForActiveSensorInLastXDays = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
            let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
            let lastCalibrationForActiveSensor = calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
            
            /// used if loopdelay > 0, to check if there was a recent calibration. If so then no readings are added in glucoseData array for a period of loopdelay + an amount of minutes
            let timeStampLastCalibrationForActiveSensor = lastCalibrationForActiveSensor != nil ? lastCalibrationForActiveSensor!.timeStamp : Date(timeIntervalSince1970: 0)
            
            
            
            // next is only if smoothing is enabled, and if there's at least 11 minutes of readings in the glucoseData array, which will normally only be the case for Libre with MM/Bubble
            // if that's the case then delete following existing BgReading's
            //  - younger than 11 minutes : why, because some of the Libre transmitters return readings of the last 15 minutes for every minute, we don't go further than 11 minutes because these readings are not so well smoothed
            //  - younger than the latest calibration : becuase if recalibration is used, then it might be difficult if there's been a recent calibration, to delete and recreate a reading with an earlier timestamp
            //  - younger or equal in age than the oldest reading in the GlucoseData array
            // why :
            //    - in case of Libre, using transmitters like Bubble, MM, .. the 16 most recent readings in GlucoseData are smoothed (done in LibreDataParser if smoothing is enabled)
            //    - specifically the reading at position 5, 6, 7....10 are well smoothed (because they are based on per minute readings of the last 15 minutes, inclusive 5 minutes before and 5 minutes after) we'll use
            //
            //  we will remove the BgReading's and then re-add them using smoothed values
            // so we'll define the timestamp as of when readings should be deleted
            // younger than 11 minutes
            
            // start defining timeStampToDelete as of when existing BgReading's will be deleted
            // this value is also used to verify that glucoseData Array has enough readings
            var timeStampToDelete = Date(timeIntervalSinceNow: -60.0 * (Double)(ConstantsLibreSmoothing.readingsToDeleteInMinutes))
            
            trace("timeStampToDelete =  %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .debug, timeStampToDelete.toString(timeStyle: .long, dateStyle: .none))

            // now check if we'll delete readings
            // there must be a glucoseData.last, here assigning oldestGlucoseData just to unwrap it
            // checking oldestGlucoseData.timeStamp < timeStampToDelete guarantees the oldest reading is older than the one we'll delete, so we're sur we have enough readings in glucoseData to refill the BgReadings
            if let oldestGlucoseData = glucoseData.last, oldestGlucoseData.timeStamp < timeStampToDelete, UserDefaults.standard.smoothLibreValues  {

                // older than the timestamp of the latest calibration (would only be applicable if recalibration is used)
                if let lastCalibrationForActiveSensor = lastCalibrationForActiveSensor {
                    timeStampToDelete = max(timeStampToDelete, lastCalibrationForActiveSensor.timeStamp)
                    trace("after lastcalibrationcheck timeStampToDelete =  %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .debug, timeStampToDelete.toString(timeStyle: .long, dateStyle: .none))
                }

                // there should be one reading per minute for the period that we want to delete readings, otherwise we may not be able to fill up a gap that is created by deleting readings, because the next readings are per 15 minutes. This will typically happen the first time the app runs (or reruns), the first range of readings is only 16 readings not enough to fill up a gap of more than 20 minutes
                // we calculate the number of minutes between timeStampToDelete and now, use the result as index in glucoseData, the timestamp of that element is a number of minutes away from now, that number should be equal to index (as we expect one reading per minute)
                // if that's not the case add 1 minute to timeStampToDelete
                // repeat this until reached
                let checkTimeStampToDelete = { (glucoseData: [GlucoseData]) -> Bool in
                    
                    // just to avoid infinite loop
                    if timeStampToDelete > Date() {return true}
                    
                    let minutes = Int(abs(timeStampToDelete.timeIntervalSince(Date())/60.0))
                    
                    if minutes < glucoseData.count {
                        
                        if abs(glucoseData[minutes].timeStamp.timeIntervalSince(timeStampToDelete)) > 60.0 {
                            
                            // increase timeStampToDelete with 1 minute
                            timeStampToDelete = timeStampToDelete.addingTimeInterval(1.0 * 60)
                            
                            return false
                            
                        }
                        
                        return true
                        
                    } else {
                        // should never come here
                        // increase timeStampToDelete with 5 minutes
                        timeStampToDelete = timeStampToDelete.addingTimeInterval(1.0 * 60)
                        
                        return false
                    }
                    
                }
                
                // repeat the function checkTimeStampToDelete until timeStampToDelete is high enough so that we delete only bgReading's without creating a gap that can't be filled in
                while !checkTimeStampToDelete(glucoseData) {}
                
                // get the readings to be deleted - delete also non-calibrated readings
                let lastBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: timeStampToDelete, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                
                // delete them
                for reading in lastBgReadings {
                    
                    trace("reading being deleted with timestamp =  %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .debug, reading.timeStamp.toString(timeStyle: .long, dateStyle: .none))
                    
                    coreDataManager.mainManagedObjectContext.delete(reading)
                    
                    coreDataManager.saveChanges()
                    
                }
                
                // as we're deleting readings, glucoseChartPoints need to be updated, otherwise we keep seeing old values
                // this is the easiest way to achieve it
                glucoseChartManager?.cleanUpMemory()
                

            }
            
            // was a new reading created or not ?
            var newReadingCreated = false
            
            // assign value of timeStampLastBgReading
            var timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            if let lastReading = bgReadingsAccessor.last(forSensor: nil) {
                timeStampLastBgReading = lastReading.timeStamp
            }
            
            /// in case loopdelay > 0, this will be used to share with Loop
            /// - it will contain the full range off per minute readings (in stead of filtered by 5 minutes
            /// - reset to empty array
            loopManager?.glucoseData = [GlucoseData]()
            
            // initialize latest3BgReadings
            var latest3BgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
            
            // iterate through array, elements are ordered by timestamp, first is the youngest, we need to start with the oldest
            for (index, glucose) in glucoseData.enumerated().reversed() {
                
                // we only add new glucose values if 5 minutes - 10 seconds younger than latest already existing reading, or, if it's the latest, it needs to be just younger
                let checktimestamp = Date(timeInterval: 5.0 * 60.0 - 10.0, since: timeStampLastBgReading)
                
                // timestamp of glucose being processed must be higher (ie more recent) than checktimestamp except if it's the last one (ie the first in the array), because there we don't care if it's less than 5 minutes different with the last but one
                if (glucose.timeStamp > checktimestamp || ((index == 0) && (glucose.timeStamp > timeStampLastBgReading))) {
                    
                    // check on glucoseLevelRaw > 0 because I've had a case where a faulty sensor was giving negative values
                    if glucose.glucoseLevelRaw > 0 {
                        
                        let newReading = calibrator.createNewBgReading(rawData: glucose.glucoseLevelRaw, timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName: self.getCGMTransmitterDeviceName(for: cgmTransmitter), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                        
                        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                            
                            trace("new reading created, timestamp = %{public}@, calculatedValue = %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, newReading.timeStamp.description(with: .current), newReading.calculatedValue.description.replacingOccurrences(of: ".", with: ","))
                            
                        }
                        
                        // save the newly created bgreading permenantly in coredata
                        coreDataManager.saveChanges()
                        
                        // a new reading was created
                        newReadingCreated = true
                        
                        // set timeStampLastBgReading to new timestamp
                        timeStampLastBgReading = glucose.timeStamp
                        
                        // reset latest3BgReadings
                        latest3BgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
                        
                        if LoopManager.loopDelay() > 0 && abs(Date().timeIntervalSince(timeStampLastCalibrationForActiveSensor)) > LoopManager.loopDelay() + TimeInterval(minutes: 5.5) {
                            loopManager?.glucoseData.insert(GlucoseData(timeStamp: newReading.timeStamp, glucoseLevelRaw: round(newReading.calculatedValue), slopeOrdinal: newReading.slopeOrdinal(), slopeName: newReading.slopeName), at: 0)
                        }
                        
                    } else {
                        
                        trace("reading skipped, rawValue <= 0, looks like a faulty sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                        
                    }
                    
                } else if LoopManager.loopDelay() > 0 && glucose.glucoseLevelRaw > 0 && abs(Date().timeIntervalSince(timeStampLastCalibrationForActiveSensor)) >  LoopManager.loopDelay() + TimeInterval(minutes: 5.5) {
                    
                    // loopdelay > 0, LoopManager will use loopShareGoucoseData
                    // create a reading just to be able to fill up loopShareGoucoseData, to have them per minute
                    
                    let newReading = calibrator.createNewBgReading(rawData: glucose.glucoseLevelRaw, timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName: self.getCGMTransmitterDeviceName(for: cgmTransmitter), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

                    loopManager?.glucoseData.insert(GlucoseData(timeStamp: newReading.timeStamp, glucoseLevelRaw: round(newReading.calculatedValue), slopeOrdinal: newReading.slopeOrdinal(), slopeName: newReading.slopeName), at: 0)
                    
                    // delete the newReading, otherwise it stays in coredata and we would end up with per minute readings
                    coreDataManager.mainManagedObjectContext.delete(newReading)
                    
                }
                
            }
            
            // if a new reading is created, create either initial calibration request or bgreading notification - upload to nightscout and check alerts
            if newReadingCreated {
                
                // only if no webOOPEnabled and overruleIsWebOOPEnabled false : if no two calibration exist yet then create calibration request notification, otherwise a bgreading notification and update labels
                if firstCalibrationForActiveSensor == nil && lastCalibrationForActiveSensor == nil && (!cgmTransmitter.isWebOOPEnabled() && !cgmTransmitter.overruleIsWebOOPEnabled()) {
                    
                    // there must be at least 2 readings
                    let latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                    
                    if latestReadings.count > 1 {

                        trace("calibration : two readings received, no calibrations exists yet and not web oopenabled, request calibation to user", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

                        createInitialCalibrationRequest()
                        
                    }
                    
                } else {
                    
                    // check alerts, create notification, set app badge
                    checkAlertsCreateNotificationAndSetAppBadge()
                    
                    // update all text in  first screen
                    updateLabelsAndChart(overrideApplicationState: false)
                    
                    // update mini-chart
                    updateMiniChart()
                    
                    // update statistics related outlets
                    updateStatistics(animatePieChart: false)
                    
                    // update sensor countdown graphic
                    updateSensorCountdown()
                    
                }
                
                nightScoutUploadManager?.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                healthKitManager?.storeBgReadings()
                
                bgReadingSpeaker?.speakNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                dexcomShareUploadManager?.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                bluetoothPeripheralManager?.sendLatestReading()
                
                watchManager?.processNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                if !UserDefaults.standard.suppressLoopShare {
                    loopManager?.share()
                }

                updateWatchApp()
            }
            
        }
        
    }
    
    /// closes the SnoozeViewController if it is being presented now
    private func closeSnoozeViewController() {
        
        if let presentedViewController = self.presentedViewController {
            
            if let snoozeViewController = presentedViewController as? SnoozeViewController {
                
                snoozeViewController.dismiss(animated: true, completion: nil)
                
            }
        }
        
    }
    
    /// used by observevalue for UserDefaults.KeysCharts
    private func evaluateUserDefaultsChange(keyPathEnumCharts: UserDefaults.KeysCharts) {
        
        // first check keyValueObserverTimeKeeper
        switch keyPathEnumCharts {
        
        case UserDefaults.KeysCharts.chartWidthInHours :
            
            if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnumCharts.rawValue, withMinimumDelayMilliSeconds: 200) {
                return
            }
            
        }
        
        switch keyPathEnumCharts {
        
        case UserDefaults.KeysCharts.chartWidthInHours:
            
            // redraw chart is necessary
            if let glucoseChartManager = glucoseChartManager {
                
                glucoseChartManager.updateChartPoints(endDate: glucoseChartManager.endDate, startDate: glucoseChartManager.endDate.addingTimeInterval(.hours(-UserDefaults.standard.chartWidthInHours)), chartOutlet: chartOutlet, completionHandler: nil)

            }
            
        default:
            break
            
        }
        
    }
    
    /// used by observevalue for UserDefaults.Key
    private func evaluateUserDefaultsChange(keyPathEnum: UserDefaults.Key) {
        
        // first check keyValueObserverTimeKeeper
        switch keyPathEnum {
        
        case UserDefaults.Key.isMaster, UserDefaults.Key.multipleAppBadgeValueWith10, UserDefaults.Key.showReadingInAppBadge, UserDefaults.Key.bloodGlucoseUnitIsMgDl, UserDefaults.Key.daysToUseStatistics, UserDefaults.Key.showMiniChart :
            
            // transmittertype change triggered by user, should not be done within 200 ms
            if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                return
            }
            
        default:
            break
            
        }
        
        switch keyPathEnum {
        
        case UserDefaults.Key.isMaster :
            
            changeButtonsStatusTo(enabled: UserDefaults.standard.isMaster)
            
            guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() else {break}
            
            // no sensor needed in follower mode, stop it
            stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
            
        case UserDefaults.Key.showReadingInNotification:
            if !UserDefaults.standard.showReadingInNotification {
                // remove existing notification if any
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest])
                
            }
            
        case UserDefaults.Key.multipleAppBadgeValueWith10, UserDefaults.Key.showReadingInAppBadge, UserDefaults.Key.bloodGlucoseUnitIsMgDl:
            
            // if showReadingInAppBadge = false, means user set it from true to false
            // set applicationIconBadgeNumber to 0. This will cause removal of the badge counter, but als removal of any existing notification on the screen
            if !UserDefaults.standard.showReadingInAppBadge {
                
                UIApplication.shared.applicationIconBadgeNumber = 0
                
            }
            
            // also update Watch App with the new values. (Only really needed for unit change between mg/dl and mmol/l)
            updateWatchApp()
            
            // this will trigger update of app badge, will also create notification, but as app is most likely in foreground, this won't show up
            createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
            
        case UserDefaults.Key.urgentLowMarkValue, UserDefaults.Key.lowMarkValue, UserDefaults.Key.highMarkValue, UserDefaults.Key.urgentHighMarkValue, UserDefaults.Key.nightScoutTreatmentsUpdateCounter:
            
            // redraw chart is necessary
            updateChartWithResetEndDate()
            
            // redraw mini-chart
            updateMiniChart()
            
            // update Watch App with the new objective values
            updateWatchApp()
            
        case UserDefaults.Key.showMiniChart:
            
            // show/hide mini-chart view as required
            miniChartOutlet.isHidden = !UserDefaults.standard.showMiniChart
            
        case UserDefaults.Key.miniChartHoursToShow:
            
            // redraw mini-chart
            updateMiniChart()

        case UserDefaults.Key.daysToUseStatistics:
            
            // refresh statistics calculations/view is necessary
            updateStatistics(animatePieChart: true, overrideApplicationState: false)
            
        case UserDefaults.Key.showClockWhenScreenIsLocked:
            
            // refresh screenLock function if it is currently activated in order to show/hide the clock as requested
            if screenIsLocked {
                screenLockUpdate(enabled: true)
            }
            
        case UserDefaults.Key.stopActiveSensor:
            
            // if stopActiveSensor wasn't changed to true then no further processing
            if UserDefaults.standard.stopActiveSensor {
                
                sensorStopDetected()
                
                updateSensorCountdown()
                
                UserDefaults.standard.stopActiveSensor = false
                
            }

        default:
            break
            
        }
    }
    
    override func willTransition(
        to newCollection: UITraitCollection,
        with coordinator: UIViewControllerTransitionCoordinator) {
      super.willTransition(to: newCollection, with: coordinator)
      
      switch newCollection.verticalSizeClass {
      case .compact:
        showLandscape(with: coordinator)
      case .regular, .unspecified:
        hideLandscape(with: coordinator)
      @unknown default:
        fatalError()
      }
    }

    
    // MARK:- observe function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {return}
        
        if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
            
            evaluateUserDefaultsChange(keyPathEnum: keyPathEnum)
            
        } else if let keyPathEnumCharts = UserDefaults.KeysCharts(rawValue: keyPath) {
            
            evaluateUserDefaultsChange(keyPathEnumCharts: keyPathEnumCharts)
            
        }
        
    }
    
    // MARK: - View Methods
    
    /// Configure View, only stuff that is independent of coredata
    private func setupView() {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        	
        // set texts for buttons on top
        preSnoozeToolbarButtonOutlet.title = Texts_HomeView.snoozeButton
        sensorToolbarButtonOutlet.title = Texts_HomeView.sensor
        calibrateToolbarButtonOutlet.title = Texts_HomeView.calibrationButton
        screenLockToolbarButtonOutlet.title = screenIsLocked ? Texts_HomeView.unlockButton : Texts_HomeView.lockButton
        
        chartLongPressGestureRecognizerOutlet.delegate = self
        chartPanGestureRecognizerOutlet.delegate = self
        
        // at this moment, coreDataManager is not yet initialized, we're just calling here prerender and reloadChart to show the chart with x and y axis and gridlines, but without readings. The readings will be loaded once coreDataManager is setup, after which updateChart() will be called, which will initiate loading of readings from coredata
        self.chartOutlet.reloadChart()
        
        self.miniChartOutlet.reloadChart()
        
    }
    
    // MARK: - private helper functions
    
    /// configures the WKSession used for communication between the app and the watch app if available
    private func configureWatchKitSession() {
        
        if WCSession.isSupported() {
            
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            
        }
    }
    
    /// creates notification
    private func createNotification(title: String?, body: String?, identifier: String, sound: UNNotificationSound?) {
        
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NotificationContent title
        if let title = title {
            notificationContent.title = title
        }
        
        // Configure NotificationContent body
        if let body = body {
            notificationContent.body = body
        }
        
        // configure sound
        if let sound = sound {
            notificationContent.sound = sound
        }
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                trace("Unable to create notification %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            }
        }
        
    }
    
    /// will update the chart with endDate = currentDate
    private func updateChartWithResetEndDate() {
        
        glucoseChartManager?.updateChartPoints(endDate: Date(), startDate: nil, chartOutlet: chartOutlet, completionHandler: nil)
        
    }
    
    /// launches timer that will do regular screen updates - and adds closure to ApplicationManager : when going to background, stop the timer, when coming to foreground, restart the timer
    ///
    /// should be called only once immediately after app start, ie in viewdidload
    private func setupUpdateLabelsAndChartTimer() {
        
        // set timeStampAppLaunch to now
        UserDefaults.standard.timeStampAppLaunch = Date()
        
        // this is the actual timer
        var updateLabelsAndChartTimer:Timer?
        
        // create closure to invalide the timer, if it exists
        let invalidateUpdateLabelsAndChartTimer = {
            
            if let updateLabelsAndChartTimer = updateLabelsAndChartTimer {
                
                updateLabelsAndChartTimer.invalidate()
                
            }
            
            updateLabelsAndChartTimer = nil
            
        }
        
        // create closure that launches the timer to update the first view every x seconds, and returns the created timer
        let createAndScheduleUpdateLabelsAndChartTimer:() -> Timer = {
            // check if timer already exists, if so invalidate it
            invalidateUpdateLabelsAndChartTimer()
            // now recreate, schedule and return
            return Timer.scheduledTimer(timeInterval: ConstantsHomeView.updateHomeViewIntervalInSeconds, target: self, selector: #selector(self.updateLabelsAndChart), userInfo: nil, repeats: true)
        }
        
        // call scheduleUpdateLabelsAndChartTimer function now - as the function setupUpdateLabelsAndChartTimer is called from viewdidload, it will be called immediately after app launch
        updateLabelsAndChartTimer = createAndScheduleUpdateLabelsAndChartTimer()
        
        // updateLabelsAndChartTimer needs to be created when app comes back from background to foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyCreateupdateLabelsAndChartTimer, closure: {updateLabelsAndChartTimer = createAndScheduleUpdateLabelsAndChartTimer()})
        
        // when app goes to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyInvalidateupdateLabelsAndChartTimerAndCloseSnoozeViewController, closure: {
            
            // this is for the case that the snoozeViewController is shown. If not removed, then if user opens alert notification, the alert snooze wouldn't be shown
            // that's why, close the snoozeViewController
            self.closeSnoozeViewController()
            
            // updateLabelsAndChartTimer needs to be invalidated when app goes to background
            invalidateUpdateLabelsAndChartTimer()
            
        })
        
    }
    
    /// opens an alert, that requests user to enter a calibration value, and calibrates
    /// - parameters:
    ///     - userRequested : if true, it's a requestCalibration initiated by user clicking on the calibrate button in the homescreen
    private func requestCalibration(userRequested:Bool) {
        
        // unwrap calibrationsAccessor, coreDataManager , bgReadingsAccessor
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = self.coreDataManager, let bgReadingsAccessor = self.bgReadingsAccessor else {
            
            trace("in requestCalibration, calibrationsAccessor or coreDataManager or bgReadingsAccessor is nil, no further processing", log: log, category: ConstantsLog.categoryRootView, type: .error)
            
            return
            
        }
        
        // check that there's an active cgmTransmitter (not necessarily connected, just one that is created and configured with shouldconnect = true)
        guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter else {
            
            trace("in requestCalibration, calibrationsAccessor or cgmTransmitter is nil, no further processing", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            self.present(UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.theresNoCGMTransmitterActive, actionHandler: nil), animated: true, completion: nil)
            
            return
        }
        
        // check if sensor active and if not don't continue
        guard let activeSensor = activeSensor else {
            
            trace("in requestCalibration, there is no active sensor, no further processing", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            self.present(UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.startSensorBeforeCalibration, actionHandler: nil), animated: true, completion: nil)
            
            return
            
        }
        
        // if it's a user requested calibration, but there's no calibration yet, then give info and return - first calibration will be requested by app via notification
        // cgmTransmitter.overruleIsWebOOPEnabled() : that means it's a transmitter that gives calibrated values (ie doesn't need to be calibrated) but it can use calibration
        if calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) == nil && userRequested && !cgmTransmitter.overruleIsWebOOPEnabled() {
            
            self.present(UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.thereMustBeAreadingBeforeCalibration, actionHandler: nil), animated: true, completion: nil)
            
            return
        }
        
        // assign deviceName, needed in the closure when creating alert. As closures can create strong references (to bluetoothTransmitter in this case), I'm fetching the deviceName here
        let deviceName = bluetoothTransmitter.deviceName
        
        let alert = UIAlertController(title: Texts_Calibrations.enterCalibrationValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: nil, placeHolder: "...", actionTitle: nil, cancelTitle: nil, actionHandler: {
            (text:String) in
            
            guard let valueAsDouble = text.toDouble() else {
                self.present(UIAlertController(title: Texts_Common.warning, message: Texts_Common.invalidValue, actionHandler: nil), animated: true, completion: nil)
                return
            }
            
            // store the calibration value entered by the user into the log
            trace("calibration : value %{public}@ entered by user", log: self.log, category: ConstantsLog.categoryRootView, type: .info, text.description)
            
            let valueAsDoubleConvertedToMgDl = valueAsDouble.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
            var latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
            
            var latestCalibrations = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
            
            if let calibrator = self.calibrator {
                
                if latestCalibrations.count == 0 {
                    
                    trace("calibration : initial calibration, creating two calibrations", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                    
                    // calling initialCalibration will create two calibrations, they are returned also but we don't need them
                    let (calibration, _) = calibrator.initialCalibration(firstCalibrationBgValue: valueAsDoubleConvertedToMgDl, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDoubleConvertedToMgDl, sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, deviceName: deviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                    
                    // send calibration to transmitter (only used for Dexcom, if firefly flow is used)
                    if let calibration = calibration {
                        
                        cgmTransmitter.calibrate(calibration: calibration)
                        
                        // presnooze fastrise and fastdrop alert
                        self.alertManager?.snooze(alertKind: .fastdrop, snoozePeriodInMinutes: 9, response: nil)
                        
                        self.alertManager?.snooze(alertKind: .fastrise, snoozePeriodInMinutes: 9, response: nil)

                    }
                    
                    
                } else {
                    
                    // it's not the first calibration
                    if let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) {

                        trace("calibration : creating calibration", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                        
                        // create new calibration
                        if let calibration = calibrator.createNewCalibration(bgValue: valueAsDoubleConvertedToMgDl, lastBgReading: latestReadings.count > 0 ? latestReadings[0] : nil, sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, deviceName: deviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext) {

                            // send calibration to transmitter (only used for Dexcom, if firefly flow is used)
                            cgmTransmitter.calibrate(calibration: calibration)
                            
                            // presnooze fastrise and fastdrop alert
                            self.alertManager?.snooze(alertKind: .fastdrop, snoozePeriodInMinutes: 9, response: nil)
                            
                            self.alertManager?.snooze(alertKind: .fastrise, snoozePeriodInMinutes: 9, response: nil)

                        }
                        
                    }
                    
                }
                
                // this will store the newly created calibration(s) in coredata
                coreDataManager.saveChanges()
                
                // initiate upload to NightScout, if needed
                if let nightScoutUploadManager = self.nightScoutUploadManager {
                    nightScoutUploadManager.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
                }
                
                // initiate upload to Dexcom Share, if needed
                if let dexcomShareUploadManager = self.dexcomShareUploadManager {
                    dexcomShareUploadManager.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
                }
                
                // update labels
                self.updateLabelsAndChart(overrideApplicationState: false)
                
                // bluetoothPeripherals (M5Stack, ..) should receive latest reading with calculated value
                self.bluetoothPeripheralManager?.sendLatestReading()
                
                // watchManager should process new reading
                self.watchManager?.processNewReading(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
                
                // send also to loopmanager, not interesting for loop probably, but the data is also used for today widget
                if !UserDefaults.standard.suppressLoopShare {
                    self.loopManager?.share()
                }

                
            }
            
        }, cancelHandler: nil)
        
        // present the alert
        self.present(alert, animated: true, completion: nil)
        
    }
    
    /// this is just some functionality which is used frequently
    private func getCalibrator(cgmTransmitter: CGMTransmitter) -> Calibrator {
        
        let cgmTransmitterType = cgmTransmitter.cgmTransmitterType()
        
        // initialize return value
        var calibrator: Calibrator = NoCalibrator()
        
        switch cgmTransmitterType {
        
        case .dexcomG4:
            
            calibrator = DexcomCalibrator()
            
        case .dexcom:
            
            if cgmTransmitter.isWebOOPEnabled() {
                
                // received values are already calibrated
                calibrator = NoCalibrator()
                
            } else if cgmTransmitter.isNonFixedSlopeEnabled() {
                
                // no oop web, fixed slope
                // should not occur, because Dexcom should have nonFixedSlopeEnabled false
                //  if true for dexcom, then someone has set this to true but didn't create a non-fixed slope calibrator
                fatalError("cgmTransmitter.isNonFixedSlopeEnabled returns true for dexcom but there's no NonFixedSlopeCalibrator for Dexcom")
                
            } else {
                
                // no oop web, no fixed slope
                
                calibrator = DexcomCalibrator()
                
            }

            
        case .miaomiao, .GNSentry, .Blucon, .Bubble, .Droplet1, .blueReader, .watlaa, .Libre2, .Atom:
            
            if cgmTransmitter.isWebOOPEnabled() {
                
                // received values are already calibrated
                calibrator = NoCalibrator()
                
            } else if cgmTransmitter.isNonFixedSlopeEnabled() {
                
                // no oop web, non-fixed slope
                
                return Libre1NonFixedSlopeCalibrator()
                
            } else {
                
                // no oop web, fixed slope
                
                calibrator = Libre1Calibrator()
                
            }
            
        }
        
        trace("in getCalibrator, calibrator = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, calibrator.description())
        
        return calibrator
        
    }
    
    /// for debug purposes
    private func logAllBgReadings() {
        if let bgReadingsAccessor = bgReadingsAccessor {
            let readings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: nil, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: true)
            for (index,reading) in readings.enumerated() {
                if reading.sensor?.id == activeSensor?.id {
                    trace("readings %{public}d timestamp = %{public}@, calculatedValue = %{public}f", log: log, category: ConstantsLog.categoryRootView, type: .info, index, reading.timeStamp.description, reading.calculatedValue)
                }
            }
        }
    }
    
    /// creates initial calibration request notification
    private func createInitialCalibrationRequest() {
        
        // first remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest])
        
        createNotification(title: Texts_Calibrations.calibrationNotificationRequestTitle, body: Texts_Calibrations.calibrationNotificationRequestBody, identifier: ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest, sound: UNNotificationSound(named: UNNotificationSoundName("")))
        
        // we will not just count on it that the user will click the notification to open the app (assuming the app is in the background, if the app is in the foreground, then we come in another flow)
        // whenever app comes from-back to foreground, requestCalibration needs to be called
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyInitialCalibration, closure: {
            
            // first of all reremove from application key manager
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeyInitialCalibration)
            
            // remove existing notification if any
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest])
            
            // request the calibration
            self.requestCalibration(userRequested: false)
            
        })
        
    }
    
    /// creates bgreading notification, and set app badge to value of reading
    /// - parameters:
    ///     - if overrideShowReadingInNotification then badge counter will be set (if enabled off course) with function UIApplication.shared.applicationIconBadgeNumber. To be used if badge counter is  to be set eg when UserDefaults.standard.showReadingInAppBadge is changed
    private func createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: Bool) {
        
        // bgReadingsAccessor should not be nil at all, but let's not create a fatal error for that, there's already enough checks for it
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            return
        }
        
        // get lastReading, with a calculatedValue - no check on activeSensor because in follower mode there is no active sensor
        let lastReading = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        // if there's no reading for active sensor with calculated value , then no reason to continue
        if lastReading.count == 0 {
            
            trace("in createBgReadingNotificationAndSetAppBadge, lastReading.count = 0", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            // remove the application badge number. Possibly an old reading is still shown.
            UIApplication.shared.applicationIconBadgeNumber = 0
            
            return
        }
        
        // if reading is older than 4.5 minutes, then also no reason to continue - this may happen eg in case of follower mode
        if Date().timeIntervalSince(lastReading[0].timeStamp) > 4.5 * 60 {
            
            trace("in createBgReadingNotificationAndSetAppBadge, timestamp of last reading > 4.5 * 60", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            // remove the application badge number. Possibly the previous value is still shown
            UIApplication.shared.applicationIconBadgeNumber = 0
            
            return
        }
        
        // remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest])
        
        // also remove the sensor not detected notification, if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected])
        
        // prepare value for badge
        var readingValueForBadge = lastReading[0].calculatedValue
        // values lower dan 12 are special values, don't show anything
        guard readingValueForBadge > 12 else {return}
        // high limit to 400
        if readingValueForBadge >= 400.0 {readingValueForBadge = 400.0}
        // low limit ti 40
        if readingValueForBadge <= 40.0 {readingValueForBadge = 40.0}
        
        // check if notification on home screen is enabled in the settings
        // and also if last notification was long enough ago (longer than UserDefaults.standard.notificationInterval), except if there would have been a disconnect since previous notification (simply because I like getting a new reading with a notification by disabling/reenabling bluetooth
        if UserDefaults.standard.showReadingInNotification && !overrideShowReadingInNotification && (abs(timeStampLastBGNotification.timeIntervalSince(Date())) > Double(UserDefaults.standard.notificationInterval) * 60.0 || lastConnectionStatusChangeTimeStamp().timeIntervalSince(timeStampLastBGNotification) > 0) {
            
            // Create Notification Content
            let notificationContent = UNMutableNotificationContent()
            
            // set value in badge if required
            if UserDefaults.standard.showReadingInAppBadge {
                
                // rescale if unit is mmol
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                    readingValueForBadge = readingValueForBadge.mgdlToMmol().round(toDecimalPlaces: 1)
                } else {
                    readingValueForBadge = readingValueForBadge.round(toDecimalPlaces: 0)
                }
                
                notificationContent.badge = NSNumber(value: readingValueForBadge.rawValue)
                
            }
            
            // Configure notificationContent title, which is bg value in correct unit, add also slopeArrow if !hideSlope and finally the difference with previous reading, if there is one
            var calculatedValueAsString = lastReading[0].unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            if !lastReading[0].hideSlope {
                calculatedValueAsString = calculatedValueAsString + " " + lastReading[0].slopeArrow()
            }
            if lastReading.count > 1 {
                calculatedValueAsString = calculatedValueAsString + "      " + lastReading[0].unitizedDeltaString(previousBgReading: lastReading[1], showUnit: true, highGranularity: true, mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            }
            notificationContent.title = calculatedValueAsString
            
            // must set a body otherwise notification doesn't show up on iOS10
            notificationContent.body = " "
            
            // Create Notification Request
            let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest, content: notificationContent, trigger: nil)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    trace("Unable to Add bg reading Notification Request %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
                }
            }
            
            // set timeStampLastBGNotification to now
            timeStampLastBGNotification = Date()
        }
        else {
            
            // notification shouldn't be shown, but maybe the badge counter. Here the badge value needs to be shown in another way
            
            if UserDefaults.standard.showReadingInAppBadge {
                
                // rescale of unit is mmol
                readingValueForBadge = readingValueForBadge.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                
                // if unit is mmol and if value needs to be multiplied by 10, then multiply by 10
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl && UserDefaults.standard.multipleAppBadgeValueWith10 {
                    readingValueForBadge = readingValueForBadge * 10.0
                }
                
                UIApplication.shared.applicationIconBadgeNumber = Int(round(readingValueForBadge))
                
            }
        }
        
    }
    
    /// - updates the labels and the chart,
    /// - but only if the chart is not panned backward
    /// - and if app is in foreground
    /// - and if overrideApplicationState = false
    /// - parameters:
    ///     - overrideApplicationState : if true, then update will be done even if state is not .active
    ///     - forceReset : if true, then force the update to be done even if the main chart is panned back in time (used for the double tap gesture)
    @objc private func updateLabelsAndChart(overrideApplicationState: Bool = false, forceReset: Bool = false) {
        
        UserDefaults.standard.nightScoutSyncTreatmentsRequired = true
        
        // if glucoseChartManager not nil, then check if panned backward and if so then don't update the chart
        if let glucoseChartManager = glucoseChartManager  {
            // check that app is in foreground, but only if overrideApplicationState = false
            // if we are not forcing to reset even if the chart is currently panned back in time (such as by double-tapping the main chart, then check if it is panned back in that case we don't update the labels
            if !forceReset {
                guard !glucoseChartManager.chartIsPannedBackward else {return}
            }
        }
        
        guard UIApplication.shared.applicationState == .active || overrideApplicationState else {return}
        
        // check that bgReadingsAccessor exists, otherwise return - this happens if updateLabelsAndChart is called from viewDidload at app launch
        guard let bgReadingsAccessor = bgReadingsAccessor else {return}
        
        // to make the following code a bit more readable
        let mgdl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // set minutesLabelOutlet.textColor to white, might still be red due to panning back in time
        self.minutesLabelOutlet.textColor = UIColor.white
        
        // get latest reading, doesn't matter if it's for an active sensor or not, but it needs to have calculatedValue > 0 / which means, if user would have started a new sensor, but didn't calibrate yet, and a reading is received, then there's not going to be a latestReading
        let latestReadings = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        // if there's no readings, then give empty fields and make sure the text isn't styled with strikethrough
        guard latestReadings.count > 0 else {
            
            valueLabelOutlet.textColor = UIColor.darkGray
            minutesLabelOutlet.text = ""
            minutesAgoLabelOutlet.text = ""
            diffLabelOutlet.text = ""
            diffLabelUnitOutlet.text = ""
                
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: "---")
            attributeString.addAttribute(.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
            return
        }
        
        // assign last reading
        let lastReading = latestReadings[0]
        
        // assign last but one reading
        let lastButOneReading = latestReadings.count > 1 ? latestReadings[1] : nil
        
        // start creating text for valueLabelOutlet, first the calculated value
        var calculatedValueAsString = lastReading.unitizedString(unitIsMgDl: mgdl)
        
        // if latestReading is older than 11 minutes, then it should be strikethrough
        if lastReading.timeStamp < Date(timeIntervalSinceNow: -60.0 * 11) {
            
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        } else {
            
            if !lastReading.hideSlope {
                calculatedValueAsString = calculatedValueAsString + " " + lastReading.slopeArrow()
            }
            
            // no strikethrough needed, but attributedText may still be set to strikethrough from previous period during which there was no recent reading.
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        }
        
        // if data is stale (over 11 minutes old), show it as gray colour to indicate that it isn't current
        // if not, then set color, depending on value lower than low mark or higher than high mark
        // set both HIGH and LOW BG values to red as previous yellow for hig is now not so obvious due to in-range colour of green.
        if lastReading.timeStamp < Date(timeIntervalSinceNow: -60 * 11) {
            
            valueLabelOutlet.textColor = UIColor.lightGray
            
        } else if lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) >= UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) || lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) <= UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) {
            
            // BG is higher than urgentHigh or lower than urgentLow objectives
            valueLabelOutlet.textColor = UIColor.red
            
        } else if lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) >= UserDefaults.standard.highMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) || lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) <= UserDefaults.standard.lowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) {
            
            // BG is between urgentHigh/high and low/urgentLow objectives
            valueLabelOutlet.textColor = UIColor.yellow
            
        } else {
            
            // BG is between high and low objectives so considered "in range"
            valueLabelOutlet.textColor = UIColor.green
        }
        
        // get minutes ago and create value text for minutes ago label
        let minutesAgo = -Int(lastReading.timeStamp.timeIntervalSinceNow) / 60
        let minutesAgoText = minutesAgo.description
        minutesLabelOutlet.text = minutesAgoText
        
        // configure the localized text in the "mins ago" label
        let minutesAgoMinAgoText = (minutesAgo == 1 ? Texts_Common.minute : Texts_Common.minutes) + " " + Texts_HomeView.ago
        minutesAgoLabelOutlet.text = minutesAgoMinAgoText
        
        // create delta value text (without the units)
        let diffLabelText = lastReading.unitizedDeltaString(previousBgReading: lastButOneReading, showUnit: false, highGranularity: true, mgdl: mgdl)
        diffLabelOutlet.text = diffLabelText
        
        // set the delta unit label text
        let diffLabelUnitText = mgdl ? Texts_Common.mgdl : Texts_Common.mmol
        diffLabelUnitOutlet.text = diffLabelUnitText
        
        // update the chart up to now
        updateChartWithResetEndDate()
        
        self.updateMiniChart()
        
    }
    
    /// if the user has chosen to show the mini-chart, then update it. If not, just return without doing anything.
    private func updateMiniChart() {
        
        if UserDefaults.standard.showMiniChart {
            
            switch UserDefaults.standard.miniChartHoursToShow {
                
            case ConstantsGlucoseChart.miniChartHoursToShow1:
                miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow).description + " " + Texts_Common.hours
                
            case ConstantsGlucoseChart.miniChartHoursToShow2, ConstantsGlucoseChart.miniChartHoursToShow3, ConstantsGlucoseChart.miniChartHoursToShow4:
                miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow / 24).description + " " + Texts_Common.days
                
            default:
                miniChartHoursLabelOutlet.text = Int(UserDefaults.standard.miniChartHoursToShow).description + " " + Texts_Common.hours
                
            }
            
            // update the chart
            glucoseMiniChartManager?.updateChartPoints(chartOutlet: miniChartOutlet, completionHandler: nil)
            
        }
        
    }
    
    /// when user clicks transmitter button, this will create and present the actionsheet, contents depend on type of transmitter and sensor status
    private func createAndPresentSensorButtonActionSheet() {
        
        // unwrap coredatamanager
        guard let coreDataManager = coreDataManager else {return}
        
        // initialize list of actions
        var listOfActions = [UIAlertAction]()
        
        // first action is to show the status
        let sensorStatusAction = UIAlertAction(title: Texts_HomeView.statusActionTitle, style: .default) { (UIAlertAction) in
            self.showStatus()
        }
        
        listOfActions.append(sensorStatusAction)
        
        // next action is to start or stop the sensor, can also be omitted depending on type of device - also not applicable for follower mode
        if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() {
            if cgmTransmitter.cgmTransmitterType().allowManualSensorStart() && UserDefaults.standard.isMaster {
                
                // user can (or needs to) start and stop the sensor
                var startStopAction: UIAlertAction
                
                if activeSensor != nil {
                    startStopAction = UIAlertAction(title: Texts_HomeView.stopSensorActionTitle, style: .default) { (UIAlertAction) in
                        
                        // first ask user confirmation
                        let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.stopSensorConfirmation, actionHandler: {
                            
                            trace("in createAndPresentSensorButtonActionSheet, user clicked stop sensor, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                            
                            self.stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: true)
                            
                        }, cancelHandler: nil)
                        
                        self.present(alert, animated: true, completion: nil)
                        
                    }
                } else {
                    startStopAction = UIAlertAction(title: Texts_HomeView.startSensorActionTitle, style: .default) { (UIAlertAction) in

                        // either sensor needs a sensor start time, or a sensor code .. or none
                        if cgmTransmitter.needsSensorStartTime() {

                            self.startSensorAskUserForStarttime(cGMTransmitter: cgmTransmitter)

                        } else if cgmTransmitter.needsSensorStartCode() {
                            
                            self.startSensorAskUserForSensorCode(cGMTransmitter: cgmTransmitter)
                            
                        } else {
                            
                            self.startSensor(cGMTransmitter: cgmTransmitter, sensorStarDate: Date(), sensorCode: nil, coreDataManager: coreDataManager, sendToTransmitter: true)
                            
                        }
                        
                        
                    }
                }
                
                listOfActions.append(startStopAction)
            }
        }

        let cancelAction = UIAlertAction(title: Texts_Common.Cancel, style: .cancel, handler: nil)
        listOfActions.append(cancelAction)
        
        // create and present new alertController of type actionsheet
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for action in listOfActions {
            actionSheet.addAction(action)
        }
        
        // following is required for iPad, as explained here https://stackoverflow.com/questions/28089898/actionsheet-not-working-ipad
        // otherwise it crashes on iPad when clicking transmitter button
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        self.present(actionSheet, animated: true)
    }
    
    private func appendEndDateInformation(_ activeSensor: Sensor, _ textToShow: String) -> String {
        var result = "\r\n\r\n" + Texts_HomeView.sensorEnd + ":\n"
        if activeSensor.endDate != nil {
            result += (activeSensor.endDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .short, showTimeZone: true))!
            result += "\r\n\r\n" + Texts_HomeView.sensorRemaining + ":\n"
            result += (activeSensor.endDate?.daysAndHoursAgo())!
        }
        else if UserDefaults.standard.maxSensorAgeInDays > 0 {
            result += activeSensor.startDate.addingTimeInterval(TimeInterval(hours: Double(UserDefaults.standard.maxSensorAgeInDays * 24))).toStringInUserLocale(timeStyle: .short, dateStyle: .short, showTimeZone: true)
            result += "\r\n\r\n" + Texts_HomeView.sensorRemaining + ":\n"
            result += "-" + activeSensor.startDate.addingTimeInterval(TimeInterval(hours: Double(UserDefaults.standard.maxSensorAgeInDays * 24))).daysAndHoursAgo()
        }
        else { //No end date information could be retrieved, return nothing
            return ""
        }
            
        return result
    }
    
    /// will show the status
    private func showStatus() {
        
        // first sensor status
        var textToShow = "\n" + Texts_HomeView.sensorStart + ":\n"
        if let activeSensor = activeSensor {
            textToShow += activeSensor.startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short, showTimeZone: true)
            textToShow += "\n\n" + Texts_HomeView.sensorDuration + ":\n"
            textToShow += activeSensor.startDate.daysAndHoursAgo()
            textToShow += appendEndDateInformation(activeSensor, textToShow)
        } else {
            textToShow += Texts_HomeView.notStarted
        }
        
        // add 2 newlines
        textToShow += "\r\n\r\n"
        
        // add transmitterBatteryInfo if known
        if let transmitterBatteryInfo = UserDefaults.standard.transmitterBatteryInfo {
            textToShow += Texts_HomeView.transmitterBatteryLevel + ":\n" + transmitterBatteryInfo.description
            // add 1 newline with last connection timestamp
            textToShow += "\r\n\r\n"
        }
        
        // display textoToshow
        let alert = UIAlertController(title: Texts_HomeView.statusActionTitle, message: textToShow, actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    /// start a new sensor, ask user for starttime
    /// - parameters:
    ///     - cGMTransmitter is required because startSensor command will be sent also to the transmitter
    private func startSensorAskUserForStarttime(cGMTransmitter: CGMTransmitter) {
        
        // craete datePickerViewData
        let datePickerViewData = DatePickerViewData(withMainTitle: Texts_HomeView.startSensorActionTitle, withSubTitle: nil, datePickerMode: .dateAndTime, date: Date(), minimumDate: nil, maximumDate: Date(), okButtonText: Texts_Common.Ok, cancelButtonText: Texts_Common.Cancel, onOkClick: {(date) in
            if let coreDataManager = self.coreDataManager, let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() {
                
                // start sensor with date chosen by user, sensorCode nil
                self.startSensor(cGMTransmitter: cgmTransmitter, sensorStarDate: date, sensorCode: nil, coreDataManager: coreDataManager, sendToTransmitter: true)
                
            }
        }, onCancelClick: nil)
        
        // if this is the first time user starts a sensor, give warning that time should be correct
        // if not the first them, then immediately open the timePickAlertController
        if (!UserDefaults.standard.startSensorTimeInfoGiven) {
            let alert = UIAlertController(title: Texts_HomeView.startSensorActionTitle, message: Texts_HomeView.startSensorTimeInfo, actionHandler: {
                
                // create and present pickerviewcontroller
                DatePickerViewController.displayDatePickerViewController(datePickerViewData: datePickerViewData, parentController: self)
                
                // no need to display sensor start time info next sensor start
                UserDefaults.standard.startSensorTimeInfoGiven = true
                
            })
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
            DatePickerViewController.displayDatePickerViewController(datePickerViewData: datePickerViewData, parentController: self)
        }
        
    }

    /// start a new sensor, ask user for sensor code
    /// - parameters:
    ///     - cGMTransmitter is required because startSensor command will be sent also to the transmitter
    private func startSensorAskUserForSensorCode(cGMTransmitter: CGMTransmitter) {
        
        let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.enterSensorCode, keyboardType:.numberPad, text: nil, placeHolder: "0000", actionTitle: nil, cancelTitle: nil, actionHandler: {
            (text:String) in
            
            if let coreDataManager = self.coreDataManager, let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() {
                
                // start sensor with date chosen by user, sensorCode nil
                self.startSensor(cGMTransmitter: cgmTransmitter, sensorStarDate: Date(), sensorCode: text, coreDataManager: coreDataManager, sendToTransmitter: true)
                
            }
            
        }, cancelHandler: nil)

        self.present(alert, animated: true, completion: nil)
        
    }
    
    private func valueLabelLongPressed(_ sender: UILongPressGestureRecognizer) {
        
        if sender.state == .began {

            // call the UIAlert but assume that the user wants a simple screen lock, not the full lock mode
            screenLockAlert(overrideScreenIsLocked: true, showClock: false)
            
        }
        
    }
    
    private func getCGMTransmitterDeviceName(for cgmTransmitter: CGMTransmitter) -> String? {
        
        if let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter {
            return bluetoothTransmitter.deviceName
        }
        
        return nil
        
    }
    
    /// enables or disables the buttons on top of the screen
    private func changeButtonsStatusTo(enabled: Bool) {
        
        if enabled {
            sensorToolbarButtonOutlet.enable()
            calibrateToolbarButtonOutlet.enable()
        } else {
            sensorToolbarButtonOutlet.disable()
            calibrateToolbarButtonOutlet.disable()
        }
        
    }
    
    /// call alertManager.checkAlerts, and calls createBgReadingNotificationAndSetAppBadge with overrideShowReadingInNotification true or false, depending if immediate notification was created or not
    private func checkAlertsCreateNotificationAndSetAppBadge() {
        
        // unwrap alerts and check alerts
        if let alertManager = alertManager {
            
            // check if an immediate alert went off that shows the current reading
            if alertManager.checkAlerts(maxAgeOfLastBgReadingInSeconds: ConstantsFollower.maximumBgReadingAgeForAlertsInSeconds) {
                
                // an immediate alert went off that shows the current reading
                
                // possibily the app is in the foreground now
                // if user would have opened SnoozeViewController now, then close it, otherwise the alarm picker view will not be shown
                closeSnoozeViewController()
                
                // only update badge is required, (if enabled offcourse)
                createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
                
            } else {
                
                // update notification and app badge
                createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: false)
                
            }
            
        }
        
    }
    
    // a long function just to get the timestamp of the last disconnect or reconnect. If not known then returns 1 1 1970
    private func lastConnectionStatusChangeTimeStamp() -> Date  {
        
        // this is actually unwrapping of optionals, goal is to get date of last disconnect/reconnect - all optionals should exist so it doesn't matter what is returned true or false
        guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter, let bluetoothPeripheral = self.bluetoothPeripheralManager?.getBluetoothPeripheral(for: bluetoothTransmitter), let lastConnectionStatusChangeTimeStamp = bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp else {return Date(timeIntervalSince1970: 0)}
        
        return lastConnectionStatusChangeTimeStamp
        
    }
    
    
    // helper function to calculate the statistics and update the pie chart and label outlets
    private func updateStatistics(animatePieChart: Bool = false, overrideApplicationState: Bool = false) {
        
        // don't calculate statis if app is not running in the foreground
        guard UIApplication.shared.applicationState == .active || overrideApplicationState else {return}
        
        // if the user doesn't want to see the statistics, then just return without doing anything
        if !UserDefaults.standard.showStatistics {
            return
        }
        
        // declare constants/variables
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        var daysToUseStatistics: Int = 0
        var fromDate: Date = Date()
        
        // get the maximum number of calculation days requested by the user
        daysToUseStatistics = UserDefaults.standard.daysToUseStatistics
        
        // if the user has selected 0 (to chose "today") then set the fromDate to the previous midnight
        if daysToUseStatistics == 0 {
            fromDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
        } else {
            fromDate = Date(timeIntervalSinceNow: -3600.0 * 24.0 * Double(daysToUseStatistics))
        }
        
        
        // let's clean up statistics UI before calling the Statistics Manager
        // we'll also show the activity monitor and change the statistics label colors to gray
        if self.averageStatisticLabelOutlet.text == "-" {
            self.activityMonitorOutlet.isHidden = true
        } else {
            self.activityMonitorOutlet.isHidden = false
        }
        
        self.pieChartOutlet.clear()
        self.pieChartLabelOutlet.text = ""
        
        self.lowStatisticLabelOutlet.textColor = UIColor.lightGray
        self.lowStatisticLabelOutlet.text = "-"
        self.inRangeStatisticLabelOutlet.textColor = UIColor.lightGray
        self.inRangeStatisticLabelOutlet.text = "-"
        self.highStatisticLabelOutlet.textColor = UIColor.lightGray
        self.highStatisticLabelOutlet.text = "-"
        self.averageStatisticLabelOutlet.text = "-"
        self.a1CStatisticLabelOutlet.text = "-"
        self.cVStatisticLabelOutlet.text = "-"
        self.timePeriodLabelOutlet.text = "- - -"
        
        
        // statisticsManager will calculate the statistics in background thread and call the callback function in the main thread
        statisticsManager?.calculateStatistics(fromDate: fromDate, toDate: nil, callback: { statistics in
            
            // set the title labels to their correct localization
            self.lowTitleLabelOutlet.text = Texts_Common.lowStatistics
            self.inRangeTitleLabelOutlet.text = Texts_Common.inRangeStatistics
            self.highTitleLabelOutlet.text = Texts_Common.highStatistics
            self.averageTitleLabelOutlet.text = Texts_Common.averageStatistics
            self.a1cTitleLabelOutlet.text = Texts_Common.a1cStatistics
            self.cvTitleLabelOutlet.text = Texts_Common.cvStatistics
            
            
            // set the low/high "label" labels with the low/high user values that the user has chosen to use
            self.lowLabelOutlet.text = "(<" + (isMgDl ? Int(statistics.lowLimitForTIR).description : statistics.lowLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
            self.highLabelOutlet.text = "(>" + (isMgDl ? Int(statistics.highLimitForTIR).description : statistics.highLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
            
            
            // set all label outlets with the correctly formatted calculated values
            self.lowStatisticLabelOutlet.textColor = ConstantsStatistics.labelLowColor
            self.lowStatisticLabelOutlet.text = Int(statistics.lowStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            
            self.inRangeStatisticLabelOutlet.textColor = ConstantsStatistics.labelInRangeColor
            self.inRangeStatisticLabelOutlet.text = Int(statistics.inRangeStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            
            self.highStatisticLabelOutlet.textColor = ConstantsStatistics.labelHighColor
            self.highStatisticLabelOutlet.text = Int(statistics.highStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            
            // if there are no values returned (new sensor?) then just leave the default "-" showing
            if statistics.averageStatisticValue.value > 0 {
                self.averageStatisticLabelOutlet.text = (isMgDl ? Int(statistics.averageStatisticValue.round(toDecimalPlaces: 0)).description : statistics.averageStatisticValue.round(toDecimalPlaces: 1).description) + (isMgDl ? " mg/dl" : " mmol/l")
            }
            
            // if there are no values returned (new sensor?) then just leave the default "-" showing
            if statistics.a1CStatisticValue.value > 0 {
                if UserDefaults.standard.useIFCCA1C {
                    self.a1CStatisticLabelOutlet.text = Int(statistics.a1CStatisticValue.round(toDecimalPlaces: 0)).description + " mmol"
                } else {
                    self.a1CStatisticLabelOutlet.text = statistics.a1CStatisticValue.round(toDecimalPlaces: 1).description + "%"
                }
            }
            
            // if there are no values returned (new sensor?) then just leave the default "-" showing
            if statistics.cVStatisticValue.value > 0 {
                self.cVStatisticLabelOutlet.text = Int(statistics.cVStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            }
            
            // show number of days calculated under the pie chart
            switch daysToUseStatistics {
            case 0:
                self.timePeriodLabelOutlet.text = Texts_Common.today
                
            case 1:
                self.timePeriodLabelOutlet.text = "24 " + Texts_Common.hours
                
            default:
                self.timePeriodLabelOutlet.text = statistics.numberOfDaysUsed.description + " " + Texts_Common.days
            }
            
            
            // disable the chart animation if it's just a normal update, enable it if the call comes from didAppear()
            if animatePieChart {
                self.pieChartOutlet.animDuration = ConstantsStatistics.pieChartAnimationSpeed
            } else {
                self.pieChartOutlet.animDuration = 0
            }
            
            // we want to calculate how many hours have passed since midnight so that we can decide if we should show the easter egg. The user will almost always be in range at 01hrs in the morning so we don't want to show it until mid-morning or midday so that there is some sense of achievement
            let currentHoursSinceMidnight = Calendar.current.dateComponents([.hour], from: Calendar(identifier: .gregorian).startOfDay(for: Date()), to: Date()).hour!
            
            
            self.activityMonitorOutlet.isHidden = true
            
            // if the user is 100% in range, show the easter egg and make them smile
            if statistics.inRangeStatisticValue < 100 {
                
                // set the reference angle of the pie chart to ensure that the in range slice is centered
                self.pieChartOutlet.referenceAngle = 90.0 - (1.8 * CGFloat(statistics.inRangeStatisticValue))
                
                self.pieChartOutlet.innerRadius = 0
                self.pieChartOutlet.models = [
                    PieSliceModel(value: Double(statistics.inRangeStatisticValue), color: ConstantsStatistics.pieChartInRangeSliceColor),
                    PieSliceModel(value: Double(statistics.lowStatisticValue), color: ConstantsStatistics.pieChartLowSliceColor),
                    PieSliceModel(value: Double(statistics.highStatisticValue), color: ConstantsStatistics.pieChartHighSliceColor)
                ]
                
                self.pieChartLabelOutlet.text = ""
                
            } else if ConstantsStatistics.showInRangeEasterEgg && ((Double(currentHoursSinceMidnight) >= ConstantsStatistics.minimumHoursInDayBeforeShowingEasterEgg) || (UserDefaults.standard.daysToUseStatistics > 0)) {
                
                // if we want to show easter eggs check if one of the following two conditions is true:
                //      - at least 16 hours (for example) have passed since midnight if the user is showing only Today and is still 100% in range
                //      - if the user is showing >= 1 full days and they are still 100% in range
                // the idea is to avoid that the easter egg appears after just a few minutes of being in range (at 00:15hrs for example) as this has no merit.
                
                // open up the inside of the chart so that we can fit the smiley face in
                self.pieChartOutlet.innerRadius = 16
                self.pieChartOutlet.models = [
                    PieSliceModel(value: 1, color: ConstantsStatistics.pieChartInRangeSliceColor)
                ]
                
                self.pieChartLabelOutlet.font = UIFont.boldSystemFont(ofSize: 26)
                
                let components = Calendar.current.dateComponents([.month, .day], from: Date())
                
                if components.day != nil {
                    
                    // let's add a Christmas holiday easter egg. Because... why not?
                    if components.month == 12 && (components.day! >= 23 && components.day! <= 31) {
                        
                        self.pieChartLabelOutlet.text = "🎁"
                        
                    } else {
                        
                        // ok, so it's not Chistmas, but we can still be happy about a 100% TIR
                        self.pieChartLabelOutlet.text = "😎"
                        
                    }
                }

            } else {
                
                // the easter egg isn't wanted so just show a green circle at 100%
                self.pieChartOutlet.innerRadius = 0
                self.pieChartOutlet.models = [
                    PieSliceModel(value: 1, color: ConstantsStatistics.pieChartInRangeSliceColor)
                ]
                
                self.pieChartLabelOutlet.text = ""
                
            }
            
        })
    }
    
    /// swaps status from locked to unlocked or vice versa, and creates alert to inform user
    /// - parameters:
    ///     - overrideScreenIsLocked : if true, then screen will be locked even if it's already locked. If false, then status swaps from locked to unlocked or unlocked to locked
    ///     - showClock : when true this parameter will be passed to the screeLockUpdate function and this will lock the screen in the full lock mode adjusting font sizes and showing the clock as required.
    private func screenLockAlert(overrideScreenIsLocked: Bool = false, showClock: Bool = true) {
        
        if !screenIsLocked || overrideScreenIsLocked {
            
            trace("screen lock : user clicked the lock button or long pressed the value", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
            // lock and update the screen
            self.screenLockUpdate(enabled: true, showClock: showClock)
            
            // only trigger the UIAlert if the user hasn't previously asked to not show it again
            if !UserDefaults.standard.lockScreenDontShowAgain {
                
                // create uialertcontroller to inform user
                screenLockAlertController = UIAlertController(title: Texts_HomeView.screenLockTitle, message: Texts_HomeView.screenLockInfo, preferredStyle: .alert)

                // create "don't show again" button for uialertcontroller
                let dontShowAgainAction = UIAlertAction(title: Texts_Common.dontShowAgain, style: .destructive) {
                    (action:UIAlertAction!) in
                    
                    // if clicked set the user default key to false so that the next time the user locks the screen, the UIAlert isn't triggered
                    UserDefaults.standard.lockScreenDontShowAgain = true
                    
                }
                
                // create OK button for uialertcontroller
                let OKAction = UIAlertAction(title: Texts_Common.Ok, style: .default) {
                    (action:UIAlertAction!) in
                    
                    // set screenLockAlertController to nil because this variable is used when app comes to foreground, to check if alert is still presented
                    self.screenLockAlertController = nil
                    
                }

                // add buttons to the alert
                screenLockAlertController!.addAction(dontShowAgainAction)
                screenLockAlertController!.addAction(OKAction)

                // show alert
                self.present(screenLockAlertController!, animated: true, completion:nil)
                
            }
            
            
            // schedule timer to dismiss the uialert controller after some time, in case user doesn't click ok
            Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(dismissScreenLockAlertController), userInfo: nil, repeats:false)
            
        } else {
            
            trace("screen lock : user clicked the unlock button", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
            // this means the user has clicked the button whilst the screen look in already in place so let's turn the function off
            self.screenLockUpdate(enabled: false, showClock: showClock)
            
        }
        
    }
    
    
    /// this function will run when the user wants the screen to lock, or whenever the view appears and it will set up the screen correctly for each mode
    /// - parameters :
    ///     - enabled : when true this will force the screen to lock
    ///     - showClock : when false, this will enable a simple screen lock without changing the UI - useful for keeping the screen open on your desk
    private func screenLockUpdate(enabled: Bool = true, showClock: Bool = true) {

        if enabled {
            
            // set the toolbar button text to "Unlock"
            screenLockToolbarButtonOutlet.title = Texts_HomeView.unlockButton
            
            screenLockToolbarButtonOutlet.tintColor = UIColor.red
            
            // vibrate so that user knows that the screen lock has been activated
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            
            // check if iOS13 or newer is being used. If it is, then take advantage of SF Symbols to fill in the lock icon to make it stand out more
            if #available(iOS 13.0, *), showClock {

                screenLockToolbarButtonOutlet.image = UIImage(systemName: "lock.fill")
            
            }
            
            if showClock {
                
                // set the value label font size to big
                valueLabelOutlet.font = ConstantsUI.valueLabelFontSizeScreenLock
                
                // de-clutter the screen. Hide the mini-chart, statistics view, controls and show the clock view
                miniChartOutlet.isHidden = true
                statisticsView.isHidden = true
                segmentedControlsView.isHidden = true
                sensorCountdownOutlet.isHidden = true
                
                if UserDefaults.standard.showClockWhenScreenIsLocked {
                    
                    // set the clock label font size to big (force ConstantsUI implementation)
                    clockLabelOutlet.font = ConstantsUI.clockLabelFontSize
                    
                    // set clock label color
                    clockLabelOutlet.textColor = ConstantsUI.clockLabelColor
                    
                    clockView.isHidden = false
                    
                    // set the format for the clock view and update it to show the current time
                    updateClockView()
                    
                    // set a timer instance to update the clock view label every second
                    clockTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateClockView), userInfo: nil, repeats:true)
                    
                } else {
                    
                    clockView.isHidden = true
                    
                }
            
            }

            // prevent screen dim/lock
            UIApplication.shared.isIdleTimerDisabled = true
            
            // prevent screen rotation
            (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
            
            // set the private var so that we can track the screen lock activation within the RootViewController
            screenIsLocked = true
           
            trace("screen lock : screen lock / keep-awake enabled", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
        } else {
            
            // set the toolbar button text to "Lock"
            screenLockToolbarButtonOutlet.title = Texts_HomeView.lockButton
            
            screenLockToolbarButtonOutlet.tintColor = nil
            
            // check if iOS13 or newer is being used. If it is, then set the lock icon back to the standard SF Symbol
            if #available(iOS 13.0, *) {
                
                screenLockToolbarButtonOutlet.image = UIImage(systemName: "lock")
            
            }

            valueLabelOutlet.font = ConstantsUI.valueLabelFontSizeNormal
            
            // hide
            miniChartOutlet.isHidden = !UserDefaults.standard.showMiniChart
            statisticsView.isHidden = !UserDefaults.standard.showStatistics
            segmentedControlsView.isHidden = false
            sensorCountdownOutlet.isHidden = !UserDefaults.standard.showSensorCountdown
            
            clockView.isHidden = true
            
            if showClock {
                
                // destroy the timer instance so that it doesn't keep using resources
                clockTimer?.invalidate()
                
            }
            
            // make sure that the screen lock is deactivated
            UIApplication.shared.isIdleTimerDisabled = false
            
            // revert screen rotation settings
            updateScreenRotationSettings()
            
            trace("screen lock / keep-awake disabled", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            screenIsLocked = false
            
        }
        
    }
    
    
    /// update the label in the clock view every time this function is called
    @objc private func updateClockView() {
        self.clockLabelOutlet.text = clockDateFormatter.string(from: Date())
    }

    /// checks if screenLockAlertController is not nil and if not dismisses the presentedViewController
    @objc private func dismissScreenLockAlertController() {
        
        // possibly screenLockAlertController is still on the screen which would happen if user chooses to lock the screen but brings the app to the background before clicking ok
        if self.screenLockAlertController != nil {
            
            self.presentedViewController?.dismiss(animated: false, completion: nil)
            
            self.screenLockAlertController = nil
            
        }

    }
    
    
    /// this function will check if the user is using a time-sensitive sensor (such as a 14 day Libre, calculate the days remaining and then update the imageUI with the relevant svg image from the project assets.
    private func updateSensorCountdown() {
        
        // if the user has chosen not to display the countdown graphic, then make sure the graphic is hidden and just return back without doing anything
        if !UserDefaults.standard.showSensorCountdown {
            sensorCountdownOutlet.isHidden = true
            return
        }
        
        // if there's no active sensor, there's nothing to do or show
        guard activeSensor != nil else {
            sensorCountdownOutlet.isHidden = true
            return
        }
        
        // check that the sensor start date is not nil before unwrapping it
        guard activeSensor?.startDate != nil else {
            return
        }
        
        // check if there is a transmitter connected (needed as Dexcom will only connect briefly every 5 minutes)
        // if there is a transmitter connected, pull the current maxSensorAgeInDays and store in in UserDefaults
        if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let maxDays = cgmTransmitter.maxSensorAgeInDays() {
            UserDefaults.standard.maxSensorAgeInDays = maxDays
        }
        
        // pull the boolean value from UserDefaults to see if you user prefers the alternative graphics (count-up instead of count-down)
        let showSensorCountdownAlternativeGraphics = UserDefaults.standard.showSensorCountdownAlternativeGraphics

        // check if the sensor type has a hard coded maximum sensor life previously stored.
        if let maxSensorAgeInDays = UserDefaults.standard.maxSensorAgeInDays as Int?, maxSensorAgeInDays > 0 {
        
            // calculate how many hours the sensor has been used for since starting. We need to use hours instead of days because during the last day we need to see how many hours are left so that we can display the warning and urgent status graphics.
            let currentSensorAgeInHours: Int = Calendar.current.dateComponents([.hour], from: activeSensor!.startDate - 5 * 60, to: Date()).hour!
            
            // we need to calculate the hours so that we can see if we need to show the yellow (<12hrs remaining) or red (<6hrs remaining) graphics
            let sensorCountdownHoursRemaining: Int = (maxSensorAgeInDays * 24) - currentSensorAgeInHours
            
            // start programatically creating the asset name that we will loaded. This is based upon the max sensor days and the days "remaining". To get the full days, we need to round up the currentSensorAgeInHours to the nearest 24 hour block
            var sensorCountdownAssetName: String = "sensor" +  String(maxSensorAgeInDays) + "_"

            // find the amount of days remaining and add it to the asset name string. If there is less than 12 hours, add the corresponding warning/urgent label. If the sensor hours remaining is 0 or less, then the sensor is either expired or in the last 12 hours of "overtime" (e.g Libre sensors have an extra 12 hours before the stop working). If this happens, then instead of appending the days left, always show the "00" graphic.
            if sensorCountdownHoursRemaining > 0 {
                
                sensorCountdownAssetName += String(format: "%02d", maxSensorAgeInDays - Int(round(Double(currentSensorAgeInHours / 24)) * 24) / 24)
                
                switch sensorCountdownHoursRemaining {

                    case 7...12:
                        sensorCountdownAssetName += "_warning"
                    case 1...6:
                        sensorCountdownAssetName += "_urgent"
                    default: break

                }
                
            } else {
                
                sensorCountdownAssetName += "00"
                
            }
            
            // if the user prefers the alternative graphics (count-up), then append this to the end of the string
            if showSensorCountdownAlternativeGraphics {
                sensorCountdownAssetName += "_alt"
            }
            
            // update the UIImage
            sensorCountdownOutlet.image = UIImage(named: sensorCountdownAssetName)
            
            // show the sensor countdown image
            sensorCountdownOutlet.isHidden = false
            
        } else {

            // this must be a sensor without a maxSensorAge , so just make sure to hide the sensor countdown image and do nothing
            sensorCountdownOutlet.isHidden = true

        }
        
    }
    
    func showLandscape(with coordinator: UIViewControllerTransitionCoordinator) {
        
        guard landscapeChartViewController == nil else { return }
        
        landscapeChartViewController = storyboard!.instantiateViewController(
            withIdentifier: "LandscapeChartViewController")
        as? LandscapeChartViewController
        
        if let controller = landscapeChartViewController {
            controller.view.frame = view.bounds
            controller.view.alpha = 0
            view.addSubview(controller.view)
            addChild(controller)
            coordinator.animate(alongsideTransition: { _ in
                controller.view.alpha = 1
            }, completion: { _ in
                controller.didMove(toParent: self)
            })
        }
    }
    
    func hideLandscape(with coordinator: UIViewControllerTransitionCoordinator) {
        
        if let controller = landscapeChartViewController {
            controller.willMove(toParent: nil)
            coordinator.animate(alongsideTransition: { _ in
                controller.view.alpha = 0
            }, completion: { _ in
                controller.view.removeFromSuperview()
                controller.removeFromParent()
                self.landscapeChartViewController = nil
            })
            
            if let controller = landscapeChartViewController {
                controller.willMove(toParent: nil)
                coordinator.animate(alongsideTransition: { _ in
                    controller.view.alpha = 0
                }, completion: { _ in
                    controller.view.removeFromSuperview()
                    controller.removeFromParent()
                    self.landscapeChartViewController = nil
                })
            }
        }
    }


    /// if there is an active WCSession open between the app and the watch app, then process the current data and send it via the messaging service to the watch app.
    private func updateWatchApp() {
        
        // if there is no active WCSession open (i.e. if there is no paired Apple Watch with the watch app installed and running), then do nothing and just return
        if let validSession = self.session, validSession.isReachable {
            
            let mgdl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
            
            // make sure that the necessary objects are initialised and readings are available.
            if let bgReadingsAccessor = bgReadingsAccessor, let lastReading = bgReadingsAccessor.last(forSensor: nil) {
                
                let calculatedValueAsString = lastReading.unitizedString(unitIsMgDl: mgdl)
                
                var calculatedValueFullAsString: String = ""
                var calculatedValueTrendAsString: String = ""
                
                if !lastReading.hideSlope {
                    calculatedValueTrendAsString = lastReading.slopeArrow()
                    calculatedValueFullAsString = calculatedValueAsString + " " + calculatedValueTrendAsString
                }
                
                let minutesAgo = -Int(lastReading.timeStamp.timeIntervalSinceNow) / 60
                
                let minutesAgoTextLocalized = (minutesAgo == 1 ? Texts_Common.minute:Texts_Common.minutes) // + " " + Texts_HomeView.ago
                
                let latestReadings = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
                
                // check that there actually exists some readings. If not then return without doing anything (if we don't trap this it could sometimes cause a crash if the app hasn't had time to collect recent readings)
                guard latestReadings.count > 0 else {
                    
                    return
                }
                
                // assign last reading
                let lastReading = latestReadings[0]
                
                // assign last but one reading
                let lastButOneReading = latestReadings.count > 1 ? latestReadings[1]:nil
                
                // create delta text from the last two readings
                let deltaText = lastReading.unitizedDeltaString(previousBgReading: lastButOneReading, showUnit: true, highGranularity: true, mgdl: mgdl)
                
                // create the WKSession messages in String format and send them. Although they are all sent almost immediately, they will be queued and sent in a background thread by the handler
                validSession.sendMessage(["currentBGValueText" : calculatedValueAsString], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["currentBGValueTextFull" : calculatedValueFullAsString], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["currentBGValueTrend" : calculatedValueTrendAsString], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["currentBGValue" : lastReading.unitizedString(unitIsMgDl: mgdl).description], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["minutesAgoTextLocalized" : minutesAgoTextLocalized], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["deltaTextLocalized" : deltaText], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["urgentLowMarkValueInUserChosenUnit" : UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.bgValueRounded(mgdl: mgdl).description], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["lowMarkValueInUserChosenUnit" : UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValueRounded(mgdl: mgdl).description], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["highMarkValueInUserChosenUnit" : UserDefaults.standard.highMarkValueInUserChosenUnit.bgValueRounded(mgdl: mgdl).description], replyHandler: nil, errorHandler: nil)
                
                validSession.sendMessage(["urgentHighMarkValueInUserChosenUnit" : UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.bgValueRounded(mgdl: mgdl).description], replyHandler: nil, errorHandler: nil)
                
                // send the timestamp last as this is what will eventually trigger the view refresh on the watch
                validSession.sendMessage(["currentBGTimeStamp" : ISO8601DateFormatter().string(from: lastReading.timeStamp)], replyHandler: nil, errorHandler: nil)
                
            }
            
        }
            
    }
    
    /// if allowed set the main screen rotation settings 
    fileprivate func updateScreenRotationSettings() {
        // if allowed, then permit the Root View Controller which is the main screen, to rotate left/right to show the landscape view
        if UserDefaults.standard.allowScreenRotation {
            
            (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .allButUpsideDown
            
        } else {
            
            (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
            
        }
    }
    
    /// - creates a new sensor and assigns it to activeSensor
    /// - if sendToTransmitter is true then sends startSensor command to transmitter (ony useful for Firefly)
    /// - saves to coredata
    private func startSensor(cGMTransmitter: CGMTransmitter?, sensorStarDate: Date, sensorCode: String?, coreDataManager: CoreDataManager, sendToTransmitter: Bool) {
        
        // create active sensor
        let newSensor = Sensor(startDate: sensorStarDate, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        
        // save the newly created Sensor permenantly in coredata
        coreDataManager.saveChanges()
        
        // send to transmitter
        if let cGMTransmitter = cGMTransmitter, sendToTransmitter {
            cGMTransmitter.startSensor(sensorCode: sensorCode, startDate: sensorStarDate)
        }

        // assign activeSensor to newSensor
        activeSensor = newSensor
        
    }
    
    private func stopSensor(cGMTransmitter: CGMTransmitter?, sendToTransmitter: Bool) {
    
        // create stopDate
        let stopDate = Date()
        
        // send stop sensor command to transmitter, don't check if there's an activeSensor in coredata or not, never know that there's a desync between coredata and transmitter
        if let cGMTransmitter = cGMTransmitter, sendToTransmitter {
            cGMTransmitter.stopSensor(stopDate: stopDate)
        }

        // no need to further continue if activeSensor = nil, and at the same time, unwrap coredataManager
        guard let activeSensor = activeSensor, let coreDataManager = coreDataManager else {
            return
        }

        // set endDate of activeSensor to stopDate
        activeSensor.endDate = stopDate
        
        // save changes to coreData
        coreDataManager.saveChanges()
        
        // asign nil to activeSensor
        self.activeSensor = nil
        
        // now that the activeSensor object has been destroyed, update (hide) the sensor countdown graphic
        updateSensorCountdown()

    }
    
    /// show the SwiftUI view via UIHostingController
    private func showBgReadingsView() {
        
        let bgReadingsViewController = UIHostingController(rootView: BgReadingsView().environmentObject(self.bgReadingsAccessor!).environmentObject(nightScoutUploadManager!) as! BgReadingsView)
        
        navigationController?.pushViewController(bgReadingsViewController, animated: true)
        
    }
    
}


// MARK: - conform to CGMTransmitter protocol

/// conform to CGMTransmitterDelegate
extension RootViewController: CGMTransmitterDelegate {

    func sensorStopDetected() {
        
        trace("sensor stop detected", log: log, category: ConstantsLog.categoryRootView, type: .info)

        stopSensor(cGMTransmitter: self.bluetoothPeripheralManager?.getCGMTransmitter(), sendToTransmitter: false)

    }
    
    func newSensorDetected(sensorStartDate: Date?) {
        
        trace("new sensor detected", log: log, category: ConstantsLog.categoryRootView, type: .info)

        // stop sensor, self.bluetoothPeripheralManager?.getCGMTransmitter() can be nil in case of Libre2, because new sensor is detected via NFC call which usually happens before the transmitter connection is made (and so before cGMTransmitter is assigned a new value)
        stopSensor(cGMTransmitter: self.bluetoothPeripheralManager?.getCGMTransmitter(), sendToTransmitter: false)

        // if sensorStartDate is given, then unwrap coreDataManager and startSensor
        if let sensorStartDate = sensorStartDate, let coreDataManager = coreDataManager {
            
            // use sensorCode nil, in the end there will be no start sensor command sent to the transmitter because we just received the sensorStartTime from the transmitter, so it's already started
            startSensor(cGMTransmitter: self.bluetoothPeripheralManager?.getCGMTransmitter(), sensorStarDate: sensorStartDate, sensorCode: nil, coreDataManager: coreDataManager, sendToTransmitter: false)
            
        }
        
    }
    
    func sensorNotDetected() {
        trace("sensor not detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        createNotification(title: Texts_Common.warning, body: Texts_HomeView.sensorNotDetected, identifier: ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected, sound: nil)
        
    }
    
    func cgmTransmitterInfoReceived(glucoseData: inout [GlucoseData], transmitterBatteryInfo: TransmitterBatteryInfo?, sensorAge: TimeInterval?) {
        
        trace("transmitterBatteryInfo %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, transmitterBatteryInfo?.description ?? "not received")
        trace("sensor time in days %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, sensorAge?.days.round(toDecimalPlaces: 1).description ?? "not received")
        trace("glucoseData size = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, glucoseData.count.description)
        
        // if received transmitterBatteryInfo not nil, then store it
        if let transmitterBatteryInfo = transmitterBatteryInfo {
            UserDefaults.standard.transmitterBatteryInfo = transmitterBatteryInfo
        }
        
        // list readings
        for (index, glucose) in glucoseData.enumerated() {
            
            trace("glucoseData %{public}@, value = %{public}@, timestamp = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, index.description, glucose.glucoseLevelRaw.description, glucose.timeStamp.toString(timeStyle: .long, dateStyle: .none))
            
        }
        
        // let's check to ensure that the sensor is not within the minimum warm-up time as defined in ConstantsMaster
        var supressReadingIfSensorIsWarmingUp: Bool = false
        
        if let sensorAgeInSeconds = sensorAge {
            
            let secondsUntilWarmUpComplete = (ConstantsMaster.minimumSensorWarmUpRequiredInMinutes * 60) - sensorAgeInSeconds
            
            if secondsUntilWarmUpComplete > 0 {
                
                supressReadingIfSensorIsWarmingUp = true
                
                trace("Sensor is still warming up. BG reading processing will remain suppressed for another %{public}@ minutes. (%{public}@ minutes warm-up required).", log: log, category: ConstantsLog.categoryRootView, type: .info, Int(secondsUntilWarmUpComplete/60).description, ConstantsMaster.minimumSensorWarmUpRequiredInMinutes.description)
                
            }
            
        }
        
        // process new readings if sensor is not still warming up
        if !supressReadingIfSensorIsWarmingUp {
            
            processNewGlucoseData(glucoseData: &glucoseData, sensorAge: sensorAge)
            
        }
        
        
    }
    
    func errorOccurred(xDripError: XdripError) {
        
        if xDripError.priority == .HIGH {
            
            createNotification(title: Texts_Common.warning, body: xDripError.errorDescription, identifier: ConstantsNotifications.notificationIdentifierForxCGMTransmitterDelegatexDripError, sound: nil)
            
        }
    }
    
}

// MARK: - conform to UITabBarControllerDelegate protocol

/// conform to UITabBarControllerDelegate, want to receive info when user clicks specific tabs
extension RootViewController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        
        // check which tab is being clicked
        if let navigationController = viewController as? SettingsNavigationController, let coreDataManager = coreDataManager, let soundPlayer = soundPlayer {
            
            navigationController.configure(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
            
        } else if let navigationController = viewController as? BluetoothPeripheralNavigationController, let bluetoothPeripheralManager = bluetoothPeripheralManager, let coreDataManager = coreDataManager {
            
            navigationController.configure(coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager)
            
        } else if let navigationController = viewController as? TreatmentsNavigationController, let coreDataManager = coreDataManager {
			navigationController.configure(coreDataManager: coreDataManager)
		}
    }
    
}

// MARK: - conform to UNUserNotificationCenterDelegate protocol

/// conform to UNUserNotificationCenterDelegate, for notifications
extension RootViewController: UNUserNotificationCenterDelegate {
    
    // called when notification created while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        if notification.request.identifier == ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest {
            
            // request calibration
            requestCalibration(userRequested: false)
            
            /// remove applicationManagerKeyInitialCalibration from application key manager - there's no need to initiate the calibration via this closure
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeyInitialCalibration)
            
            // call completionhandler to avoid that notification is shown to the user
            completionHandler([])
            
        } else if notification.request.identifier == ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected {
            
            // call completionhandler to show the notification even though the app is in the foreground, without sound
            completionHandler([.alert])
            
        } else if notification.request.identifier == ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing {
            
            // so actually the app was in the foreground, at the  moment the Transmitter Class called the cgmTransmitterNeedsPairing function, there's no need to show the notification, we can immediately call back the cgmTransmitter initiatePairing function
            completionHandler([])
            bluetoothPeripheralManager?.initiatePairing()
            
            // this will verify if it concerns an alert notification, if not pickerviewData will be nil
        } else if let pickerViewData = alertManager?.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) {
            
            
            PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
            
        }  else if notification.request.identifier == ConstantsNotifications.notificationIdentifierForVolumeTest {
            
            // user is testing iOS Sound volume in the settings. Only the sound should be played, the alert itself will not be shown
            if #available(iOS 14.0, *) {
                completionHandler([.sound, .list])
            } else {
                // Fallback on earlier versions
                completionHandler([.sound])
            }
            
        } else if notification.request.identifier == ConstantsNotifications.notificationIdentifierForxCGMTransmitterDelegatexDripError {
            
            // call completionhandler to show the notification even though the app is in the foreground, without sound
            completionHandler([.alert])
            
        }
    }
    
    // called when user clicks a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        trace("userNotificationCenter didReceive", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        // call completionHandler when exiting function
        defer {
            // call completionhandler
            completionHandler()
        }
        
        if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest {
            
            // nothing required, the requestCalibration function will be called as it's been added to ApplicationManager
            trace("     userNotificationCenter didReceive, user pressed calibration notification to open the app, requestCalibration should be called because closure is added in ApplicationManager.shared", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
        } else if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected {
            
            // if user clicks notification "sensor not detected", then show uialert with title and body
            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.sensorNotDetected, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing {
            
            // nothing required, the pairing function will be called as it's been added to ApplicationManager in function cgmTransmitterNeedsPairing
            
        } else {
            
            // it's not an initial calibration request notification that the user clicked, by calling alertManager?.userNotificationCenter, we check if it was an alert notification that was clicked and if yes pickerViewData will have the list of alert snooze values
            if let pickerViewData = alertManager?.userNotificationCenter(center, didReceive: response) {
                
                trace("     userNotificationCenter didReceive, user pressed an alert notification to open the app", log: log, category: ConstantsLog.categoryRootView, type: .info)
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
                
            } else {
                // it as also not an alert notification that the user clicked, there might come in other types of notifications in the future
            }
        }
    }
}

// MARK: - conform to NightScoutFollowerDelegate protocol

extension RootViewController:NightScoutFollowerDelegate {
    
    func nightScoutFollowerInfoReceived(followGlucoseDataArray: inout [NightScoutBgReading]) {
        
        if let coreDataManager = coreDataManager, let bgReadingsAccessor = bgReadingsAccessor, let nightScoutFollowManager = nightScoutFollowManager {
            
            trace("nightScoutFollowerInfoReceived", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            // assign value of timeStampLastBgReading
            var timeStampLastBgReading = Date(timeIntervalSince1970: 0)

            // get lastReading, ignore sensor as this should be nil because this is follower mode
            if let lastReading = bgReadingsAccessor.last(forSensor: nil) {
                
                timeStampLastBgReading = lastReading.timeStamp
                
                trace("    timeStampLastBgReading = %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, timeStampLastBgReading.toString(timeStyle: .long, dateStyle: .long))

            }
            
            // was a new reading created or not
            var newReadingCreated = false
            
            // iterate through array, elements are ordered by timestamp, first is the youngest, let's create first the oldest, although it shouldn't matter in what order the readings are created
            for (_, followGlucoseData) in followGlucoseDataArray.enumerated().reversed() {

                trace("    followGlucoseData timestamp = %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, followGlucoseData.timeStamp.toString(timeStyle: .long, dateStyle: .long))
                
                if followGlucoseData.timeStamp > timeStampLastBgReading {
                    
                    trace("    creating new bgreading timestamp = %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, followGlucoseData.timeStamp.toString(timeStyle: .long, dateStyle: .long))
                    
                    // creata a new reading
                    _ = nightScoutFollowManager.createBgReading(followGlucoseData: followGlucoseData)
                    
                    // a new reading was created
                    newReadingCreated = true
                    
                    // set timeStampLastBgReading to new timestamp
                    timeStampLastBgReading = followGlucoseData.timeStamp
                    
                }
            }
            
            if newReadingCreated {
                
                trace("    new reading(s) received", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                
                // save in core data
                coreDataManager.saveChanges()
                
                // update all text in  first screen
                updateLabelsAndChart(overrideApplicationState: false)
                
                // update the mini-chart
                updateMiniChart()
                
                // update statistics related outlets
                updateStatistics(animatePieChart: false)
                
                // update sensor countdown
                updateSensorCountdown()
                
                // check alerts, create notification, set app badge
                checkAlertsCreateNotificationAndSetAppBadge()
                
                if let healthKitManager = healthKitManager {
                    healthKitManager.storeBgReadings()
                }
                
                if let bgReadingSpeaker = bgReadingSpeaker {
                    bgReadingSpeaker.speakNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                }
                
                bluetoothPeripheralManager?.sendLatestReading()
                
                // ask watchManager to process new reading, ignore last connection change timestamp because this is follower mode, there is no connection to a transmitter
                watchManager?.processNewReading(lastConnectionStatusChangeTimeStamp: nil)
                
                // send also to loopmanager, not interesting for loop probably, but the data is also used for today widget
                if !UserDefaults.standard.suppressLoopShare {
                    self.loopManager?.share()
                }
                                
                updateWatchApp()
                
            }
        }
    }
}

extension RootViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer.view != chartOutlet {
            return false
        }
        
        if gestureRecognizer.view != otherGestureRecognizer.view {
            return false
        }
        
        return true
        
    }
    
}

// WCSession delegate functions
extension RootViewController: WCSessionDelegate {
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    // process any received messages from the watch app
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        // uncomment the following for debug console use
        print("received message from Watch App: \(message)")
        
        DispatchQueue.main.async {
            
            // if the action: refreshBGData message is received, then force the app to send new data to the Watch App
            if let action = message["action"] as? String {
                
                if action == "refreshBGData" {
                    
                    self.updateWatchApp()
                    
                }
            }
            
        }
    }
}
