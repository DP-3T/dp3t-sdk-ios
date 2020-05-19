/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK
import UIKit

class ParametersViewController: UIViewController {
    let stackView = UIStackView()

    let attenuationLow = UITextField()
    let attenuationHigh = UITextField()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Parameters"
        if #available(iOS 13.0, *) {
            tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: "wrench.fill"), tag: 0)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
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

            attenuationLow.text = "\(params.contactMatching.attenuationThresholdLow)"
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

            attenuationHigh.text = "\(params.contactMatching.attenuationThresholdHigh)"
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
            let high = Int(highString) else { return }
        DP3TTracing.parameters.contactMatching.attenuationThresholdLow = low
        DP3TTracing.parameters.contactMatching.attenuationThresholdHigh = high

        attenuationLow.resignFirstResponder()
        attenuationHigh.resignFirstResponder()
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
