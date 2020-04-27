/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK_CALIBRATION
import UIKit

class ParametersViewController: UIViewController {
    let stackView = UIStackView()

    let reconnectionDelayInput = UITextField()
    let batchLenghtInput = UITextField()

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

        do {
            let label = UILabel()
            label.text = "Set Reconnection Delay (seconds)"
            stackView.addArrangedSubview(label)

            reconnectionDelayInput.text = "\(Default.shared.reconnectionDelay)"
            reconnectionDelayInput.delegate = self
            reconnectionDelayInput.font = UIFont.systemFont(ofSize: 15)
            reconnectionDelayInput.borderStyle = UITextField.BorderStyle.roundedRect
            reconnectionDelayInput.autocorrectionType = UITextAutocorrectionType.no
            reconnectionDelayInput.keyboardType = UIKeyboardType.numberPad
            reconnectionDelayInput.returnKeyType = UIReturnKeyType.done
            reconnectionDelayInput.clearButtonMode = UITextField.ViewMode.whileEditing
            reconnectionDelayInput.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            reconnectionDelayInput.delegate = self
            stackView.addArrangedSubview(reconnectionDelayInput)

            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Update", for: .normal)
            button.addTarget(self, action: #selector(updateReconnectionDelay), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        do {
            let label = UILabel()
            label.text = "Set buckets batch lenght (seconds)"
            stackView.addArrangedSubview(label)

            batchLenghtInput.text = "\(Default.shared.batchLenght)"
            batchLenghtInput.delegate = self
            batchLenghtInput.font = UIFont.systemFont(ofSize: 15)
            batchLenghtInput.borderStyle = UITextField.BorderStyle.roundedRect
            batchLenghtInput.autocorrectionType = UITextAutocorrectionType.no
            batchLenghtInput.keyboardType = UIKeyboardType.numberPad
            batchLenghtInput.returnKeyType = UIReturnKeyType.done
            batchLenghtInput.clearButtonMode = UITextField.ViewMode.whileEditing
            batchLenghtInput.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            batchLenghtInput.delegate = self
            stackView.addArrangedSubview(batchLenghtInput)

            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Update", for: .normal)
            button.addTarget(self, action: #selector(batchLenghtUpdate), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addArrangedView(UIView())
    }

    @objc func updateReconnectionDelay() {
        let delay = reconnectionDelayInput.text ?? "0"
        let intDelay = Int(delay) ?? 0
        Default.shared.reconnectionDelay = intDelay
        reconnectionDelayInput.text = "\(Default.shared.reconnectionDelay)"
        DP3TTracing.reconnectionDelay = Default.shared.reconnectionDelay
        reconnectionDelayInput.resignFirstResponder()
    }

    @objc func batchLenghtUpdate() {
        let lenght = batchLenghtInput.text ?? "7200"
        let double = Double(lenght) ?? 7200.0
        Default.shared.batchLenght = double
        batchLenghtInput.text = "\(Default.shared.batchLenght)"
        DP3TTracing.batchLenght = Default.shared.batchLenght
        batchLenghtInput.resignFirstResponder()
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
