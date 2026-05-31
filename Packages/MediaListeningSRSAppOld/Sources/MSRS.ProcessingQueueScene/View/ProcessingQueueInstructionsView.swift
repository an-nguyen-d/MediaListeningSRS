import UIKit

final class ProcessingQueueInstructionsView: UIView {

  var onSaveInstructions: ((String) -> Void)?

  private(set) var isEditingInstructions = false

  private let headerLabel = UILabel()
  private let editButton = UIButton(type: .system)
  private let cancelButton = UIButton(type: .system)
  private let saveButton = UIButton(type: .system)
  private let textView = UITextView()

  private var savedText = ""

  override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setInstructionsText(_ text: String) {
    savedText = text
    if !isEditingInstructions {
      applyDisplayText()
    }
  }

  // MARK: - Setup

  private func setUp() {
    backgroundColor = .systemBackground

    headerLabel.text = "Instructions"
    headerLabel.font = .preferredFont(forTextStyle: .headline)
    headerLabel.setContentHuggingPriority(.required, for: .horizontal)

    editButton.setTitle("Edit", for: .normal)
    editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)

    cancelButton.setTitle("Cancel", for: .normal)
    cancelButton.setTitleColor(.systemRed, for: .normal)
    cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    cancelButton.isHidden = true

    saveButton.setTitle("Save", for: .normal)
    saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    saveButton.isHidden = true

    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

    let headerStack = UIStackView(arrangedSubviews: [headerLabel, spacer, cancelButton, saveButton, editButton])
    headerStack.spacing = 12
    headerStack.alignment = .center

    textView.font = .preferredFont(forTextStyle: .body)
    textView.isEditable = false
    textView.isScrollEnabled = true
    textView.backgroundColor = .clear
    textView.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

    addSubview(headerStack)
    addSubview(textView)
    headerStack.translatesAutoresizingMaskIntoConstraints = false
    textView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

      textView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 4),
      textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      textView.heightAnchor.constraint(equalToConstant: 100),
    ])

    applyDisplayText()
  }

  // MARK: - Display

  private func applyDisplayText() {
    if savedText.isEmpty {
      textView.text = "No instructions yet"
      textView.textColor = .tertiaryLabel
    } else {
      textView.text = savedText
      textView.textColor = .secondaryLabel
    }
  }

  // MARK: - Actions

  @objc private func editTapped() {
    isEditingInstructions = true
    textView.text = savedText
    textView.textColor = .label
    textView.isEditable = true
    textView.backgroundColor = .secondarySystemBackground
    textView.layer.cornerRadius = 6
    textView.becomeFirstResponder()
    editButton.isHidden = true
    cancelButton.isHidden = false
    saveButton.isHidden = false
  }

  @objc private func cancelTapped() {
    exitEditMode()
  }

  @objc private func saveTapped() {
    let text = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    savedText = text
    onSaveInstructions?(text)
    exitEditMode()
  }

  private func exitEditMode() {
    isEditingInstructions = false
    textView.isEditable = false
    textView.backgroundColor = .clear
    textView.layer.cornerRadius = 0
    textView.resignFirstResponder()
    editButton.isHidden = false
    cancelButton.isHidden = true
    saveButton.isHidden = true
    applyDisplayText()
  }
}
