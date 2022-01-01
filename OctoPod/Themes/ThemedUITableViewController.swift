import UIKit

class ThemedUITableViewController: UITableViewController {

    var currentTheme: Theme.ThemeChoice!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeUIUtils.applyTheme(table: tableView, staticCells: staticCells())

        if currentTheme != Theme.currentTheme() {
            tableView.reloadData()
            currentTheme = Theme.currentTheme()
        }
    }
    
    // MARK: - Table operations

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.textLabel?.textColor = Theme.currentTheme().tableHeaderFooterTextColor()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.textLabel?.textColor = Theme.currentTheme().tableHeaderFooterTextColor()
        }
    }
    
    // MARK: - Abstract methods
    
    func staticCells() -> Bool {
        return false
    }
}

