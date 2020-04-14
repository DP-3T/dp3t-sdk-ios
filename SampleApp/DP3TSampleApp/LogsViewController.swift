/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK_CALIBRATION
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

    var nextRequest: LogRequest?

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

    func loadLogs(request: LogRequest = LogRequest(sorting: .desc, offset: 0, limit: 200)) {
        DispatchQueue.global(qos: .background).async {
            if let resp = try? DP3TTracing.getLogs(request: request) {
                self.nextRequest = resp.nextRequest
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    if request.offset == 0 {
                        self.logs = resp.logs
                    } else {
                        self.logs.append(contentsOf: resp.logs)
                        self.tableView.reloadData()
                    }
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
        if indexPath.row == (logs.count - 1),
            let nextRequest = self.nextRequest {
            loadLogs(request: nextRequest)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "logCell", for: indexPath) as! LogCell
        let log = logs[indexPath.row]
        cell.textLabel?.text = "\(log.timestamp.stringVal) \(log.type.description)"
        cell.detailTextLabel?.text = log.message
        switch log.type {
        case .sender:
            cell.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.1)
        case .receiver:
            cell.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.1)
        default:
            cell.backgroundColor = .clear
        }
        return cell
    }
}

extension LogsViewController: DP3TTracingDelegate {
    func DP3TTracingStateChanged(_: TracingState) {}

    func didAddLog(_ entry: LogEntry) {
        logs.insert(entry, at: 0)
        if view.superview != nil {
            tableView.reloadData()
        }
        nextRequest?.offset += 1
    }
}

extension Date {
    var stringVal: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM HH:mm:ss "
        return dateFormatter.string(from: self)
    }
}
