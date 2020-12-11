import UIKit

class SetTargetTempViewController: ThemedStaticUITableViewController {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    enum TargetScope {
        case bed
        case tool0
        case tool1
        case tool2
        case tool3
        case tool4
        case chamber
    }

    @IBOutlet weak var newTemperatureLabel: UILabel!
    @IBOutlet weak var targetTempField: UITextField!
    @IBOutlet weak var offButton: UIButton!
    @IBOutlet weak var setButton: UIButton!
    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    
    var targetTempScope: SetTargetTempViewController.TargetScope?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch targetTempScope! {
        case .bed:
            if let printer = printerManager.getDefaultPrinter(), let bedTemps = printer.bedTemps, bedTemps.count > 1 {
                button1.setTitle("\(bedTemps[0])", for: .normal)
                button2.setTitle("\(bedTemps[1])", for: .normal)
            } else {
                button1.setTitle("60", for: .normal)
                button2.setTitle("80", for: .normal)
            }
        case .chamber:
            button1.setTitle("50", for: .normal)
            button2.setTitle("70", for: .normal)
        default:
            if let printer = printerManager.getDefaultPrinter(), let extruderTemps = printer.extruderTemps, extruderTemps.count > 1 {
                button1.setTitle("\(extruderTemps[0])", for: .normal)
                button2.setTitle("\(extruderTemps[1])", for: .normal)
            } else {
                button1.setTitle("210", for: .normal)
                button2.setTitle("235", for: .normal)
            }
        }

        // Only enable buttons if app is not locked
        offButton.isEnabled = !appConfiguration.appLocked()
        button1.isEnabled = !appConfiguration.appLocked()
        button2.isEnabled = !appConfiguration.appLocked()

        // Change colors based on current theme
        let theme = Theme.currentTheme()
        newTemperatureLabel.textColor = theme.labelColor()
        targetTempField.backgroundColor = theme.backgroundColor()
        targetTempField.textColor = theme.textColor()
        // Use separator color for more contrast on the arrow to make it more visible
        self.popoverPresentationController?.backgroundColor = theme.separatorColor()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func tempChanged(_ sender: Any) {
        if appConfiguration.appLocked() {
            // Do nothing since app is locked
            return
        }
        if let text = targetTempField.text, let newTemp: Int = Int(text) {
            if targetTempScope! == .bed {
                setButton.isEnabled = newTemp >= 0 && newTemp < 150
            } else {
                setButton.isEnabled = newTemp >= 0 && newTemp < 500
            }
        } else {
            setButton.isEnabled = false
        }
    }
    
    
    @IBAction func setOff(_ sender: Any) {
        targetTempField.text = "0"
        setTargetTemp(sender)
    }
    
    @IBAction func setButton1Temp(_ sender: Any) {
        targetTempField.text = button1.titleLabel?.text
        setTargetTemp(sender)
    }
    
    @IBAction func setButton2Temp(_ sender: Any) {
        targetTempField.text = button2.titleLabel?.text
        setTargetTemp(sender)
    }
    
    @IBAction func setTargetTemp(_ sender: Any) {
        performSegue(withIdentifier: "backFromSetTemperature", sender: self)
    }
}
