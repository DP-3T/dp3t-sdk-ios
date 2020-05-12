/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK
import UIKit

class LogCell: UITableViewCell {
    override init(style _: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        textLabel?.numberOfLines = 0
        textLabel?.font = .boldSystemFont(ofSize: 12.0)
        detailTextLabel?.numberOfLines = 0
        selectionStyle = .none
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LogsViewController: UIViewController {
    let tableView = UITableView()

    let refreshControl = UIRefreshControl()

    var logs: [LogEntry] = []

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Logs"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "list.bullet"), tag: 0)
        }
        loadLogs()
        NotificationCenter.default.addObserver(self, selector: #selector(didClearData(notification:)), name: Notification.Name("ClearData"), object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(LogCell.self, forCellReuseIdentifier: "logCell")
        tableView.refreshControl = refreshControl
        tableView.dataSource = self
        refreshControl.addTarget(self, action: #selector(reloadLogs), for: .allEvents)
    }

    @objc func didClearData(notification _: Notification) {
        logs = []
        tableView.reloadData()
    }

    @objc
    func reloadLogs() {
        loadLogs()
    }

    func loadLogs() {
        DispatchQueue.global(qos: .background).async {
            if let logs  = try? DP3TTracing.getLogs() {
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.logs = logs
                }
            }
        }
    }
}

extension LogsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return logs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "logCell", for: indexPath) as! LogCell
        let log = logs[indexPath.row]
        cell.textLabel?.text = "\(log.timestamp.stringVal)"
        cell.detailTextLabel?.text = log.message
        return cell
    }
}

extension LogsViewController: DP3TTracingDelegate {
    func DP3TTracingStateChanged(_: TracingState) {
        loadLogs()
    }
}

extension Date {
    var stringVal: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM HH:mm:ss "
        return dateFormatter.string(from: self)
    }
}
