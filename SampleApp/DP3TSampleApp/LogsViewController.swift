/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
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
        } else {
            tabBarItem = UITabBarItem(title: title, image: nil, tag: 0)
        }
        loadLogs()
        NotificationCenter.default.addObserver(self, selector: #selector(didClearData(notification:)), name: Notification.Name("ClearData"), object: nil)

        NotificationCenter.default.addObserver(forName: .init("org.dpppt.didAddLog"), object: nil, queue: .main) { [weak self] _ in
            self?.reloadLogs()
        }
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
            if let logs = try? loggingStorage?.getLogs() {
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.logs = logs
                    self.tableView.reloadData()
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
        cell.textLabel?.text = "[\(log.type.string)] \(log.timestamp.stringVal)"
        cell.detailTextLabel?.text = log.message
        switch log.type {
        case .error:
            cell.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        case .info:
            cell.backgroundColor = UIColor.green.withAlphaComponent(0.05)
        default:
            if #available(iOS 13.0, *) {
                cell.backgroundColor = .systemBackground
            } else {
                cell.backgroundColor = .white
            }
        }
        return cell
    }
}

extension LogsViewController: DP3TTracingDelegate {
    func DP3TTracingStateChanged(_: TracingState) {}
}

extension Date {
    var stringVal: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM HH:mm:ss "
        return dateFormatter.string(from: self)
    }
}

private extension OSLogType {
    var string: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .default:
            return "DEFAULT"
        case .error:
            return "ERROR"
        case .fault:
            return "FAULT"
        case .info:
            return "INFO"
        default:
            return ""
        }
    }
}
