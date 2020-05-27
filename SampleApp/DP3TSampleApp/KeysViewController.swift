
import DP3TSDK
import ExposureNotification
import UIKit
import ZIPFoundation

class KeyDiffableDataSource: UITableViewDiffableDataSource<Date, NetworkingHelper.DebugZips> {
    static var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Self.formatter.string(from: snapshot().sectionIdentifiers[section])
    }
}

class KeysViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let datePicker = UIDatePicker()

    private let cellReuseIdentifier = "keyCell"
    private lazy var dataSource: KeyDiffableDataSource = makeDataSource()

    private let networkingHelper = NetworkingHelper()

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

        let date = Date().addingTimeInterval(60 * 60 * 24)
        datePicker.setDate(date, animated: false)
        networkingHelper.getDebugKeys(day: date) { [weak self] result in
            var snapshot = NSDiffableDataSourceSnapshot<Date, NetworkingHelper.DebugZips>()
            snapshot.appendSections([date])
            snapshot.appendItems(result, toSection: date)
            self?.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }

    @objc func datePickerDidChange() {
        let date = datePicker.date
        guard !dataSource.snapshot().sectionIdentifiers.contains(date) else { return }
        networkingHelper.getDebugKeys(day: date) { [weak self] result in
            guard let self = self else { return }
            var snapshot = self.dataSource.snapshot()
            if !snapshot.sectionIdentifiers.contains(date) {
                snapshot.appendSections([date])
            }
            snapshot.appendItems(result, toSection: date)
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
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
                    let computedThreshold: Double = (Double(truncating: summary.attenuationDurations[0]) * parameters.factorLow + Double(truncating: summary.attenuationDurations[0]) * parameters.factorHigh) / 60
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
        configuration.attenuationWeight = 50
        configuration.daysSinceLastExposureLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.daysSinceLastExposureWeight = 50
        configuration.durationLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.durationWeight = 50
        configuration.transmissionRiskLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.transmissionRiskWeight = 50
        configuration.metadata = ["attenuationDurationThresholds": [parameters.contactMatching.lowerThreshold,
                                                                    parameters.contactMatching.higherThreshold]]
        return configuration
    }
}
