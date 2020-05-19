/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK
import UIKit

class ParametersViewController: UIViewController {
    let stackView = UIStackView()

    let batchLengthInput = UITextField()

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

        /*
        do {
            let label = UILabel()
            label.text = "Set buckets batch length (seconds)"
            stackView.addArrangedSubview(label)

            batchLengthInput.delegate = self
            batchLengthInput.font = UIFont.systemFont(ofSize: 15)
            batchLengthInput.borderStyle = UITextField.BorderStyle.roundedRect
            batchLengthInput.autocorrectionType = UITextAutocorrectionType.no
            batchLengthInput.keyboardType = UIKeyboardType.numberPad
            batchLengthInput.returnKeyType = UIReturnKeyType.done
            batchLengthInput.clearButtonMode = UITextField.ViewMode.whileEditing
            batchLengthInput.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
            batchLengthInput.delegate = self
            stackView.addArrangedSubview(batchLengthInput)

            let button = UIButton()
            if #available(iOS 13.0, *) {
                button.setTitleColor(.systemBlue, for: .normal)
                button.setTitleColor(.systemGray, for: .highlighted)
            } else {
                button.setTitleColor(.blue, for: .normal)
                button.setTitleColor(.black, for: .highlighted)
            }
            button.setTitle("Update", for: .normal)
            button.addTarget(self, action: #selector(batchLengthUpdate), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        stackView.addArrangedView(UIView())*/
    }
/*
    @objc func batchLengthUpdate() {
        let length = batchLengthInput.text ?? "7200"
        let double = Double(length) ?? 7200.0
        batchLengthInput.text = "\(double)"
        DP3TTracing.parameters.networking.batchLength = double
        batchLengthInput.resignFirstResponder()
    }*/
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
