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

class ParametersViewController: UIViewController {
    let stackView = UIStackView()

    let attenuationLow = UITextField()
    let attenuationHigh = UITextField()
    let attenuationFactorLow = UITextField()
    let attenuationFactorHigh = UITextField()
    let attenuationtriggerThreshold = UITextField()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Parameters"
        tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "wrench.fill"), tag: 0)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        view.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(self.view.layoutMarginsGuide)
            make.top.equalTo(self.view.layoutMarginsGuide).inset(12)
        }
        stackView.axis = .vertical

        let params = DP3TTracing.parameters

        do {
            let label = UILabel()
            label.text = "Set Attenuation Low threshold"
            stackView.addArrangedSubview(label)

            attenuationLow.text = "\(params.contactMatching.lowerThreshold)"
            attenuationLow.delegate = self
            attenuationLow.font = UIFont.systemFont(ofSize: 15)
            attenuationLow.borderStyle = UITextField.BorderStyle.roundedRect
            attenuationLow.autocorrectionType = UITextAutocorrectionType.no
            attenuationLow.keyboardType = UIKeyboardType.numberPad
            attenuationLow.returnKeyType = UIReturnKeyType.done
            attenuationLow.clearButtonMode = UITextField.ViewMode.whileEditing
            attenuationLow.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            attenuationLow.delegate = self
            stackView.addArrangedSubview(attenuationLow)
        }
        do {
            let label = UILabel()
            label.text = "Set Attenuation High Threshold"
            stackView.addArrangedSubview(label)

            attenuationHigh.text = "\(params.contactMatching.higherThreshold)"
            attenuationHigh.delegate = self
            attenuationHigh.font = UIFont.systemFont(ofSize: 15)
            attenuationHigh.borderStyle = UITextField.BorderStyle.roundedRect
            attenuationHigh.autocorrectionType = UITextAutocorrectionType.no
            attenuationHigh.keyboardType = UIKeyboardType.numberPad
            attenuationHigh.returnKeyType = UIReturnKeyType.done
            attenuationHigh.clearButtonMode = UITextField.ViewMode.whileEditing
            attenuationHigh.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            attenuationHigh.delegate = self
            stackView.addArrangedSubview(attenuationHigh)
        }

        do {
            let label = UILabel()
            label.text = "Set Attenuation Factor Low"
            stackView.addArrangedSubview(label)

            attenuationFactorLow.text = "\(params.contactMatching.factorLow)"
            attenuationFactorLow.delegate = self
            attenuationFactorLow.font = UIFont.systemFont(ofSize: 15)
            attenuationFactorLow.borderStyle = UITextField.BorderStyle.roundedRect
            attenuationFactorLow.autocorrectionType = UITextAutocorrectionType.no
            attenuationFactorLow.keyboardType = UIKeyboardType.decimalPad
            attenuationFactorLow.returnKeyType = UIReturnKeyType.done
            attenuationFactorLow.clearButtonMode = UITextField.ViewMode.whileEditing
            attenuationFactorLow.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            attenuationFactorLow.delegate = self
            stackView.addArrangedSubview(attenuationFactorLow)
        }

        do {
            let label = UILabel()
            label.text = "Set Attenuation Factor High"
            stackView.addArrangedSubview(label)

            attenuationFactorHigh.text = "\(params.contactMatching.factorHigh)"
            attenuationFactorHigh.delegate = self
            attenuationFactorHigh.font = UIFont.systemFont(ofSize: 15)
            attenuationFactorHigh.borderStyle = UITextField.BorderStyle.roundedRect
            attenuationFactorHigh.autocorrectionType = UITextAutocorrectionType.no
            attenuationFactorHigh.keyboardType = UIKeyboardType.decimalPad
            attenuationFactorHigh.returnKeyType = UIReturnKeyType.done
            attenuationFactorHigh.clearButtonMode = UITextField.ViewMode.whileEditing
            attenuationFactorHigh.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            attenuationFactorHigh.delegate = self
            stackView.addArrangedSubview(attenuationFactorHigh)
        }

        do {
            let label = UILabel()
            label.text = "Set Attenuation Factor High"
            stackView.addArrangedSubview(label)

            attenuationtriggerThreshold.text = "\(params.contactMatching.triggerThreshold)"
            attenuationtriggerThreshold.delegate = self
            attenuationtriggerThreshold.font = UIFont.systemFont(ofSize: 15)
            attenuationtriggerThreshold.borderStyle = UITextField.BorderStyle.roundedRect
            attenuationtriggerThreshold.autocorrectionType = UITextAutocorrectionType.no
            attenuationtriggerThreshold.keyboardType = UIKeyboardType.numberPad
            attenuationtriggerThreshold.returnKeyType = UIReturnKeyType.done
            attenuationtriggerThreshold.clearButtonMode = UITextField.ViewMode.whileEditing
            attenuationtriggerThreshold.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            attenuationtriggerThreshold.delegate = self
            stackView.addArrangedSubview(attenuationtriggerThreshold)
        }

        let button = UIButton()
        button.setTitleColor(.systemBlue, for: .normal)
        button.setTitleColor(.systemGray, for: .highlighted)
        button.setTitle("Update", for: .normal)
        button.addTarget(self, action: #selector(attenutationUpdate), for: .touchUpInside)
        stackView.addArrangedSubview(button)

        stackView.addArrangedView(UIView())
    }

    @objc func attenutationUpdate() {
        guard let lowString = attenuationLow.text,
            let low = Int(lowString),
            let highString = attenuationHigh.text,
            let high = Int(highString),
            let factorLowString = attenuationFactorLow.text,
            let factorLow = try? Double(value: factorLowString),
            let factorHighString = attenuationFactorHigh.text,
            let factorHigh = try? Double(value: factorHighString),
            let thresholdString = attenuationtriggerThreshold.text,
            let threshold = Int(thresholdString) else { return }
        var params = DP3TTracing.parameters
        params.contactMatching.lowerThreshold = low
        params.contactMatching.higherThreshold = high
        params.contactMatching.factorLow = factorLow
        params.contactMatching.factorHigh = factorHigh
        params.contactMatching.triggerThreshold = threshold
        DP3TTracing.parameters = params

        [attenuationtriggerThreshold, attenuationLow, attenuationHigh, attenuationFactorLow, attenuationFactorHigh].forEach { $0.resignFirstResponder() }
    }
}

extension ParametersViewController: DP3TTracingDelegate {
    func DP3TTracingStateChanged(_: TracingState) {}
}

extension ParametersViewController: UITextFieldDelegate {
    func textField(_: UITextField, shouldChangeCharactersIn _: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
