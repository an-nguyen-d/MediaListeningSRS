import UIKit

final class TranscriptEditorVC: UIViewController {

  private let textView = UITextView()
  private let saveButton = UIButton(type: .system)
  private let cancelButton = UIButton(type: .system)
  private let onSave: (String) -> Void

  init(currentText: String, onSave: @escaping (String) -> Void) {
    self.onSave = onSave
    super.init(nibName: nil, bundle: nil)
    textView.text = currentText
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    textView.backgroundColor = UIColor(white: 0.12, alpha: 1)
    textView.textColor = .white
    textView.font = .systemFont(ofSize: 28, weight: .regular)
    textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
    textView.layer.cornerRadius = 12
    textView.keyboardAppearance = .dark
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(textView)

    var saveConfig = UIButton.Configuration.filled()
    saveConfig.title = "Save"
    saveConfig.baseBackgroundColor = .systemGreen
    saveConfig.baseForegroundColor = .white
    saveConfig.cornerStyle = .large
    saveConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
    saveButton.configuration = saveConfig
    saveButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
    saveButton.translatesAutoresizingMaskIntoConstraints = false
    saveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)
    view.addSubview(saveButton)

    var cancelConfig = UIButton.Configuration.filled()
    cancelConfig.title = "Cancel"
    cancelConfig.baseBackgroundColor = UIColor(white: 0.25, alpha: 1)
    cancelConfig.baseForegroundColor = .white
    cancelConfig.cornerStyle = .large
    cancelConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
    cancelButton.configuration = cancelConfig
    cancelButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
    view.addSubview(cancelButton)

    let buttonRow = UIStackView(arrangedSubviews: [cancelButton, saveButton])
    buttonRow.axis = .horizontal
    buttonRow.spacing = 16
    buttonRow.distribution = .fillEqually
    buttonRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(buttonRow)

    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      textView.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -16),

      buttonRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      buttonRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      buttonRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
      buttonRow.heightAnchor.constraint(equalToConstant: 56),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    textView.becomeFirstResponder()
  }

  @objc private func handleSave() {
    onSave(textView.text)
    dismiss(animated: true)
  }

  @objc private func handleCancel() {
    dismiss(animated: true)
  }
}
