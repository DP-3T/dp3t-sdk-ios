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
import ExposureNotification
import UIKit
import ZIPFoundation

struct KeySection: Hashable {
    let date: Date
    let experimentName: String?

    var title: String {
        let dateString = Self.formatter.string(from: date)
        if let experimentName = experimentName {
            return "\(dateString) - Experiment: \(experimentName)"
        }
        return "\(dateString) - Single Device"
    }

    static var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

class KeyDiffableDataSource: UITableViewDiffableDataSource<KeySection, NetworkingHelper.DebugZips> {
    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return snapshot().sectionIdentifiers[section].title
    }
}

class KeysViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let datePicker = UIDatePicker()

    private let cellReuseIdentifier = "keyCell"
    private lazy var dataSource: KeyDiffableDataSource = makeDataSource()

    private let networkingHelper = NetworkingHelper()

    let activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Keys"
        tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "keyboard"), tag: 0)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.top.right.equalTo(self.view.safeAreaLayoutGuide)
        }

        view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(self.view.safeAreaLayoutGuide)
            make.top.equalTo(tableView.snp.bottom)
        }

        datePicker.backgroundColor = .systemBackground
        datePicker.datePickerMode = .date
        datePicker.addTarget(self, action: #selector(datePickerDidChange), for: .valueChanged)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.dataSource = dataSource
        tableView.delegate = self

        self.dataSource.apply(NSDiffableDataSourceSnapshot<KeySection, NetworkingHelper.DebugZips>(), animatingDifferences: true)


        activityIndicator.hidesWhenStopped = true
        let barButton = UIBarButtonItem(customView: activityIndicator)
        self.navigationItem.setRightBarButton(barButton, animated: true)
        activityIndicator.stopAnimating()

        let ts = Date().timeIntervalSince1970
        let roundendTs = Date(timeIntervalSince1970: ts - ts.truncatingRemainder(dividingBy: 60 * 60 * 24))
        let date = roundendTs.addingTimeInterval(60 * 60 * 24)
        datePicker.setDate(date, animated: false)
        loadKey(for: date)
    }

    func loadKey(for date: Date) {
        activityIndicator.startAnimating()
        networkingHelper.getDebugKeys(day: date) { [weak self] result in
            guard let self = self else { return }
            defer { self.activityIndicator.stopAnimating() }
            var snapshot = self.dataSource.snapshot()

            let pattern = "key_export_experiment_([a-zA-Z0-9]+)_(.+)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }

            let grouped = result.reduce([KeySection: [NetworkingHelper.DebugZips]]()) { (result, zip) -> [KeySection : [NetworkingHelper.DebugZips]] in
                var experimentName: String? = nil
                //var deviceName: String?

                if let match = regex.firstMatch(in: zip.name, options: [], range: NSRange(location: 0, length: zip.name.utf16.count)) {
                    if let experimentRange = Range(match.range(at: 1), in: zip.name) {
                        experimentName = String(zip.name[experimentRange])
                    }

                    /*if let deviceRange = Range(match.range(at: 2), in: zip.name) {
                        deviceName = zip.name[deviceRange]
                    }*/
                }

                let section = KeySection(date: date, experimentName: experimentName)
                var mutatingResult = result
                mutatingResult[section, default: []].append(zip)
                return mutatingResult
            }

            for groupedItem in grouped {
                let section = groupedItem.key
                if !snapshot.sectionIdentifiers.contains(section) {
                    var inserted = false
                    for s in snapshot.sectionIdentifiers {
                        if !inserted, date > s.date, (section.experimentName == nil && s.experimentName == nil) || section.experimentName! > s.experimentName! {
                            snapshot.insertSections([section], beforeSection: s)
                            inserted = true
                            continue
                        }
                    }
                    if !inserted {
                        snapshot.appendSections([section])
                    }
                }
                let existingNames = snapshot.itemIdentifiers(inSection: section).map(\.name)
                for zip in groupedItem.value {
                    if !existingNames.contains(zip.name) {
                        snapshot.appendItems([zip], toSection: section)
                    }
                }
            }

            if grouped.isEmpty {
                let section = KeySection(date: date, experimentName: nil)
                if !snapshot.sectionIdentifiers.contains(section) {
                    var inserted = false
                    for s in snapshot.sectionIdentifiers {
                        if !inserted, date > s.date {
                            snapshot.insertSections([section], beforeSection: s)
                            inserted = true
                            continue
                        }
                    }
                    if !inserted {
                        snapshot.appendSections([section])
                    }
                }
                snapshot.appendItems([], toSection: section)
            }

            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }

    @objc func datePickerDidChange() {
        let date = datePicker.date
        loadKey(for: date)
    }

    func makeDataSource() -> KeyDiffableDataSource {
        let reuseIdentifier = cellReuseIdentifier

        return KeyDiffableDataSource(
            tableView: tableView,
            cellProvider: { tableView, indexPath, zip in
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: reuseIdentifier,
                    for: indexPath
                )

                cell.textLabel?.text = zip.name
                return cell
            }
        )
    }
}

extension KeysViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let key = dataSource.itemIdentifier(for: indexPath) else { return }
        let archive = Archive(url: key.localUrl, accessMode: .read)!
        var localUrls: [URL] = []
        for entry in archive {
            let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent(entry.path)
            _ = try? archive.extract(entry, to: localURL)
            localUrls.append(localURL)
        }

        let manager = ENManager()
        manager.activate { error in
            if let error = error {
                loggingStorage?.log(error.localizedDescription, type: .error)
            }

            let configuration: ENExposureConfiguration = .configuration()
            manager.detectExposures(configuration: configuration, diagnosisKeyURLs: localUrls) { summary, error in
                var string = summary?.description ?? error.debugDescription
                if let summary = summary {
                    let parameters = DP3TTracing.parameters.contactMatching
                    let computedThreshold: Double = (Double(truncating: summary.attenuationDurations[0]) * parameters.factorLow + Double(truncating: summary.attenuationDurations[1]) * parameters.factorHigh) / 60
                    string.append("\n--------\n computed Threshold: \(computedThreshold)")
                    if computedThreshold > Double(parameters.triggerThreshold) {
                        string.append("\n meets requirement of \(parameters.triggerThreshold)")
                    } else {
                        string.append("\n doesn't meet requirement of \(parameters.triggerThreshold)")
                    }
                }

                loggingStorage?.log(string, type: .info)
                let alertController = UIAlertController(title: "Summary", message: string, preferredStyle: .alert)
                let actionOk = UIAlertAction(title: "OK",
                                             style: .default,
                                             handler: nil)
                alertController.addAction(actionOk)
                self.present(alertController, animated: true, completion: nil)
                try? localUrls.forEach(FileManager.default.removeItem(at:))
            }
        }
    }
}

extension ENExposureConfiguration {
    static func configuration(parameters: DP3TParameters = DP3TTracing.parameters) -> ENExposureConfiguration {
        let configuration = ENExposureConfiguration()
        configuration.minimumRiskScore = 0
        configuration.attenuationLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.daysSinceLastExposureLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.durationLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.transmissionRiskLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.metadata = ["attenuationDurationThresholds": [parameters.contactMatching.lowerThreshold,
                                                                    parameters.contactMatching.higherThreshold]]
        return configuration
    }
}
