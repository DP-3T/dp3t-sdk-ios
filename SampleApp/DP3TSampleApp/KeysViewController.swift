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

    private let activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))

    private let nameRegex = try? NSRegularExpression(pattern: "key_export_experiment_([a-zA-Z0-9]+)_(.+)", options: .caseInsensitive)

    private let manager = ENManager()

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
        loadKeys(for: date)

        manager.activate { error in
            if let error = error {
                loggingStorage?.log(error.localizedDescription, type: .error)
            }
        }
    }

    private func parseZipName(name: String) -> (experimentName: String?, deviceName: String?) {
        guard let regex = nameRegex else { return (nil, nil) }
        var experimentName: String?
        var deviceName: String?

        if let match = regex.firstMatch(in: name, options: [], range: NSRange(location: 0, length: name.utf16.count)) {
            if let experimentRange = Range(match.range(at: 1), in: name) {
                experimentName = String(name[experimentRange])
            }

            if let deviceRange = Range(match.range(at: 2), in: name) {
                deviceName = String(name[deviceRange])
            }
        }
        return (experimentName, deviceName)
    }

    private func groupZips(zips: [NetworkingHelper.DebugZips], date: Date) -> [KeySection: [NetworkingHelper.DebugZips]] {
        return zips.reduce([KeySection: [NetworkingHelper.DebugZips]]()) { (result, zip) -> [KeySection : [NetworkingHelper.DebugZips]] in
            let (experimentName, _) = self.parseZipName(name: zip.name)
            let section = KeySection(date: date, experimentName: experimentName)
            var mutatingResult = result
            mutatingResult[section, default: []].append(zip)
            return mutatingResult
        }
    }

    func loadKeys(for date: Date) {
        activityIndicator.startAnimating()
        networkingHelper.getDebugKeys(day: date) { [weak self] result in
            guard let self = self else { return }
            defer { self.activityIndicator.stopAnimating() }
            var snapshot = self.dataSource.snapshot()

            let grouped = self.groupZips(zips: result, date: date)

            for groupedItem in grouped {
                let section = groupedItem.key
                snapshot.insert(section: section, items: groupedItem.value)
            }

            if grouped.isEmpty {
                let section = KeySection(date: date, experimentName: nil)
                snapshot.insert(section: section, items: [])
            }

            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }

    @objc func datePickerDidChange() {
        let date = datePicker.date
        loadKeys(for: date)
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
                cell.textLabel?.numberOfLines = 0
                return cell
            }
        )
    }
}

extension KeysViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let zip = dataSource.itemIdentifier(for: indexPath) else { return }
        handleZip(zip)
    }
}

extension KeysViewController {

    func unarchiveZip(_ zip: NetworkingHelper.DebugZips) -> [URL] {
        let archive = Archive(url: zip.localUrl, accessMode: .read)!
        var localUrls: [URL] = []
        for entry in archive {
            let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent(entry.path)
            _ = try? archive.extract(entry, to: localURL)
            localUrls.append(localURL)
        }
        return localUrls
    }

    func detectExposures(localUrls: [URL]) {
        let configuration: ENExposureConfiguration = .configuration()
        manager.detectExposures(configuration: configuration, diagnosisKeyURLs: localUrls) { [weak self] summary, error in
            guard let self = self else { return }
            guard let summary = summary else { return }
            self.getWindows(summary: summary)
        }
    }

    func getWindows(summary: ENExposureDetectionSummary) {
        manager.getExposureWindows(summary: summary) { (weakWindows, errir) in
            if let allWindows = weakWindows {
                let parameters = DP3TTracing.parameters.contactMatching
                let groups = allWindows.groupByDay
                var exposureDays = Set<Date>()
                for (day, windows) in groups {
                    let attenuationValues = windows.attenuationValues(lowerThreshold: parameters.lowerThreshold,
                                                                      higherThreshold: parameters.higherThreshold)

                    if attenuationValues.matches(factorLow: parameters.factorLow,
                                                 factorHigh: parameters.factorHigh,
                                                 triggerThreshold: parameters.triggerThreshold) {
                        exposureDays.insert(day)

                    }
                }
                print(exposureDays)
            }


            let alertController = UIAlertController(title: "Windows", message: "windows: \(weakWindows?.debugDescription ?? "nil")", preferredStyle: .actionSheet)
            let actionOk = UIAlertAction(title: "OK",
                                         style: .default,
                                         handler: nil)
            alertController.addAction(actionOk)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    func handleZip(_ zip: NetworkingHelper.DebugZips){
        let localUrls = unarchiveZip(zip)
        detectExposures(localUrls: localUrls)
    }

}

extension ENExposureConfiguration {
    static func configuration(parameters: DP3TParameters = DP3TTracing.parameters) -> ENExposureConfiguration {
        let configuration = ENExposureConfiguration()
        configuration.reportTypeNoneMap = .confirmedTest
        configuration.infectiousnessForDaysSinceOnsetOfSymptoms = [ENDaysSinceOnsetOfSymptomsUnknown as NSNumber: ENInfectiousness.high.rawValue as NSNumber]
        for i in -14...14 {
            configuration.infectiousnessForDaysSinceOnsetOfSymptoms?[i as NSNumber] = ENInfectiousness.high.rawValue as NSNumber
        }
        return configuration
    }
}

extension NSDiffableDataSourceSnapshot where SectionIdentifierType == KeySection,ItemIdentifierType == NetworkingHelper.DebugZips {
    mutating func insert(section: KeySection, items: [NetworkingHelper.DebugZips]) {
        if !sectionIdentifiers.contains(section) {
            var inserted = false
            for s in sectionIdentifiers {
                if !inserted,
                    section.date > s.date,
                    (section.experimentName == nil || s.experimentName == nil) || section.experimentName! > s.experimentName! {
                    insertSections([section], beforeSection: s)
                    inserted = true
                    break
                }
            }
            if !inserted {
                appendSections([section])
            }
        }
        let existingNames = itemIdentifiers(inSection: section).map(\.name)
        for zip in items {
            if !existingNames.contains(zip.name) {
                appendItems([zip], toSection: section)
            }
        }
    }
}
