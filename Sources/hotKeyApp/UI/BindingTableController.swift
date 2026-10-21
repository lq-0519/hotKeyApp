import AppKit

/// 管理设置窗口里 bindings 表格的数据源与展示。
final class BindingTableController: NSObject, NSTableViewDataSource, NSTableViewDelegate {

    private(set) var bindings: [Binding]
    private weak var tableView: NSTableView?

    // 列标识
    static let colName = NSUserInterfaceItemIdentifier("name")
    static let colShortcut = NSUserInterfaceItemIdentifier("shortcut")
    static let colTarget = NSUserInterfaceItemIdentifier("target")

    init(bindings: [Binding], tableView: NSTableView) {
        self.bindings = bindings
        self.tableView = tableView
        super.init()
        tableView.dataSource = self
        tableView.delegate = self
    }

    func setBindings(_ newBindings: [Binding]) {
        bindings = newBindings
        tableView?.reloadData()
    }

    var selectedIndex: Int? {
        guard let row = tableView?.selectedRow, row >= 0 else { return nil }
        return row
    }

    // MARK: - DataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        bindings.count
    }

    // MARK: - Delegate(View-based)

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard let column = tableColumn, row < bindings.count else { return nil }
        let binding = bindings[row]

        let text: String
        switch column.identifier {
        case BindingTableController.colName:
            text = binding.name
        case BindingTableController.colShortcut:
            text = binding.keyCombo.displayString
        case BindingTableController.colTarget:
            text = binding.target.bundleIdentifier
                ?? binding.target.path
                ?? "—"
        default:
            text = ""
        }

        let id = column.identifier
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = text
        return cell
    }
}
