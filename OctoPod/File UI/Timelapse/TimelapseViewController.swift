import UIKit
import AVKit

class TimelapseViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, WatchSessionManagerDelegate {

    private var currentTheme: Theme.ThemeChoice!

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    @IBOutlet weak var tableView: UITableView!
    var refreshControl: UIRefreshControl?

    var files: Array<Timelapse> = Array()

    var itemDelegate: AVAssetResourceLoaderDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()

        // Create, configure and add UIRefreshControl to table view
        refreshControl = UIRefreshControl()
        refreshControl!.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull down to refresh", comment: ""))
        tableView.addSubview(refreshControl!)
        tableView.alwaysBounceVertical = true
        self.refreshControl?.addTarget(self, action: #selector(refreshFiles), for: UIControl.Event.valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Listen to changes coming from Apple Watch
        watchSessionManager.delegates.append(self)

        if currentTheme != Theme.currentTheme() {
            // Theme changed so repaint table now (to prevent quick flash in the UI with the old theme)
            tableView.reloadData()
            currentTheme = Theme.currentTheme()
        }

        refreshNewSelectedPrinter()
        
        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)
        applyTheme()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes coming from Apple Watch
        watchSessionManager.remove(watchSessionManagerDelegate: self)
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = files[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "timelapse_cell", for: indexPath)
        cell.textLabel?.text = file.name
        cell.detailTextLabel?.text = file.size

        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let file = files[indexPath.row]
        
        
        if let printer = printerManager.getDefaultPrinter(), let url = URL(string: printer.hostname + file.url) {
            // Create AVPlayerItem object
            let headers = ["X-Api-Key": printer.apiKey]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey" : headers])
            
            if let username = printer.username, let password = printer.password {
                itemDelegate = UIUtils.getAVAssetResourceLoaderDelegate(username: username, password: password)
                asset.resourceLoader.setDelegate(itemDelegate, queue:  DispatchQueue.global(qos: .userInitiated))
            }
            
            let playerItem = AVPlayerItem(asset: asset)
            // Register as an observer of the player item's status property
            playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ), options: [.old, .new], context: nil)
            
            // Create AVPlayer object
            let player = AVPlayer(playerItem: playerItem)            
            
            let playerController = AVPlayerViewController()
            playerController.player = player
            
            present(playerController, animated: true) {
                player.play()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "Delete action"), handler: { (action, view, completionHandler) in
            let file = self.files[indexPath.row]
            // Delete timelapse from OctoPrint
            self.octoprintClient.deleteTimelapse(timelapse: file) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if let error = error {
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription) {
                        completionHandler(false)
                    }
                } else {
                    // Remove timelapse from files and refresh table
                    self.files.remove(at: indexPath.row)
                    DispatchQueue.main.async {
                        tableView.deleteRows(at: [indexPath], with: .fade)
                    }
                    completionHandler(true)
                }
            }
          })
        if #available(iOS 13.0, *) {
            deleteAction.image = UIImage(systemName: "trash")
        } else {
            // Fallback on earlier versions
        }

        let shareAction = UIContextualAction(style: .normal, title: NSLocalizedString("Share", comment: "Share action"), handler: { (action, view, completionHandler) in
            // Update data source when user taps action
            let file = self.files[indexPath.row]
            self.octoprintClient.downloadTimelapse(timelapse: file) { (data: Data?, error: Error?, response: HTTPURLResponse) in
                if let error = error {
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription) {
                        completionHandler(false)
                    }
                } else if let data = data {
                    // Write downloaded file into a filepath and return the filepath in NSURL
                    let fileURL = data.dataToFile(fileName: file.name)
                    let filesToShare = [fileURL]
                    let activityViewController = UIActivityViewController(activityItems: filesToShare as [Any], applicationActivities: nil)
                    DispatchQueue.main.async {
                        self.present(activityViewController, animated: true) {
                            completionHandler(true)
                        }
                    }
                } else {
                    completionHandler(false)
                }
            }
            completionHandler(true)
          })
        if #available(iOS 13.0, *) {
            shareAction.image = UIImage(systemName: "square.and.arrow.up")
        } else {
            // Fallback on earlier versions
        }
        
        return UISwipeActionsConfiguration(actions: appConfiguration.appLocked() ? [shareAction] : [deleteAction, shareAction])
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            
            // Get the status change from the change dictionary
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over the status
            switch status {
            case .readyToPlay:
                break
            case .failed:
                NSLog("Player item failed.")
                if let playerItem = object as? AVPlayerItem, let error = playerItem.error {
                    NSLog("Player item error: \(error.localizedDescription)")
//                        self.stopPlaying()
//                    // Display error messages
//                    self.errorMessageLabel.text = error.localizedDescription
//                    self.errorMessageLabel.numberOfLines = 2
//                    self.errorURLButton.setTitle(self.cameraURL, for: .normal)
//                    self.errorMessageLabel.isHidden = false
//                    self.errorURLButton.isHidden = false
                }
            case .unknown:
                NSLog("Player item is not yet ready.")
            @unknown default:
                NSLog("Unkown status: \(status)")
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - WatchSessionManagerDelegate
    
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            self.refreshNewSelectedPrinter()
        }
    }
    
    // MARK: - Refresh functions

    @objc func refreshFiles() {
        loadFiles(done: nil)
    }
    
    // MARK: - Theme functions
    
    fileprivate func applyTheme() {
        let theme = Theme.currentTheme()
        
        // Set background color to the view
        view.backgroundColor = theme.backgroundColor()

        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)
    }

    // MARK: - Private functions

    fileprivate func loadFiles(delay seconds: Double) {
        // Wait requested seconds before loading files (so SD card has time to be read)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.loadFiles(done: nil)
        }
    }
    
    fileprivate func loadFiles(done: (() -> Void)?) {
        // Refreshing files could take some time so show spinner of refreshing
        DispatchQueue.main.async {
            if let refreshControl = self.refreshControl {
                refreshControl.beginRefreshing()
                self.tableView.setContentOffset(CGPoint(x: 0, y: self.tableView.contentOffset.y - refreshControl.frame.size.height), animated: true)
            }
        }
        // Load all files and folders (recursive)
        octoprintClient.timelapses { (result: Array<Timelapse>?, error: Error?, response: HTTPURLResponse) in
            self.files = Array()
            // Handle connection errors
            if let error = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription, done: nil)
            } else if let newFiles = result {
                // Sort files by date (newest at the top)
                self.files = newFiles.sorted { (left: Timelapse, right: Timelapse) -> Bool in
                    return left.date > right.date
                }
            }
            // Refresh table (even if there was an error so it is empty)
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()
            }
            // Execute done block when done
            done?()
        }
    }

    fileprivate func refreshNewSelectedPrinter() {
        loadFiles(done: nil)
    }
    
    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }
}
