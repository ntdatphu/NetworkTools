pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import UI

StandardDialog {
    id: root

    signal createRequested(string projectName, string password)

    title: "Create New Project"
    subtitle: "Start a NetworkTools workspace"
    preferredWidth: 520
    implicitHeight: protectProjectCheck.checked ? 535 : 390

    onOpened: projectNameField.forceActiveFocus()
    onClosed: {
        passwordField.clear()
        confirmPasswordField.clear()
        protectProjectCheck.checked = false
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing16

        StandardTextField {
            id: projectNameField
            objectName: "welcomeProjectNameField"
            Layout.fillWidth: true
            labelText: "Project name"
            placeholderText: "e.g., Campus Core Lab"
            onAccepted: if (createButton.enabled) createButton.clicked()
        }

        StandardCheckBox {
            id: protectProjectCheck
            objectName: "welcomeProtectProjectCheck"
            text: "Protect project with a password"
            onToggled: {
                if (checked)
                    passwordField.forceActiveFocus()
                else {
                    passwordField.clear()
                    confirmPasswordField.clear()
                }
            }
        }

        StandardPasswordField {
            id: passwordField
            objectName: "welcomeProjectPasswordField"
            Layout.fillWidth: true
            visible: protectProjectCheck.checked
            labelText: "Password"
            placeholderText: "Enter a strong password"
            onAccepted: confirmPasswordField.forceActiveFocus()
        }

        StandardPasswordField {
            id: confirmPasswordField
            objectName: "welcomeProjectPasswordConfirmationField"
            Layout.fillWidth: true
            visible: protectProjectCheck.checked
            labelText: "Confirm password"
            placeholderText: "Enter the password again"
            onAccepted: if (createButton.enabled) createButton.clicked()
        }

        InlineMessage {
            Layout.fillWidth: true
            visible: protectProjectCheck.checked
                     && confirmPasswordField.text.length > 0
                     && passwordField.text !== confirmPasswordField.text
            message: "The passwords do not match."
            severity: "warning"
        }

        InlineMessage {
            Layout.fillWidth: true
            message: protectProjectCheck.checked
                     ? "The complete .ntp package will be protected with AES-256. The password is not stored or recoverable."
                     : "Creates a standard ZIP-compatible .ntp project in your Documents folder."
            severity: "info"
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            Item { Layout.fillWidth: true }

            StandardButton {
                text: "Cancel"
                type: "Text"
                onClicked: root.reject()
            }

            StandardButton {
                id: createButton
                objectName: "welcomeCreateProjectConfirmButton"
                text: "Create Project"
                type: "Primary"
                enabled: projectNameField.text.trim().length > 0
                         && (!protectProjectCheck.checked
                             || (passwordField.text.length > 0
                                 && passwordField.text === confirmPasswordField.text))
                onClicked: {
                    root.createRequested(
                        projectNameField.text.trim(),
                        protectProjectCheck.checked ? passwordField.text : ""
                    )
                    root.accept()
                }
            }
        }
    }
}
