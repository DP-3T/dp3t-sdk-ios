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
import SnapKit
import UIKit

class ControlViewController: UIViewController {
    let segmentedControl = UISegmentedControl(items: ["On", "Off"])

    let startAdvertisingButton = UIButton()
    let startReceivingButton = UIButton()

    let statusLabel = UILabel()

    let stackView = UIStackView()

    let scrollView = UIScrollView()

    let shareButton = UIButton()

    let uploadButton = UIButton()

    let uploadKeysButton = UIButton()

    private let uploadHelper = NetworkingHelper()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Controls"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "doc.text"), tag: 0)
        }
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanges), for: .valueChanged)

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateState()
    }

    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

        if notification.name == UIResponder.keyboardWillHideNotification {
            scrollView.contentInset = .zero
        } else {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
        }

        scrollView.scrollIndicatorInsets = scrollView.contentInset
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(self.view)
        }

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.leading.bottom.trailing.equalToSuperview().inset(10)
        }
        stackView.axis = .vertical

        statusLabel.font = .systemFont(ofSize: 18)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        if #available(iOS 13.0, *) {
            statusLabel.backgroundColor = .systemGroupedBackground
        } else {
            statusLabel.backgroundColor = .lightGray
        }
        DP3TTracing.status { result in
            switch result {
            case let .success(state):
                self.updateUI(state)
            case .failure:
                break
            }
        }

        stackView.addArrangedSubview(statusLabel)
        stackView.addSpacerView(18)

        do {
            let label = UILabel()
            label.text = "Start / Stop Exposure Notification Service"
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(segmentedControl)
        }

        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Reset SDK", for: .normal)
            button.addTarget(self, action: #selector(reset), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Reset Infection Status", for: .normal)
            button.addTarget(self, action: #selector(resetInfectionState), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Reset Exposure Days", for: .normal)
            button.addTarget(self, action: #selector(resetExposureDays), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Set Infected", for: .normal)
            button.addTarget(self, action: #selector(setExposed), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Set Infected Fake", for: .normal)
            button.addTarget(self, action: #selector(setExposedFake), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        stackView.addSpacerView(12)

        do {
            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Synchronize with Backend", for: .normal)
            button.addTarget(self, action: #selector(sync), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addSpacerView(12)

        do {
            if #available(iOS 13.0, *) {
                shareButton.setTitleColor(.systemBlue, for: .normal)
                shareButton.setTitleColor(.systemGray, for: .highlighted)
            } else {
                shareButton.setTitleColor(.blue, for: .normal)
                shareButton.setTitleColor(.black, for: .highlighted)
            }
            shareButton.setTitle("Share Database", for: .normal)
            shareButton.addTarget(self, action: #selector(shareDatabase), for: .touchUpInside)
            stackView.addArrangedSubview(shareButton)
        }
        stackView.addSpacerView(12)

        do {
            if #available(iOS 13.0, *) {
                uploadButton.setTitleColor(.systemBlue, for: .normal)
                uploadButton.setTitleColor(.systemGray, for: .highlighted)
            } else {
                uploadButton.setTitleColor(.blue, for: .normal)
                uploadButton.setTitleColor(.black, for: .highlighted)
            }
            uploadButton.setTitle("Upload Database", for: .normal)
            uploadButton.addTarget(self, action: #selector(uploadDatabase), for: .touchUpInside)
            stackView.addArrangedSubview(uploadButton)
        }

        stackView.addSpacerView(12)

        do {
            if #available(iOS 13.0, *) {
                uploadKeysButton.setTitleColor(.systemBlue, for: .normal)
                uploadKeysButton.setTitleColor(.systemGray, for: .highlighted)
            } else {
                uploadKeysButton.setTitleColor(.blue, for: .normal)
                uploadKeysButton.setTitleColor(.black, for: .highlighted)
            }
            uploadKeysButton.setTitle("Upload Keys for Debugging", for: .normal)
            uploadKeysButton.addTarget(self, action: #selector(uploadKeys), for: .touchUpInside)
            stackView.addArrangedSubview(uploadKeysButton)
        }

        stackView.addArrangedSubview(UIView())
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func sync() {
        DP3TTracing.sync { [weak self] result in
            switch result {
            case let .failure(error):
                let ac = UIAlertController(title: "Error",
                                           message: error.description,
                                           preferredStyle: .alert)
                ac.addAction(.init(title: "Retry", style: .default) { _ in self?.sync() })
                ac.addAction(.init(title: "Cancel", style: .destructive))
                self?.present(ac, animated: true)
            default:
                break
            }
            self?.updateState()
        }
    }

    @objc func setExposed() {
        // Share keys of last 14 days
        DP3TTracing.iWasExposed(onset: Date(timeIntervalSinceNow: -60 * 60 * 24 * 14), authentication: .none) { [weak self] result in
            switch result {
            case let .failure(error):
                let ac = UIAlertController(title: "Error",
                                           message: error.description,
                                           preferredStyle: .alert)
                ac.addAction(.init(title: "Retry", style: .default) { _ in self?.setExposed() })
                ac.addAction(.init(title: "Cancel", style: .destructive))
                self?.present(ac, animated: true)
            default:
                break
            }
            self?.updateState()
        }
    }

    @objc func setExposedFake() {
        DP3TTracing.iWasExposed(onset: Date(), authentication: .none, isFakeRequest: true) { _ in
            DP3TTracing.status { result in
                switch result {
                case let .success(state):
                    self.updateUI(state)
                case .failure:
                    break
                }
            }
        }
    }

    @objc func shareDatabase() {
        let acv = UIActivityViewController(activityItems: [Self.getDatabasePath()], applicationActivities: nil)
        if let popoverController = acv.popoverPresentationController {
            popoverController.sourceView = shareButton
        }
        present(acv, animated: true)
    }

    @objc func uploadDatabase() {
        let loading = UIAlertController(title: "Uploading", message: "Please wait", preferredStyle: .alert)
        present(loading, animated: true)

        uploadHelper.uploadDatabase(fileUrl: Self.getDatabasePath()) { result in
            let alert: UIAlertController
            switch result {
            case .success:
                alert = UIAlertController(title: "Upload successful", message: nil, preferredStyle: .alert)
            case let .failure(error):
                alert = UIAlertController(title: "Upload failed", message: error.message, preferredStyle: .alert)
            }
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            loading.dismiss(animated: false) {
                self.present(alert, animated: false)
            }
        }
    }

    @objc func uploadKeys() {
        let alert = UIAlertController(title: "Upload Keys", message: "Enter debug device name", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "debug device name"
            textField.text = ""
        }

        alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [weak alert] _ in
            let textField = alert?.textFields![0]
            self.uploadHelper.uploadDebugKeys(debugName: textField?.text ?? "noName") { result in
                print(result)
            }
        }))

        alert.addAction(.init(title: "Cancel", style: .destructive, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    @objc func reset() {
        DP3TTracing.stopTracing()
        try? DP3TTracing.reset()
        NotificationCenter.default.post(name: Notification.Name("ClearData"), object: nil)

        initializeSDK()

        DP3TTracing.delegate = navigationController?.tabBarController as? DP3TTracingDelegate
        DP3TTracing.status { result in
            switch result {
            case let .success(state):
                self.updateUI(state)
            case .failure:
                break
            }
        }
    }

    @objc func resetInfectionState() {
        try? DP3TTracing.resetInfectionStatus()
    }

    @objc func resetExposureDays() {
        try? DP3TTracing.resetExposureDays()
    }

    @objc func segmentedControlChanges() {
        if segmentedControl.selectedSegmentIndex == 0 {
            try? DP3TTracing.startTracing()
            Default.shared.tracingMode = .active
        } else {
            DP3TTracing.stopTracing()
            Default.shared.tracingMode = .none
        }
    }

    func updateState() {
        DP3TTracing.status { result in
            switch result {
            case let .success(state):
                self.updateUI(state)
            case .failure:
                break
            }
        }
    }

    func updateUI(_ state: TracingState) {
        var elements: [String] = []
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            elements.append("Version: App: \(version)(\(build)) SDK: \(DP3TTracing.frameworkVersion)")
        }
        elements.append("tracking State: \(state.trackingState.stringValue)")
        switch state.backgroundRefreshState {
        case .available:
            elements.append("background: available")
        case .restricted:
            elements.append("background: restricted")
        case .denied:
            elements.append("background: denied")
        @unknown default:
            break
        }
        switch state.trackingState {
        case .active:
            segmentedControl.selectedSegmentIndex = 0
            startReceivingButton.isEnabled = false
            startAdvertisingButton.isEnabled = false
        default:
            segmentedControl.selectedSegmentIndex = 1
            startReceivingButton.isEnabled = true
            startAdvertisingButton.isEnabled = true
        }
        if let lastSync = state.lastSync {
            elements.append("last Sync: \(lastSync.stringVal)")
        }

        switch state.infectionStatus {
        case let .exposed(days):
            elements.append("InfectionStatus: EXPOSED days ->")
            elements.append(contentsOf: days.enumerated().map { "\($0.offset): \($0.element.exposedDate.description)" })
            elements.append("--")
        case .infected:
            elements.append("InfectionStatus: INFECTED")
        case .healthy:
            elements.append("InfectionStatus: HEALTHY")
        }

        statusLabel.text = elements.joined(separator: "\n")
    }

    private static func getDatabasePath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("DP3T_tracing_db").appendingPathExtension("sqlite")
    }
}

extension ControlViewController: DP3TTracingDelegate {
    func DP3TTracingStateChanged(_ state: TracingState) {
        updateUI(state)
    }
}

extension ControlViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let textFieldText = textField.text,
            let rangeOfTextToReplace = Range(range, in: textFieldText) else {
            return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        return count <= 4
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private extension TrackingState {
    var stringValue: String {
        switch self {
        case .active:
            return "active"
        case let .inactive(error):
            return "inactive \(error.localizedDescription)"
        case .stopped:
            return "stopped"
        }
    }
}

extension DP3TTracingError {
    var description: String {
        switch self {
        case .bluetoothTurnedOff:
            return "bluetoothTurnedOff"
        case let .caseSynchronizationError(errors: errors):
            return "caseSynchronizationError \(errors.map { $0.localizedDescription })"
        case let .databaseError(error: error):
            return "databaseError \(error?.localizedDescription ?? "nil")"
        case let .networkingError(error: error):
            return "networkingError \(error.localizedDescription)"
        case .permissonError:
            return "networkingError"
        case .userAlreadyMarkedAsInfected:
            return "userAlreadyMarkedAsInfected"
        case let .exposureNotificationError(error: error):
            return "exposureNotificationError \(error.localizedDescription)"
        case .cancelled:
            return "cancelled"
        }
    }
}
