import UIKit

class MoveViewController: UIViewController, OctoPrintClientDelegate, OctoPrintSettingsDelegate, CameraViewDelegate, DefaultPrinterManagerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()

    var camerasViewController: CamerasViewController?

    var screenHeight: CGFloat!
    var imageAspectRatio16_9: Bool = false
    var transitioningNewPage: Bool = false
    var camera4_3HeightConstraintPortrait: CGFloat! = 313
    var camera4_3HeightConstraintLandscape: CGFloat! = 330
    var camera16_9HeightConstraintPortrait: CGFloat! = 313
    var cameral16_9HeightConstraintLandscape: CGFloat! = 330
    
    @IBOutlet weak var cameraHeightConstraint: NSLayoutConstraint!
    
    // Gestures to switch between printers
    var swipeLeftGestureRecognizer : UISwipeGestureRecognizer!
    var swipeRightGestureRecognizer : UISwipeGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep track of children controllers
        trackChildrenControllers()        

        // Listen to event when first image gets loaded so we can adjust UI based on aspect ratio of image
        camerasViewController?.embeddedCameraDelegate = self
        
        // Calculate constraint for subpanel
        calculateCameraHeightConstraints()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
        // Listen to changes to default printer
        defaultPrinterManager.delegates.append(self)

        // Set background color to the view
        let theme = Theme.currentTheme()
        view.backgroundColor = theme.backgroundColor()

        refreshNewSelectedPrinter()

        // Add gestures to capture swipes and taps on navigation bar
        addNavBarGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Now that cameraVC has appeared, we can configure it to display print status info
        camerasViewController?.displayPrintStatus(enabled: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to changes from OctoPrintClient
        octoprintClient.remove(octoPrintClientDelegate: self)
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
        // Remove gestures that capture swipes and taps on navigation bar
        removeNavBarGestures()
    }

    // MARK: - OctoPrintClientDelegate
    
    func printerStateUpdated(event: CurrentStateEvent) {
        camerasViewController?.currentStateUpdated(event: event)
    }

    // MARK: - OctoPrintSettingsDelegate
    
    func sdSupportChanged(sdSupport: Bool) {
        // Do nothing
    }
    
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
        DispatchQueue.main.async {
            self.updateForCameraOrientation(orientation: newOrientation)
        }
    }
    
    // Notification that a new camera has been added or removed. We rely on MultiCam
    // plugin to be installed on OctoPrint so there is no need to re-enter this information
    // URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>) {
        camerasViewController?.camerasChanged(camerasURLs: camerasURLs)
    }

    // React when device orientation changes
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let printer = printerManager.getDefaultPrinter() {
            // Update layout depending on camera orientation
            updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!, devicePortrait: size.height == screenHeight)
        }
    }
    
    // MARK: - EmbeddedCameraDelegate
    
    func imageAspectRatio(cameraIndex: Int, ratio: CGFloat) {
        let newRatio = ratio < 0.60
        if imageAspectRatio16_9 != newRatio {
            imageAspectRatio16_9 = newRatio
            if !transitioningNewPage {
                if let printer = printerManager.getDefaultPrinter() {
                    let orientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                    // Add a tiny delay so the UI does not go crazy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.updateForCameraOrientation(orientation: orientation)
                    }
                }
            }
        }
    }
    
    func startTransitionNewPage() {
        transitioningNewPage = true
    }
    
    func finishedTransitionNewPage() {
        transitioningNewPage = false
        if let printer = printerManager.getDefaultPrinter() {
            let orientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
            // Add a tiny delay so the UI does not go crazy
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateForCameraOrientation(orientation: orientation)
            }
            camerasViewController?.displayPrintStatus(enabled: true)
        }
    }

    // MARK: - DefaultPrinterManagerDelegate
    
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            self.refreshNewSelectedPrinter()
            self.camerasViewController?.printerSelectedChanged()
        }
    }
    
    // MARK: - Private - Navigation Bar Gestures

    fileprivate func addNavBarGestures() {
        // Add gesture when we swipe from right to left
        swipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeLeftGestureRecognizer.direction = .left
        navigationController?.navigationBar.addGestureRecognizer(swipeLeftGestureRecognizer)
        swipeLeftGestureRecognizer.cancelsTouchesInView = false
        
        // Add gesture when we swipe from left to right
        swipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeRightGestureRecognizer.direction = .right
        navigationController?.navigationBar.addGestureRecognizer(swipeRightGestureRecognizer)
        swipeRightGestureRecognizer.cancelsTouchesInView = false
    }

    fileprivate func removeNavBarGestures() {
        // Remove gesture when we swipe from right to left
        navigationController?.navigationBar.removeGestureRecognizer(swipeLeftGestureRecognizer)
        
        // Remove gesture when we swipe from left to right
        navigationController?.navigationBar.removeGestureRecognizer(swipeRightGestureRecognizer)
    }

    @objc fileprivate func navigationBarSwiped(_ gesture: UIGestureRecognizer) {
        // Change default printer
        let direction: DefaultPrinterManager.SwipeDirection = gesture == swipeLeftGestureRecognizer ? .left : .right
        defaultPrinterManager.navigationBarSwiped(direction: direction)
    }

    // MARK: - Private functions
    
    // We are using Container Views so this is how we keep a reference to the contained view controllers
    fileprivate func trackChildrenControllers() {
        guard let camerasChild = children.first as? CamerasViewController else {
            fatalError("Check storyboard for missing CamerasViewController")
        }
        camerasViewController = camerasChild
    }
    
    fileprivate func updateForCameraOrientation(orientation: UIImage.Orientation, devicePortrait: Bool = UIApplication.shared.statusBarOrientation.isPortrait) {
        if cameraHeightConstraint == nil {
            // Do nothing since view never rendered
            return
        }
        // Check if user decided to hide camera subpanel for this printer
        if let printer = printerManager.getDefaultPrinter(), printer.hideCamera {
            cameraHeightConstraint.constant = 0
            return
        }
        if orientation == UIImage.Orientation.left || orientation == UIImage.Orientation.leftMirrored || orientation == UIImage.Orientation.rightMirrored || orientation == UIImage.Orientation.right {
            cameraHeightConstraint.constant = 281 + 50
        } else {
            if imageAspectRatio16_9 {
                cameraHeightConstraint.constant = devicePortrait ? camera16_9HeightConstraintPortrait! : cameral16_9HeightConstraintLandscape!
            } else {
                cameraHeightConstraint.constant = devicePortrait ? camera4_3HeightConstraintPortrait! : camera4_3HeightConstraintLandscape!
            }
        }
    }

    fileprivate func calculateCameraHeightConstraints() {
        let devicePortrait = UIApplication.shared.statusBarOrientation.isPortrait
        screenHeight = devicePortrait ? UIScreen.main.bounds.height : UIScreen.main.bounds.width
        let constraints = UIUtils.calculateCameraHeightConstraints(screenHeight: screenHeight)
        
        camera4_3HeightConstraintPortrait = constraints.cameraHeight4_3ConstraintPortrait
        camera4_3HeightConstraintLandscape = constraints.cameraHeight4_3ConstraintLandscape
        camera16_9HeightConstraintPortrait = constraints.camera16_9HeightConstraintPortrait
        cameral16_9HeightConstraintLandscape = constraints.cameral16_9HeightConstraintLandscape
    }
    
    fileprivate func refreshNewSelectedPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
            
            // Use last known aspect ratio of first camera of this printer
            // End user will have a better experience with this
            self.imageAspectRatio16_9 = printer.firstCameraAspectRatio16_9
            
            // Update layout depending on camera orientation
            updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!)
            
        } else {
            navigationItem.title = NSLocalizedString("Move", comment: "")
        }
    }
}
